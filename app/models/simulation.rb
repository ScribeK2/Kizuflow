class Simulation < ApplicationRecord
  belongs_to :workflow
  belongs_to :user

  # Status constants
  STATUSES = %w[active completed stopped].freeze

  # JSON columns - automatically serialized/deserialized
  
  # Initialize execution_path and results as empty arrays/hashes if needed
  before_save :initialize_execution_data
  
  # Validate status
  validates :status, inclusion: { in: STATUSES }, allow_nil: false
  
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
  def process_step(answer = nil)
    return false if complete?
    return false if stopped?
    
    step = current_step
    return false unless step
    
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
      
      # Move to next step
      self.current_step_index += 1
      
    when 'decision'
      # Process decision based on current results
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
      self.execution_path << path_entry
      
      # Move to next step
      self.current_step_index += 1
      
    when 'checkpoint'
      # Checkpoints don't auto-advance - user must resolve them
      # Don't add to execution_path yet - that happens when resolved
      # Don't increment current_step_index - stay on checkpoint
      return false  # Return false to indicate no advancement
      
    else
      # Unknown step type, just advance
      self.current_step_index += 1
    end
    
    # Mark as completed if we've reached the end
    if current_step_index >= workflow.steps.length && status != 'stopped'
      self.status = 'completed'
    end
    
    save
  end
  
  # Determine next step index based on decision logic
  def determine_next_step_index(step, results)
    # Handle multi-branch format (new)
    if step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
      # Evaluate branches in order, take first match
      step['branches'].each do |branch|
        branch_condition = branch['condition'] || branch[:condition]
        branch_path = branch['path'] || branch[:path]
        
        if branch_condition.present? && branch_path.present?
          condition_result = evaluate_condition_string(branch_condition, results)
          if condition_result
            next_step = find_step_by_title(branch_path)
            if next_step
              next_index = workflow.steps.index(next_step)
              return next_index unless next_index.nil?
            end
          end
        end
      end
      
      # No branch matched, check else_path
      if step['else_path'].present?
        next_step = find_step_by_title(step['else_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      end
      
      # Default: move to next step
      current_step_index + 1
    else
      # Legacy format (true_path/false_path)
      condition_result = evaluate_condition(step, results)
      
      if condition_result && step['true_path'].present?
        next_step = find_step_by_title(step['true_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      elsif !condition_result && step['false_path'].present?
        next_step = find_step_by_title(step['false_path'])
        if next_step
          next_index = workflow.steps.index(next_step)
          return next_index unless next_index.nil?
        end
      end
      
      # Default: move to next step
      current_step_index + 1
    end
  end

  def execute
    return false unless workflow.present? && inputs.present?

    path = []
    results = {}
    current_step_index = 0
    visited_steps = Set.new

    while current_step_index < workflow.steps.length
      step = workflow.steps[current_step_index]
      break unless step
      
      # Prevent infinite loops
      step_key = "#{current_step_index}_#{step['title']}"
      if visited_steps.include?(step_key)
        break
      end
      visited_steps.add(step_key)

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

      when 'decision'
        # Handle multi-branch format (new)
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
            next_step = find_step_by_title(branch_path)
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
            else
              current_step_index += 1
            end
          elsif step['else_path'].present?
            # No branch matched, use else_path
            next_step = find_step_by_title(step['else_path'])
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
            next_step = find_step_by_title(step['true_path'])
            if next_step
              next_index = workflow.steps.index(next_step)
              current_step_index = next_index unless next_index.nil?
            else
              current_step_index += 1
            end
          elsif !condition_result && step['false_path'].present?
            next_step = find_step_by_title(step['false_path'])
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
    # Extract condition from string (same logic as evaluate_condition)
    return false unless condition_string.present?
    
    condition = condition_string

    # Enhanced condition evaluation supporting variable names
    # Supports: variable == 'value', variable != 'value', variable > 10, etc.
    
    # String equality/inequality
    if condition.include?('==')
      parts = condition.split('==').map(&:strip)
      key = parts[0].gsub(/['"]/, '').strip
      value = parts[1].gsub(/['"]/, '').strip
      
      # Try multiple strategies to find the value:
      # 1. Direct key lookup
      result_value = results[key]
      
      # 2. If key is "answer", check all values (for legacy conditions)
      if result_value.nil? && key.downcase == 'answer'
        result_value = results.values.last
      end
      
      # 3. Case-insensitive key lookup
      if result_value.nil?
        result_value = results.find { |k, v| k.to_s.downcase == key.to_s.downcase }&.last
      end
      
      # Compare values (case-insensitive for strings)
      if result_value
        return result_value.to_s.downcase == value.to_s.downcase || result_value == value
      end
      
      return false
    elsif condition.include?('!=')
      parts = condition.split('!=').map(&:strip)
      key = parts[0].gsub(/['"]/, '').strip
      value = parts[1].gsub(/['"]/, '').strip
      
      result_value = results[key]
      
      # If key is "answer", check all values (for legacy conditions)
      if result_value.nil? && key.downcase == 'answer'
        result_value = results.values.last
      end
      
      if result_value.nil?
        result_value = results.find { |k, v| k.to_s.downcase == key.to_s.downcase }&.last
      end
      
      if result_value
        return result_value.to_s.downcase != value.to_s.downcase && result_value != value
      end
      
      return true # If variable doesn't exist, != comparison is true
    end
    
    # Numeric comparisons
    if condition.match?(/^\w+\s*>\s*\d+/)
      match = condition.match(/^(\w+)\s*>\s*(\d+)/)
      return false unless match
      key = match[1].strip
      threshold = match[2].to_i
      value = (results[key] || 0).to_i
      return value > threshold
    elsif condition.match?(/^\w+\s*>=\s*\d+/)
      match = condition.match(/^(\w+)\s*>=\s*(\d+)/)
      return false unless match
      key = match[1].strip
      threshold = match[2].to_i
      value = (results[key] || 0).to_i
      return value >= threshold
    elsif condition.match?(/^\w+\s*<\s*\d+/)
      match = condition.match(/^(\w+)\s*<\s*(\d+)/)
      return false unless match
      key = match[1].strip
      threshold = match[2].to_i
      value = (results[key] || 0).to_i
      return value < threshold
    elsif condition.match?(/^\w+\s*<=\s*\d+/)
      match = condition.match(/^(\w+)\s*<=\s*(\d+)/)
      return false unless match
      key = match[1].strip
      threshold = match[2].to_i
      value = (results[key] || 0).to_i
      return value <= threshold
    end
    
    false
  end

  def evaluate_condition(step, results)
    condition = step['condition']
    return false unless condition.present?
    
    evaluate_condition_string(condition, results)
  end

  def find_step_by_title(title)
    workflow.steps.find { |s| s['title'] == title }
  end
end

