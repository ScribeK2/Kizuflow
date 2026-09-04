# Validates sub-flow references to prevent circular dependencies.
# A circular dependency would cause infinite recursion during execution.
#
# Example of circular dependency:
#   Workflow A -> references Workflow B as sub-flow
#   Workflow B -> references Workflow A as sub-flow
#   This would cause infinite recursion: A -> B -> A -> B -> ...
#
# Usage:
#   validator = SubflowValidator.new(workflow_id)
#   if validator.valid?
#     # No circular references
#   else
#     validator.findings # => [#<ValidationFinding code: :circular_subflow, ...>]
#     validator.errors   # => ["Circular sub-flow reference: Workflow A -> Workflow B -> Workflow A"]
#   end
#
# Reporting mirrors GraphValidator: findings are the source of truth and carry
# the code plus structured details, while #errors is a projection of their
# messages for callers that only surface text.
class SubflowValidator
  attr_reader :findings

  MAX_DEPTH = 10 # Maximum sub-flow nesting depth
  SUBFLOW_TYPES = %w[sub_flow sub-flow].freeze

  # Initialize with the workflow ID to validate
  # @param workflow_id [Integer] The ID of the workflow to validate
  def initialize(workflow_id)
    @workflow_id = workflow_id
    @findings = []
  end

  # Human-readable messages, in findings order. Kept so Workflow's AR validation
  # needs no knowledge of findings.
  def errors
    @findings.map(&:message)
  end

  # Run validation and return true if no circular references exist
  def valid?
    @findings = []
    # Grey and black for the cycle walk, plus one depth memo. Reset per run so a
    # validator instance can be re-asked after the graph changes.
    @on_path = Set.new
    @explored = Set.new
    @depth_cache = {}

    root = Workflow.find_by(id: @workflow_id)
    return true unless root

    # Batch-load all reachable workflows upfront
    @workflows_cache = preload_reachable_workflows(root)

    validate_no_circular_subflows(root, [])
    validate_max_depth(root)

    @findings.empty?
  end

  # Class method for quick validation
  def self.valid?(workflow_id)
    new(workflow_id).valid?
  end

  # Class method to get all errors
  def self.errors_for(workflow_id)
    validator = new(workflow_id)
    validator.valid?
    validator.errors
  end

  private

  def add_finding(code, message, details: {})
    @findings << ValidationFinding.new(code:, message:, details:)
  end

  # Batch-load all workflows reachable via sub-flow references
  # Uses a single bulk query to load all potentially reachable workflows,
  # then verifies connectivity in-memory
  # @param root [Workflow] The starting workflow
  # @return [Hash<Integer, Workflow>] Cache of workflow_id => workflow
  def preload_reachable_workflows(root)
    cache = { root.id => root }
    initial_ids = extract_subflow_target_ids(root)
    return cache if initial_ids.empty?

    # Load all initial targets in one query
    batch = Workflow.where(id: initial_ids).to_a
    batch.each { |w| cache[w.id] = w }

    # Collect any further references from loaded workflows
    loaded_ids = cache.keys.to_set
    new_ids = batch.flat_map { |w| extract_subflow_target_ids(w) }.uniq - loaded_ids.to_a

    # Continue loading in batches until no new IDs are found
    while new_ids.any?
      next_batch = Workflow.where(id: new_ids).to_a
      next_batch.each { |w| cache[w.id] = w }
      loaded_ids.merge(new_ids)

      new_ids = next_batch.flat_map { |w| extract_subflow_target_ids(w) }.uniq - loaded_ids.to_a
    end

    cache
  end

  # Extract target workflow IDs from sub-flow steps
  # Supports both ActiveRecord Steps and legacy JSONB during migration.
  # Checks JSONB first (in-memory, no extra query) during transition period.
  # @param workflow [Workflow] The workflow to extract from
  # @return [Array<Integer>] Array of target workflow IDs
  def extract_subflow_target_ids(workflow)
    if workflow.read_attribute(:steps).is_a?(Array)
      workflow.read_attribute(:steps)
              .select { |s| SUBFLOW_TYPES.include?(s["type"]) && s["target_workflow_id"].present? }
              .map { |s| s["target_workflow_id"].to_i }
    else
      Steps::SubFlow.where(workflow_id: workflow.id).pluck(:sub_flow_workflow_id).compact
    end
  end

  # Recursively check for circular sub-flow references.
  #
  # Three-colour DFS: `@on_path` is grey (an ancestor of the current node, so an
  # edge back to it is a cycle) and `@explored` is black (a subtree already
  # proven acyclic, so there is nothing to learn by walking it again).
  #
  # The black set is the whole point. Without it this enumerated every simple
  # path in the graph — `visited_path + [workflow.id]` forked a fresh array per
  # branch and nothing remembered a node had been cleared — which is exponential
  # in a fan-out graph rather than a chain. Measured before the fix, on a DAG
  # with no cycle at all: 8 workflows 0.7s, 12 workflows 4.3s, 14 workflows 16s,
  # 16 workflows 61s, roughly doubling per workflow. That ran inside the import's
  # open write transaction, and again on every later save and health check of any
  # workflow carrying a sub_flow step. Each visit also issues a query
  # (`extract_subflow_target_ids`), so the query count grew the same way.
  #
  # `path` is now mutated with push/pop rather than copied, so it stays the
  # current root-to-node path and still names the cycle it finds.
  #
  # @param workflow [Workflow] The current workflow being validated
  # @param path [Array<Integer>] Workflow ids from the root to this node
  def validate_no_circular_subflows(workflow, path)
    return if workflow.nil?

    # Grey is consulted BEFORE black, and that order is the correctness of the
    # whole thing: a back edge points at a node that is on the current path, and
    # if the black check ran first it would skip that edge and miss the cycle.
    # Reversing these two lines makes six tests in this file fail — checked.
    #
    # Given that order, marking black on exit rather than on entry is a matter of
    # meaning, not behaviour (also checked: moving it makes nothing fail). It is
    # on exit because black is meant to say "this subtree is proven acyclic",
    # not "seen once".
    if @on_path.include?(workflow.id)
      cycle_start = path.index(workflow.id)
      cycle_path = path[cycle_start..] + [workflow.id]
      cycle_names = cycle_path.map { |wid| @workflows_cache[wid]&.title || "Workflow ##{wid}" }
      add_finding(:circular_subflow, "Circular sub-flow reference: #{cycle_names.join(' -> ')}",
                  details: { cycle_workflow_ids: cycle_path })
      return
    end

    return if @explored.include?(workflow.id)

    @on_path.add(workflow.id)
    path.push(workflow.id)

    extract_subflow_target_ids(workflow).each do |target_id|
      target = @workflows_cache[target_id]
      unless target
        add_finding(:subflow_target_missing, "Sub-flow references non-existent workflow (ID: #{target_id})",
                    details: { workflow_id: workflow.id, target_workflow_id: target_id })
        next
      end
      validate_no_circular_subflows(target, path)
    end

    path.pop
    @on_path.delete(workflow.id)
    @explored.add(workflow.id)
  end

  # Validate that sub-flow nesting doesn't exceed maximum depth
  # @param workflow [Workflow] The workflow to validate
  def validate_max_depth(workflow)
    depth = calculate_max_depth(workflow, Set.new)

    return unless depth > MAX_DEPTH

    add_finding(:max_depth_exceeded, "Sub-flow nesting exceeds maximum depth of #{MAX_DEPTH} levels",
                details: { depth: depth, max_depth: MAX_DEPTH })
  end

  # Calculate the maximum nesting depth of sub-flows
  # @param workflow [Workflow] The current workflow
  # @param visited [Set<Integer>] Set of visited workflow IDs (to prevent infinite loops)
  # @return [Integer] The maximum depth
  # Memoised, and the path set is mutated rather than copied per branch.
  #
  # `visited.dup` on every child had the same exponential shape as the cycle walk
  # above, for the same reason: nothing remembered a node's depth, so a node
  # reachable by many paths was recomputed once per path. The longest path out of
  # a node does not depend on how you arrived, so one memo per workflow is
  # correct on an acyclic graph.
  #
  # On a cyclic graph the number is entry-point dependent and always has been —
  # the grey guard returns 0 for a back edge — but a cycle is reported by
  # validate_no_circular_subflows and refuses the workflow anyway, so the depth
  # figure never stands alone.
  def calculate_max_depth(workflow, on_path)
    return 0 if workflow.nil?
    return 0 if on_path.include?(workflow.id)

    cached = @depth_cache[workflow.id]
    return cached if cached

    on_path.add(workflow.id)

    target_ids = extract_subflow_target_ids(workflow)
    depth = if target_ids.empty?
              1
            else
              1 + (target_ids.map { |tid| calculate_max_depth(@workflows_cache[tid], on_path) }.max || 0)
            end

    on_path.delete(workflow.id)
    @depth_cache[workflow.id] = depth
  end
end
