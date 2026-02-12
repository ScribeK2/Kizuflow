# Extracted execution logic for Simulation model.
# Contains determine_next_step_index and execute_with_limits.
module SimulationExecution
  extend ActiveSupport::Concern

  # Determine the next step index based on the current step's branches/conditions.
  # Evaluates multi-branch format first, then falls back to legacy true_path/false_path.
  def determine_next_step_index(step, results)
    Rails.logger.debug { "[Simulation ##{id}] determine_next_step_index: step='#{step['title']}', type=#{step['type']}" }
    Rails.logger.debug { "[Simulation ##{id}] Results: #{results.inspect}" }

    # First check for universal jumps (works for all step types)
    jump_result = check_jumps(step, results)
    if jump_result
      Rails.logger.debug { "[Simulation ##{id}] Jump matched -> index #{jump_result}" }
      return jump_result
    end

    # Handle multi-branch format (new)
    if step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
      determine_next_from_branches(step, results)
    else
      determine_next_from_legacy(step, results)
    end
  end

  # Internal execution method with iteration limits
  def execute_with_limits
    path = []
    results = {}
    current_step_index = 0
    iteration_count = 0

    while current_step_index < workflow.steps.length
      step = workflow.steps[current_step_index]
      break unless step

      iteration_count += 1
      if iteration_count > self.class::MAX_ITERATIONS
        self.status = 'error'
        self.results = results.merge('_error' => "Exceeded maximum iterations (#{self.class::MAX_ITERATIONS})")
        self.execution_path = path
        save
        raise Simulation::SimulationIterationLimit, "Simulation exceeded maximum of #{self.class::MAX_ITERATIONS} iterations"
      end

      path << {
        step_index: current_step_index,
        step_title: step['title'],
        step_type: step['type']
      }

      current_step_index = execute_step(step, current_step_index, path, results)
    end

    self.status = 'completed'
    self.current_step_index = current_step_index
    self.execution_path = path
    self.results = results
    save
  rescue StandardError => e
    Rails.logger.error "Simulation execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  # Execute a single step and return the next step index.
  def execute_step(step, current_step_index, path, results)
    case step['type']
    when 'question'
      execute_question_step(step, current_step_index, path, results)
    when 'decision', 'simple_decision'
      execute_decision_step(step, current_step_index, path, results)
    when 'action'
      path.last[:action_completed] = true
      results[step['title']] = "Action executed"
      current_step_index + 1
    else
      current_step_index + 1
    end
  end

  def execute_question_step(step, current_step_index, path, results)
    answer = nil
    if step['variable_name'].present?
      answer = inputs[step['variable_name']]
    end
    answer = inputs[current_step_index.to_s] if answer.blank?
    answer = inputs[step['title']] if answer.blank?

    results[step['title']] = answer if answer.present?
    results[step['variable_name']] = answer if step['variable_name'].present? && answer.present?
    path.last[:answer] = answer
    current_step_index + 1
  end

  def execute_decision_step(step, current_step_index, path, results)
    if step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
      execute_branch_decision(step, current_step_index, path, results)
    else
      execute_legacy_decision(step, current_step_index, path, results)
    end
  end

  def execute_branch_decision(step, current_step_index, path, results)
    matched_branch = nil

    step['branches'].each do |branch|
      branch_condition = branch['condition'] || branch[:condition]
      branch_path = branch['path'] || branch[:path]

      next unless branch_condition.present? && branch_path.present?

      condition_result = evaluate_condition_string(branch_condition, results)
      next unless condition_result

      matched_branch = branch
      path.last[:condition_result] = "matched: #{branch_condition}"
      path.last[:matched_branch] = branch_condition
      break
    end

    if matched_branch
      branch_path = matched_branch['path'] || matched_branch[:path]
      resolve_step_to_index(branch_path, current_step_index)
    elsif step['else_path'].present?
      path.last[:condition_result] = "else"
      resolve_step_to_index(step['else_path'], current_step_index)
    else
      path.last[:condition_result] = "no match"
      current_step_index + 1
    end
  end

  def execute_legacy_decision(step, current_step_index, path, results)
    condition_result = evaluate_condition(step, results)
    path.last[:condition_result] = condition_result

    if condition_result && step['true_path'].present?
      resolve_step_to_index(step['true_path'], current_step_index)
    elsif !condition_result && step['false_path'].present?
      resolve_step_to_index(step['false_path'], current_step_index)
    else
      current_step_index + 1
    end
  end

  # Resolve a step reference to an index, falling back to next step.
  def resolve_step_to_index(reference, current_step_index)
    next_step = resolve_step_reference(reference)
    if next_step
      next_index = workflow.steps.index(next_step)
      return next_index unless next_index.nil?
    end
    current_step_index + 1
  end

  # --- determine_next_step_index helpers ---

  def determine_next_from_branches(step, results)
    step['branches'].each_with_index do |branch, idx|
      branch_condition = branch['condition'] || branch[:condition]
      branch_path = branch['path'] || branch[:path]

      Rails.logger.debug { "[Simulation ##{id}] Branch #{idx + 1}: condition='#{branch_condition}', path='#{branch_path}'" }

      next unless branch_condition.present? && branch_path.present?

      condition_result = evaluate_condition_string(branch_condition, results)
      Rails.logger.debug { "[Simulation ##{id}] Branch #{idx + 1} evaluated: #{condition_result}" }

      next unless condition_result

      next_step = resolve_step_reference(branch_path)
      if next_step
        next_index = workflow.steps.index(next_step)
        Rails.logger.debug { "[Simulation ##{id}] Branch matched -> '#{next_step['title']}' at index #{next_index}" }
        return next_index unless next_index.nil?
      else
        Rails.logger.warn "[Simulation ##{id}] Branch path '#{branch_path}' not found!"
      end
    end

    # No branch matched, check else_path
    if step['else_path'].present?
      Rails.logger.debug { "[Simulation ##{id}] No branch matched, trying else_path: '#{step['else_path']}'" }
      next_step = resolve_step_reference(step['else_path'])
      if next_step
        next_index = workflow.steps.index(next_step)
        Rails.logger.debug { "[Simulation ##{id}] else_path resolved -> index #{next_index}" }
        return next_index unless next_index.nil?
      else
        Rails.logger.warn "[Simulation ##{id}] else_path '#{step['else_path']}' not found!"
      end
    end

    # Default: move to next step
    next_index = current_step_index + 1
    Rails.logger.debug { "[Simulation ##{id}] Defaulting to next step: #{next_index}" }
    next_index < workflow.steps.length ? next_index : workflow.steps.length
  end

  def determine_next_from_legacy(step, results)
    Rails.logger.debug { "[Simulation ##{id}] Using legacy format (true_path/false_path)" }
    condition_result = evaluate_condition(step, results)
    Rails.logger.debug { "[Simulation ##{id}] Legacy condition evaluated: #{condition_result}" }

    if condition_result && step['true_path'].present?
      Rails.logger.debug { "[Simulation ##{id}] Following true_path: '#{step['true_path']}'" }
      next_step = resolve_step_reference(step['true_path'])
      if next_step
        next_index = workflow.steps.index(next_step)
        Rails.logger.debug { "[Simulation ##{id}] true_path resolved -> index #{next_index}" }
        return next_index unless next_index.nil?
      else
        Rails.logger.warn "[Simulation ##{id}] true_path '#{step['true_path']}' not found!"
      end
    elsif !condition_result && step['false_path'].present?
      Rails.logger.debug { "[Simulation ##{id}] Following false_path: '#{step['false_path']}'" }
      next_step = resolve_step_reference(step['false_path'])
      if next_step
        next_index = workflow.steps.index(next_step)
        Rails.logger.debug { "[Simulation ##{id}] false_path resolved -> index #{next_index}" }
        return next_index unless next_index.nil?
      else
        Rails.logger.warn "[Simulation ##{id}] false_path '#{step['false_path']}' not found!"
      end
    end

    # Default: move to next step
    next_index = current_step_index + 1
    Rails.logger.debug { "[Simulation ##{id}] Legacy defaulting to next step: #{next_index}" }
    next_index < workflow.steps.length ? next_index : workflow.steps.length
  end
end
