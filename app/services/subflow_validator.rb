# frozen_string_literal: true

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
#     validator.errors # => ["Circular sub-flow reference: Workflow A -> Workflow B -> Workflow A"]
#   end
class SubflowValidator
  attr_reader :errors

  MAX_DEPTH = 10 # Maximum sub-flow nesting depth

  # Initialize with the workflow ID to validate
  # @param workflow_id [Integer] The ID of the workflow to validate
  def initialize(workflow_id)
    @workflow_id = workflow_id
    @errors = []
  end

  # Run validation and return true if no circular references exist
  def valid?
    @errors = []

    workflow = Workflow.find_by(id: @workflow_id)
    return true unless workflow

    validate_no_circular_subflows(workflow, [])
    validate_max_depth(workflow)

    @errors.empty?
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

  # Recursively check for circular sub-flow references
  # Uses DFS with path tracking to detect cycles
  # @param workflow [Workflow] The current workflow being validated
  # @param visited_path [Array<Integer>] Path of workflow IDs visited so far
  def validate_no_circular_subflows(workflow, visited_path)
    return if workflow.nil?

    # Check if we've already visited this workflow in the current path
    if visited_path.include?(workflow.id)
      cycle_start = visited_path.index(workflow.id)
      cycle_path = visited_path[cycle_start..] + [workflow.id]
      cycle_names = cycle_path.map { |id| workflow_name(id) }
      @errors << "Circular sub-flow reference: #{cycle_names.join(' -> ')}"
      return
    end

    # Get all sub-flow step references
    subflow_workflow_ids = workflow.referenced_workflow_ids
    return if subflow_workflow_ids.empty?

    # Add current workflow to the path
    current_path = visited_path + [workflow.id]

    # Recursively check each referenced workflow
    subflow_workflow_ids.each do |target_id|
      target_workflow = Workflow.find_by(id: target_id)
      next unless target_workflow

      validate_no_circular_subflows(target_workflow, current_path)
    end
  end

  # Validate that sub-flow nesting doesn't exceed maximum depth
  # @param workflow [Workflow] The workflow to validate
  def validate_max_depth(workflow)
    depth = calculate_max_depth(workflow, Set.new)

    if depth > MAX_DEPTH
      @errors << "Sub-flow nesting exceeds maximum depth of #{MAX_DEPTH} levels"
    end
  end

  # Calculate the maximum nesting depth of sub-flows
  # @param workflow [Workflow] The current workflow
  # @param visited [Set<Integer>] Set of visited workflow IDs (to prevent infinite loops)
  # @return [Integer] The maximum depth
  def calculate_max_depth(workflow, visited)
    return 0 if workflow.nil?
    return 0 if visited.include?(workflow.id)

    visited.add(workflow.id)

    subflow_workflow_ids = workflow.referenced_workflow_ids
    return 1 if subflow_workflow_ids.empty?

    max_child_depth = subflow_workflow_ids.map do |target_id|
      target_workflow = Workflow.find_by(id: target_id)
      calculate_max_depth(target_workflow, visited.dup)
    end.max || 0

    1 + max_child_depth
  end

  # Get workflow name for error messages
  def workflow_name(workflow_id)
    workflow = Workflow.find_by(id: workflow_id)
    workflow&.title || "Workflow ##{workflow_id}"
  end
end
