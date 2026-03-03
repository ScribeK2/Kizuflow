# Resolves the next step in a graph-mode workflow based on current step and results.
# Handles transition condition evaluation and sub-flow detection.
#
# Usage:
#   resolver = StepResolver.new(workflow)
#   next_uuid = resolver.resolve_next(current_step, results)
#
# Returns:
#   - UUID of the next step to execute
#   - :sub_flow marker with sub-flow info if a sub-flow step is hit
#   - nil if no valid transition or terminal node
class StepResolver
  # Marker returned when a sub-flow step is encountered
  SubflowMarker = Struct.new(:target_workflow_id, :variable_mapping, :step_uuid, keyword_init: true)

  attr_reader :workflow

  def initialize(workflow)
    @workflow = workflow
    @graph_steps = workflow.graph_mode? ? workflow.graph_steps : nil
  end

  # Resolve the next step UUID from the current step
  # @param step [Hash] The current step hash
  # @param results [Hash] Current scenario results (variable values)
  # @return [String, SubflowMarker, nil] Next step UUID, sub-flow marker, or nil
  def resolve_next(step, results)
    return nil unless step

    # Check if current step is a sub-flow
    if step['type'] == 'sub_flow'
      return SubflowMarker.new(
        target_workflow_id: step['target_workflow_id'],
        variable_mapping: step['variable_mapping'] || {},
        step_uuid: step['id']
      )
    end

    resolve_graph_next(step, results)
  end

  # Resolve the next step after a sub-flow completes (bypasses SubflowMarker interception).
  # This directly evaluates the sub_flow step's outgoing transitions/linear position
  # to determine where the parent scenario should resume.
  # @param step [Hash] The sub_flow step that just completed
  # @param results [Hash] Current scenario results
  # @return [String, nil] Next step UUID or nil
  def resolve_next_after_subflow(step, results)
    return nil unless step

    resolve_graph_next(step, results)
  end

  # Find the start step for this workflow
  # @return [Hash, nil] The start step hash or nil
  def start_step
    @workflow.start_node
  end

  # Check if a step is a terminal node (no outgoing transitions)
  # @param step [Hash] The step to check
  # @return [Boolean]
  def terminal?(step)
    return false unless step

    # Resolve steps are always terminal regardless of mode
    return true if step['type'] == 'resolve'

    transitions = step['transitions'] || []
    transitions.empty? && step['type'] != 'sub_flow'
  end

  private

  # Resolve next step in graph mode using transitions
  def resolve_graph_next(step, results)
    transitions = step['transitions'] || []
    return nil if transitions.empty?

    # First, check for universal jumps (same as linear mode)
    jump_result = check_jumps(step, results)
    return jump_result if jump_result

    # Evaluate transitions in order, return first match
    transitions.each do |transition|
      target_uuid = transition['target_uuid']
      next if target_uuid.blank?

      condition = transition['condition']

      # If no condition, this is the default transition
      if condition.blank?
        return target_uuid
      end

      # Evaluate the condition
      if evaluate_condition(condition, results)
        return target_uuid
      end
    end

    # No transition matched - look for a default (unconditional) transition
    default_transition = transitions.find { |t| t['condition'].blank? }
    default_transition&.dig('target_uuid')
  end

  # Check universal jumps on any step type
  def check_jumps(step, results)
    return nil unless step['jumps'].present? && step['jumps'].is_a?(Array)

    step['jumps'].each do |jump|
      jump_condition = jump['condition'] || jump[:condition]
      jump_next_step_id = jump['next_step_id'] || jump[:next_step_id]

      next unless jump_condition.present? && jump_next_step_id.present?

      condition_result = case step['type']
                         when 'question'
                           # For questions, check if the answer matches the condition
                           current_answer = results[step['title']] || results[step['variable_name']]
                           current_answer.to_s == jump_condition.to_s
                         when 'action'
                           # For actions, check if action completed or custom condition
                           jump_condition == 'completed' || evaluate_condition(jump_condition, results)
                         else
                           evaluate_condition(jump_condition, results)
                         end

      return jump_next_step_id if condition_result
    end

    nil
  end

  # Evaluate a condition string against results
  def evaluate_condition(condition, results)
    return false if condition.blank?

    ConditionEvaluator.evaluate(condition, results)
  end

end
