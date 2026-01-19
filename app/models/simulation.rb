require 'timeout'

class Simulation < ApplicationRecord
  belongs_to :workflow
  belongs_to :user

  # Status constants
  STATUSES = %w[active completed stopped timeout error].freeze

  # Simulation limits to prevent infinite loops and DoS
  MAX_ITERATIONS = ENV.fetch("SIMULATION_MAX_ITERATIONS", 1000).to_i
  MAX_EXECUTION_TIME = ENV.fetch("SIMULATION_MAX_SECONDS", 30).to_i  # seconds
  MAX_CONDITION_DEPTH = 50  # Max nested condition evaluations per step

  # Custom error classes
  class SimulationTimeout < StandardError; end
  class SimulationIterationLimit < StandardError; end

  # JSON columns - automatically serialized/deserialized
  
  # Initialize execution_path and results as empty arrays/hashes if needed
  before_save :initialize_execution_data
  
  # Validate status
  validates :status, inclusion: { in: STATUSES }, allow_nil: false
  
  # Track iteration count for step-by-step processing
  attr_accessor :iteration_count
  
  def initialize_execution_data
    self.execution_path ||= []
    self.results ||= {}
    self.inputs ||= {}
  end
  
  # Get the current step
  def current_step
    return nil unless workflow&.steps&.present?
    workflow.steps[current_step_index] if current_step_index < workflow.steps.length
  end
  
  # Check if simulation is stopped
  def stopped?
    status == 'stopped'
  end
  
  # Check if simulation is complete
  def complete?
    return true if status == 'completed'
    return true if stopped?
    return true unless workflow&.steps&.present?
    current_step_index >= workflow.steps.length
  end
  
  # Stop the workflow execution
  def stop!(step_index = nil)
    update!(
      status: 'stopped',
      stopped_at_step_index: step_index || current_step_index
    )
  end
  
  # Resolve a checkpoint step
  def resolve_checkpoint!(resolved: true, notes: nil)
    step = current_step
    return false unless step&.dig('type') == 'checkpoint'
    return false if stopped?
    return false if complete?
    
    # Initialize execution_path if needed
    initialize_execution_data
    
    # Add checkpoint to execution path
    path_entry = {
      step_index: current_step_index,
      step_title: step['title'],
      step_type: 'checkpoint',
      resolved: resolved,
      resolved_at: Time.current.iso8601
    }
    path_entry[:notes] = notes if notes.present?
    
    self.execution_path << path_entry
    
    if resolved
      # Mark workflow as completed
      self.status = 'completed'
      self.current_step_index = workflow.steps.length # Mark as complete
      self.results ||= {}
      self.results[step['title']] = "Issue resolved - workflow completed"
    else
      # Continue to next step
      self.current_step_index += 1
      self.results ||= {}
      self.results[step['title']] = "Issue not resolved - continuing workflow"
    end
    
    save
  end
  
  # Process a single step and advance
  # Returns false if step can't be processed, true otherwise
  # Raises SimulationIterationLimit if max iterations exceeded
  def process_step(answer = nil)
    return false if complete?
    return false if stopped?
    return false if status == 'timeout' || status == 'error'
    
    step = current_step
    return false unless step
    
    # Track iterations to prevent infinite loops in step-by-step mode
    self.iteration_count ||= execution_path&.length || 0
    self.iteration_count += 1
    
    if iteration_count > MAX_ITERATIONS
      self.status = 'error'
      self.results ||= {}
      self.results['_error'] = "Simulation exceeded maximum iterations (#{MAX_ITERATIONS})"
      save
      raise SimulationIterationLimit, "Simulation exceeded maximum of #{MAX_ITERATIONS} steps"
    end
    
    # Initialize execution_path if needed
    initialize_execution_data
    
    # Add step to execution path
    path_entry = {
      step_index: current_step_index,
      step_title: step['title'],
      step_type: step['type']
    }
    
    case step['type']
    when 'question'
      # Store the answer
      input_key = step['variable_name'].present? ? step['variable_name'] : current_step_index.to_s
      self.inputs ||= {}
      self.inputs[input_key] = answer if answer.present?

      # Also store by title for lookup
      self.inputs[step['title']] = answer if answer.present?

      # Update results
      self.results ||= {}
      self.results[step['title']] = answer if answer.present?
      self.results[step['variable_name']] = answer if step['variable_name'].present? && answer.present?

      path_entry[:answer] = answer
      self.execution_path << path_entry

      # Check for jumps or move to next step
      next_step_index = determine_next_step_index(step, self.results)
      self.current_step_index = next_step_index

    when 'decision', 'simple_decision'
      # Process decision based on current results
      # simple_decision is a variant used for yes/no routing in workflow builder
      self.results ||= {}
      next_step_index = determine_next_step_index(step, self.results)

      path_entry[:condition_result] = "routing to step #{next_step_index + 1}"
      self.execution_path << path_entry

      self.current_step_index = next_step_index

    when 'action'
      # Actions are automatically completed
      path_entry[:action_completed] = true
      self.results ||= {}
      self.results[step['title']] = "Action executed"
      
      # Process output_fields if defined
      if step['output_fields'].present? && step['output_fields'].is_a?(Array)
        step['output_fields'].each do |output_field|
          next unless output_field.is_a?(Hash) && output_field['name'].present?
          
          variable_name = output_field['name'].to_s
          # Interpolate the value using existing results
          raw_value = output_field['value'] || ""
          interpolated_value = VariableInterpolator.interpolate(raw_value, self.results)
          
          # Store the output variable in results
          self.results[variable_name] = interpolated_value
        end
      end
      
      self.execution_path << path_entry

      # Check for jumps or move to next step
      next_step_index = determine_next_step_index(step, self.results)
      self.current_step_index = next_step_index
      
    when 'checkpoint'
      # Checkpoints don't auto-advance - user must resolve them
      # Don't add to execution_path yet - that happens when resolved
      # Don't increment current_step_index - stay on checkpoint
      return false  # Return false to indicate no advancement
      
    else
      # Unknown step type, check for jumps or just advance
      next_step_index = determine_next_step_index(step, self.results)
      self.current_step_index = next_step_index
    end
    
    # Mark as completed if we've reached the end
    if current_step_index >= workflow.steps.length && status != 'stopped'
      self.status = 'completed'
    end
    
    save
  end
  
  # Check for universal jumps on any step type
  def check_jumps(step, results)
    return nil unless step['jumps'].present? && step['jumps'].is_a?(Array)

    step['jumps'].each do |jump|
      jump_condition = jump['condition'] || jump[:condition]
      jump_next_step_id = jump['next_step_id'] || jump[:next_step_id]

      if jump_condition.present? && jump_next_step_id.present?
        # For question steps, condition might be the answer value
        # For action steps, condition might be 'completed' or similar
        # For decision steps, condition can be complex expressions

        condition_result = case step['type']
        when 'question'
          # For questions, check if the answer matches the condition
          current_answer = results[step['title']] || results[step['variable_name']]
          current_answer.to_s == jump_condition.to_s
        when 'action'
          # For actions, check if action completed or custom condition
          if jump_condition == 'completed'
            true  # Actions are considered completed when they reach this point
          else
            evaluate_condition_string(jump_condition, results)
          end
        when 'decision'
          # For decisions, use full condition evaluation
          evaluate_condition_string(jump_condition, results)
        else
          # Default to condition evaluation
          evaluate_condition_string(jump_condition, results)
        end

        if condition_result
          next_step = find_step_by_id(jump_next_step_id)
          if next_step
            return workflow.steps.index(next_step)
          end
        end
      end
    end

    nil  # No jump matched
  end

  # Determine next step index based on decision logic
  def determine_next_step_index(step, results)
    # First check for universal jumps (works for all step types)
    jump_result = check_jumps(step, results)
    return jump_result unless jump_result.nil?
    # Handle multi-branch format (new)
    if step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
      # Evaluate branches in order, take first match
      step['branches'].each do |branch|
        branch_condition = branch['condition'] || branch[:condition]
        branch_path = branch['path'] || branch[:path]
        
        if branch_condition.present? && branch_path.present?
          condition_result = evaluate_condition_string(branch_condition, results)
          if condition_result
            # Use ID-based resolution (supports both IDs and titles for backward compatibility)
            next_step = resolve_step_reference(branch_path)
            if next_step
              next_index = workflow.steps.index(next_step)
              return next_index unless next_index.nil?
            end
          end
        end
      end
      
      # No branch matched, check else_path
      if step['else_path'].present?
        # Use ID-based resolution (supports both IDs and titles for backward compatibility)
        next_step = resolve_step_reference(step['else_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      end
      
      # Default: move to next step - check bounds
      next_index = current_step_index + 1
      return next_index < workflow.steps.length ? next_index : workflow.steps.length
    else
      # Legacy format (true_path/false_path)
      condition_result = evaluate_condition(step, results)
      
      if condition_result && step['true_path'].present?
        # Use ID-based resolution (supports both IDs and titles for backward compatibility)
        next_step = resolve_step_reference(step['true_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      elsif !condition_result && step['false_path'].present?
        # Use ID-based resolution (supports both IDs and titles for backward compatibility)
        next_step = resolve_step_reference(step['false_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      end
      
      # Default: move to next step - check bounds
      next_index = current_step_index + 1
      return next_index < workflow.steps.length ? next_index : workflow.steps.length
    end
  end

  def execute
    return false unless workflow.present? && inputs.present?

    # Wrap execution with timeout protection
    Timeout.timeout(MAX_EXECUTION_TIME, SimulationTimeout) do
      execute_with_limits
    end
  rescue SimulationTimeout => e
    self.status = 'timeout'
    self.results ||= {}
    self.results['_error'] = "Simulation timed out after #{MAX_EXECUTION_TIME} seconds"
    save
    Rails.logger.warn "Simulation #{id} timed out for workflow #{workflow_id}"
    false
  rescue SimulationIterationLimit => e
    Rails.logger.warn "Simulation #{id} hit iteration limit for workflow #{workflow_id}"
    false
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
      
      # Prevent infinite loops with iteration counter
      iteration_count += 1
      if iteration_count > MAX_ITERATIONS
        self.status = 'error'
        self.results = results.merge('_error' => "Exceeded maximum iterations (#{MAX_ITERATIONS})")
        self.execution_path = path
        save
        raise SimulationIterationLimit, "Simulation exceeded maximum of #{MAX_ITERATIONS} iterations"
      end

      path << {
        step_index: current_step_index,
        step_title: step['title'],
        step_type: step['type']
      }

      case step['type']
      when 'question'
        # Try to get answer by variable_name first (most reliable), then by index, then by title
        answer = nil
        if step['variable_name'].present?
          answer = inputs[step['variable_name']]
        end
        if answer.blank?
          answer = inputs[current_step_index.to_s]
        end
        if answer.blank?
          answer = inputs[step['title']]
        end
        
        results[step['title']] = answer if answer.present?
        results[step['variable_name']] = answer if step['variable_name'].present? && answer.present?
        path.last[:answer] = answer
        current_step_index += 1

      when 'decision', 'simple_decision'
        # Handle multi-branch format (new)
        # simple_decision is a variant used for yes/no routing in workflow builder
        if step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
          matched_branch = nil
          
          # Evaluate branches in order, take first match
          step['branches'].each do |branch|
            branch_condition = branch['condition'] || branch[:condition]
            branch_path = branch['path'] || branch[:path]
            
            if branch_condition.present? && branch_path.present?
              condition_result = evaluate_condition_string(branch_condition, results)
              if condition_result
                matched_branch = branch
                path.last[:condition_result] = "matched: #{branch_condition}"
                path.last[:matched_branch] = branch_condition
                break
              end
            end
          end
          
          # If a branch matched, use its path
          if matched_branch
            branch_path = matched_branch['path'] || matched_branch[:path]
            # Use ID-based resolution (supports both IDs and titles for backward compatibility)
            next_step = resolve_step_reference(branch_path)
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
            else
              current_step_index += 1
            end
          elsif step['else_path'].present?
            # No branch matched, use else_path
            # Use ID-based resolution (supports both IDs and titles for backward compatibility)
            next_step = resolve_step_reference(step['else_path'])
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
              path.last[:condition_result] = "else"
            else
              current_step_index += 1
            end
          else
            # No branch matched and no else_path, continue to next step
            path.last[:condition_result] = "no match"
            current_step_index += 1
          end
        else
          # Legacy format (true_path/false_path)
          condition_result = evaluate_condition(step, results)
          path.last[:condition_result] = condition_result
          
          if condition_result && step['true_path'].present?
            # Use ID-based resolution (supports both IDs and titles for backward compatibility)
            next_step = resolve_step_reference(step['true_path'])
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
            else
              current_step_index += 1
            end
          elsif !condition_result && step['false_path'].present?
            # Use ID-based resolution (supports both IDs and titles for backward compatibility)
            next_step = resolve_step_reference(step['false_path'])
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
            else
              current_step_index += 1
            end
          else
            current_step_index += 1
          end
        end

      when 'action'
        path.last[:action_completed] = true
        results[step['title']] = "Action executed"
        current_step_index += 1
      else
        current_step_index += 1
      end
    end

    # Mark simulation as completed when all steps have been processed
    self.status = 'completed'
    self.current_step_index = current_step_index
    self.execution_path = path
    self.results = results
    save
  rescue => e
    Rails.logger.error "Simulation execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  private

  def evaluate_condition_string(condition_string, results)
    ConditionEvaluator.evaluate(condition_string, results)
  end

  def evaluate_condition(step, results)
    condition = step['condition']
    return false unless condition.present?
    
    evaluate_condition_string(condition, results)
  end

  def find_step_by_title(title)
    workflow.steps.find { |s| s['title'] == title }
  end

  def find_step_by_id(id)
    workflow.steps.find { |s| s['id'] == id }
  end

  # Resolve a step reference (ID or title) to a step object
  # Prefers ID-based lookup but falls back to title for backward compatibility
  # Returns the step hash or nil if not found
  def resolve_step_reference(reference)
    return nil if reference.blank?
    
    # First try to resolve to ID using workflow's helper (handles both IDs and titles)
    step_id = workflow.resolve_step_reference_to_id(reference)
    return find_step_by_id(step_id) if step_id.present?
    
    # Fallback to title-based lookup for backward compatibility
    find_step_by_title(reference)
  end
end

