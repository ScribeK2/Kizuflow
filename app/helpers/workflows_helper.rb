# Workflow View Helpers
# Sprint 1: Decision Step Revolution helpers for improved UX
module WorkflowsHelper
  # ============================================================================
  # Step Type Helpers
  # ============================================================================

  # Get a user-friendly label for a step type
  def step_type_label(type)
    case type
    when 'question' then 'Question'
    when 'decision' then 'Decision'
    when 'action' then 'Action'
    when 'checkpoint' then 'Checkpoint'
    else type&.titleize || 'Step'
    end
  end

  # Get an emoji icon for a step type
  def step_type_icon(type)
    case type
    when 'question' then '❓'
    when 'decision' then '🔀'
    when 'action' then '⚡'
    when 'checkpoint' then '📍'
    else '📝'
    end
  end

  # Get CSS classes for a step type badge
  def step_type_badge_classes(type)
    base = "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium"
    
    case type
    when 'question'
      "#{base} bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
    when 'decision'
      "#{base} bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-300"
    when 'action'
      "#{base} bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300"
    when 'checkpoint'
      "#{base} bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    else
      "#{base} bg-gray-100 text-gray-700 dark:bg-gray-900/30 dark:text-gray-300"
    end
  end

  # ============================================================================
  # Answer Type Helpers
  # ============================================================================

  # Get a user-friendly label for an answer type
  def answer_type_label(type)
    case type
    when 'yes_no' then 'Yes / No'
    when 'multiple_choice' then 'Multiple Choice'
    when 'text' then 'Text Input'
    when 'number' then 'Number'
    when 'dropdown' then 'Dropdown'
    else type&.titleize || 'Unknown'
    end
  end

  # Check if an answer type has predefined options
  def answer_type_has_options?(type)
    %w[multiple_choice dropdown].include?(type)
  end

  # Check if an answer type is Yes/No
  def yes_no_answer_type?(type)
    type == 'yes_no'
  end

  # ============================================================================
  # Condition Display Helpers
  # ============================================================================

  # Format a condition for human-readable display
  # Converts "variable == 'value'" to "variable is value"
  def format_condition_for_display(condition)
    return 'Not set' if condition.blank?
    
    # Parse the condition
    if match = condition.match(/^(\w+)\s*(==|!=|>|>=|<|<=)\s*['"]?([^'"]*?)['"]?$/)
      variable, operator, value = match.captures
      
      operator_text = case operator
        when '==' then 'is'
        when '!=' then 'is not'
        when '>' then 'is greater than'
        when '>=' then 'is at least'
        when '<' then 'is less than'
        when '<=' then 'is at most'
        else operator
      end
      
      "#{variable} #{operator_text} \"#{value}\""
    else
      condition
    end
  end

  # Get CSS classes for the condition display
  def condition_display_classes(condition)
    if condition.present?
      "text-sm font-mono text-gray-900 dark:text-gray-100"
    else
      "text-sm text-gray-400 dark:text-gray-500 italic"
    end
  end

  # ============================================================================
  # Step Reference Helpers
  # ============================================================================

  # Resolve a step reference (ID or title) to a display name
  def resolve_step_reference(workflow, reference)
    return nil if reference.blank? || workflow.nil?
    
    title = workflow.resolve_step_reference_to_title(reference)
    title || reference
  end

  # Get step options for a select dropdown
  # Returns an array of [display_name, value] pairs
  def step_options_for_select(workflow, exclude_step_id: nil)
    return [] unless workflow&.steps.present?
    
    workflow.steps.map.with_index do |step, index|
      next nil unless step.is_a?(Hash) && step['title'].present?
      next nil if exclude_step_id && step['id'] == exclude_step_id
      
      [
        "#{step_type_icon(step['type'])} #{index + 1}. #{step['title']}",
        step['title'] # Use title for now, can switch to ID after migration
      ]
    end.compact
  end

  # ============================================================================
  # Variable Helpers
  # ============================================================================

  # Get variable options for a select dropdown
  # Returns an array of [display_name, value] pairs
  def variable_options_for_select(workflow)
    return [] unless workflow&.respond_to?(:variables_with_metadata)
    
    workflow.variables_with_metadata.map do |var|
      [var[:display_name], var[:name]]
    end
  end

  # Get the answer type for a variable
  def variable_answer_type(workflow, variable_name)
    return nil unless workflow&.respond_to?(:variables_with_metadata)
    
    var = workflow.variables_with_metadata.find { |v| v[:name] == variable_name }
    var&.dig(:answer_type)
  end

  # ============================================================================
  # Branch Helpers
  # ============================================================================

  # Get CSS classes for a branch card
  def branch_card_classes(index)
    base = "branch-item border rounded-lg p-4 bg-white dark:bg-gray-800/50"
    
    case index % 4
    when 0 then "#{base} border-blue-200 dark:border-blue-800/50"
    when 1 then "#{base} border-green-200 dark:border-green-800/50"
    when 2 then "#{base} border-purple-200 dark:border-purple-800/50"
    else "#{base} border-amber-200 dark:border-amber-800/50"
    end
  end

  # Get CSS classes for a branch number badge
  def branch_number_badge_classes(index)
    base = "inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold"
    
    case index % 4
    when 0 then "#{base} bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400"
    when 1 then "#{base} bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400"
    when 2 then "#{base} bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400"
    else "#{base} bg-amber-100 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400"
    end
  end

  # ============================================================================
  # Yes/No Specific Helpers
  # ============================================================================

  # Check if a decision step follows a Yes/No question pattern
  def decision_follows_yes_no?(workflow, step, step_index)
    return false unless step['type'] == 'decision'
    return false unless workflow&.steps.present?
    
    # Look at preceding steps to find Yes/No questions
    preceding_steps = workflow.steps[0...step_index]
    
    preceding_steps.any? do |prev_step|
      prev_step['type'] == 'question' && 
      prev_step['answer_type'] == 'yes_no' &&
      prev_step['variable_name'].present?
    end
  end

  # Get the most recent Yes/No question before a decision step
  def most_recent_yes_no_question(workflow, step_index)
    return nil unless workflow&.steps.present?
    
    preceding_steps = workflow.steps[0...step_index].reverse
    
    preceding_steps.find do |step|
      step['type'] == 'question' && 
      step['answer_type'] == 'yes_no' &&
      step['variable_name'].present?
    end
  end

  # ============================================================================
  # Workflow Wizard Helpers
  # ============================================================================

  # Get the current wizard step number
  def wizard_step_number(action_name)
    case action_name
    when 'step1', 'update_step1' then 1
    when 'step2', 'update_step2' then 2
    when 'step3', 'create_from_draft' then 3
    else 1
    end
  end

  # Check if a wizard step is complete
  def wizard_step_complete?(workflow, step_number)
    case step_number
    when 1
      workflow.title.present?
    when 2
      workflow.steps.present? && workflow.steps.any?
    else
      false
    end
  end

  # Get the label for a wizard step
  def wizard_step_label(step_number)
    case step_number
    when 1 then 'Basic Info'
    when 2 then 'Build Steps'
    when 3 then 'Review & Launch'
    else "Step #{step_number}"
    end
  end

  # ============================================================================
  # Step Type Composition Dots
  # ============================================================================

  # Renders small colored dots representing the composition of step types in a workflow.
  # Groups steps by type and shows up to 4 dots per type. Returns nil if no steps.
  def step_type_composition_dots(workflow)
    steps = workflow.steps
    return nil if steps.blank?

    dot_colors = {
      'question'   => 'bg-blue-500',
      'decision'   => 'bg-purple-500',
      'action'     => 'bg-emerald-500',
      'checkpoint' => 'bg-amber-500',
      'message'    => 'bg-cyan-500',
      'escalate'   => 'bg-red-500',
      'resolve'    => 'bg-green-500',
      'sub_flow'   => 'bg-indigo-500'
    }

    dot_labels = {
      'question'   => 'Question',
      'decision'   => 'Decision',
      'action'     => 'Action',
      'checkpoint' => 'Checkpoint',
      'message'    => 'Message',
      'escalate'   => 'Escalate',
      'resolve'    => 'Resolve',
      'sub_flow'   => 'Sub-flow'
    }

    # Group steps by type and count them
    type_counts = steps.each_with_object(Hash.new(0)) do |step, counts|
      step_type = step['type']
      counts[step_type] += 1 if step_type.present?
    end

    return nil if type_counts.empty?

    dots = type_counts.flat_map do |type, count|
      color = dot_colors[type] || 'bg-slate-400'
      label = dot_labels[type] || type&.titleize || 'Step'
      visible_count = [count, 4].min
      visible_count.times.map do
        content_tag(:span, '', class: "inline-block w-2 h-2 rounded-full #{color}", title: "#{label} (#{count})")
      end
    end

    safe_join(dots)
  end
end

