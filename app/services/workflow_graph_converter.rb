# frozen_string_literal: true

# Converts linear (array-based) workflows to graph (DAG-based) workflows.
# Maps sequential steps to explicit transitions while preserving decision branches.
#
# Usage:
#   converter = WorkflowGraphConverter.new(workflow)
#   converted_steps = converter.convert
#   if converted_steps
#     workflow.steps = converted_steps
#     workflow.graph_mode = true
#     workflow.save
#   end
#
# The converter:
# - Preserves all existing step data
# - Converts sequential order to explicit transitions
# - Maps decision branches to graph transitions
# - Handles legacy decision format (true_path/false_path)
# - Validates the resulting graph structure
class WorkflowGraphConverter
  attr_reader :workflow, :errors

  def initialize(workflow)
    @workflow = workflow
    @errors = []
  end

  # Convert the workflow's steps to graph format
  # @return [Array<Hash>, nil] Converted steps array or nil if conversion failed
  def convert
    @errors = []

    return nil unless workflow&.steps.present?
    return workflow.steps if workflow.graph_mode?

    steps = deep_copy(workflow.steps)

    # Ensure all steps have IDs
    ensure_step_ids(steps)

    # Build step ID lookup
    step_id_to_index = build_step_index_map(steps)

    # Convert each step to graph format
    steps.each_with_index do |step, index|
      convert_step_to_graph(step, index, steps, step_id_to_index)
    end

    # Validate the converted graph
    if validate_converted_graph(steps)
      steps
    else
      nil
    end
  end

  # Check if conversion would be valid without modifying the workflow
  # @return [Boolean]
  def valid_for_conversion?
    @errors = []

    return false unless workflow&.steps.present?
    return true if workflow.graph_mode?

    steps = deep_copy(workflow.steps)
    ensure_step_ids(steps)
    step_id_to_index = build_step_index_map(steps)

    steps.each_with_index do |step, index|
      convert_step_to_graph(step, index, steps, step_id_to_index)
    end

    validate_converted_graph(steps)
  end

  private

  # Deep copy the steps array to avoid modifying the original
  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

  # Ensure all steps have UUIDs
  def ensure_step_ids(steps)
    steps.each do |step|
      step['id'] ||= SecureRandom.uuid if step.is_a?(Hash)
    end
  end

  # Build a map of step ID to array index
  def build_step_index_map(steps)
    map = {}
    steps.each_with_index do |step, index|
      map[step['id']] = index if step.is_a?(Hash) && step['id']
    end
    map
  end

  # Convert a single step to graph format by adding transitions
  def convert_step_to_graph(step, index, steps, step_id_to_index)
    return unless step.is_a?(Hash)

    step['transitions'] ||= []

    case step['type']
    when 'decision', 'simple_decision'
      convert_decision_step(step, index, steps, step_id_to_index)
    when 'sub_flow'
      # Sub-flow steps already have transitions defined or need next step
      convert_subflow_step(step, index, steps)
    else
      # All other steps: add transition to next step (if exists)
      convert_sequential_step(step, index, steps)
    end
  end

  # Convert a decision step's branches to graph transitions
  def convert_decision_step(step, index, steps, step_id_to_index)
    transitions = []

    # Handle multi-branch format
    if step['branches'].present? && step['branches'].is_a?(Array)
      step['branches'].each do |branch|
        condition = branch['condition'] || branch[:condition]
        path = branch['path'] || branch[:path]

        next unless path.present?

        target_uuid = resolve_path_to_uuid(path, steps, step_id_to_index)
        if target_uuid
          transitions << {
            'target_uuid' => target_uuid,
            'condition' => condition,
            'label' => "If #{condition}"
          }
        else
          @errors << "Step '#{step['title']}': Branch path '#{path}' could not be resolved"
        end
      end
    end

    # Handle legacy format (true_path/false_path)
    if step['true_path'].present?
      target_uuid = resolve_path_to_uuid(step['true_path'], steps, step_id_to_index)
      if target_uuid
        condition = step['condition'] || 'true'
        transitions << {
          'target_uuid' => target_uuid,
          'condition' => condition,
          'label' => 'If true'
        }
      end
    end

    if step['false_path'].present?
      target_uuid = resolve_path_to_uuid(step['false_path'], steps, step_id_to_index)
      if target_uuid
        # Negate the condition for false path
        condition = step['condition'] ? negate_condition(step['condition']) : 'false'
        transitions << {
          'target_uuid' => target_uuid,
          'condition' => condition,
          'label' => 'If false'
        }
      end
    end

    # Handle else_path (default/fallback transition)
    if step['else_path'].present?
      target_uuid = resolve_path_to_uuid(step['else_path'], steps, step_id_to_index)
      if target_uuid
        transitions << {
          'target_uuid' => target_uuid,
          'condition' => nil, # No condition = default transition
          'label' => 'Else'
        }
      end
    end

    # If no transitions defined but has next step, add default transition
    if transitions.empty? && index < steps.length - 1
      next_step = steps[index + 1]
      if next_step && next_step['id']
        transitions << {
          'target_uuid' => next_step['id'],
          'condition' => nil,
          'label' => 'Default'
        }
      end
    end

    step['transitions'] = transitions
  end

  # Convert a sub-flow step to graph format
  def convert_subflow_step(step, index, steps)
    return if step['transitions'].present? && step['transitions'].any?

    # Add transition to next step after sub-flow completes
    if index < steps.length - 1
      next_step = steps[index + 1]
      if next_step && next_step['id']
        step['transitions'] = [{
          'target_uuid' => next_step['id'],
          'condition' => nil,
          'label' => 'After sub-flow'
        }]
      end
    else
      step['transitions'] = [] # Terminal sub-flow
    end
  end

  # Convert a sequential step (question, action, checkpoint) to graph format
  def convert_sequential_step(step, index, steps)
    # Check for jumps and add those as transitions
    if step['jumps'].present? && step['jumps'].is_a?(Array)
      step['jumps'].each do |jump|
        condition = jump['condition'] || jump[:condition]
        next_step_id = jump['next_step_id'] || jump[:next_step_id]

        if next_step_id.present?
          step['transitions'] << {
            'target_uuid' => next_step_id,
            'condition' => condition,
            'label' => "Jump: #{condition}"
          }
        end
      end
    end

    # Add default transition to next step (unless it's the last step or checkpoint)
    if step['type'] != 'checkpoint' && index < steps.length - 1
      next_step = steps[index + 1]
      if next_step && next_step['id']
        # Only add if no unconditional jump already exists
        has_default = step['transitions'].any? { |t| t['condition'].blank? }
        unless has_default
          step['transitions'] << {
            'target_uuid' => next_step['id'],
            'condition' => nil,
            'label' => nil
          }
        end
      end
    end
  end

  # Resolve a path reference (title or ID) to a step UUID
  def resolve_path_to_uuid(path, steps, step_id_to_index)
    return nil if path.blank?

    # Check if it's already a UUID
    if path.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      return path if step_id_to_index.key?(path)
    end

    # Search by title
    step = steps.find { |s| s['title'] == path }
    step&.dig('id')
  end

  # Negate a condition for the false path
  def negate_condition(condition)
    return nil if condition.blank?

    # Simple negation: swap == and !=
    if condition.include?('==')
      condition.gsub('==', '!=')
    elsif condition.include?('!=')
      condition.gsub('!=', '==')
    else
      # For other operators, wrap with NOT logic (simplified)
      "!(#{condition})"
    end
  end

  # Validate the converted graph structure
  def validate_converted_graph(steps)
    return false if steps.empty?

    # Build graph steps hash
    graph_steps = {}
    steps.each do |step|
      graph_steps[step['id']] = step if step['id']
    end

    start_uuid = steps.first['id']
    validator = GraphValidator.new(graph_steps, start_uuid)

    unless validator.valid?
      @errors.concat(validator.errors)
      return false
    end

    true
  end
end
