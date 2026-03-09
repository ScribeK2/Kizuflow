module StepHelper
  # Unified field access for both AR Step objects and legacy JSONB hashes.
  # Returns the value of a field from either format.
  #
  # Examples:
  #   step_field(step, 'title')         # works for Hash or Step
  #   step_field(step, 'instructions')  # returns plain text for AR rich text fields
  #   step_field(step, 'type')          # returns "action" for both formats
  def step_field(step, field)
    if step.is_a?(Step)
      case field.to_s
      when "type"
        step.type.demodulize.underscore
      when "id"
        step.uuid
      when "target_workflow_id"
        step.respond_to?(:sub_flow_workflow_id) ? step.sub_flow_workflow_id : nil
      when "instructions", "content", "notes"
        # Rich text fields - return body as string for interpolation
        rt = step.try(field)
        rt.respond_to?(:body) ? rt.body.to_s : rt.to_s
      else
        step.try(field)
      end
    elsif step.is_a?(Hash)
      step[field.to_s] || step[field.to_sym]
    end
  end

  # Check if step is an AR Step object (vs legacy Hash)
  def ar_step?(step)
    step.is_a?(Step)
  end

  # Render rich text content for AR steps or markdown for JSONB steps.
  # Used in scenario player and workflow show views.
  def render_step_content(step, field, variables = {})
    if ar_step?(step)
      rt = step.try(field)
      if rt.present? && variables.present?
        VariableInterpolator.interpolate_rich_text(rt, variables).html_safe
      elsif rt.present?
        rt.to_s.html_safe
      else
        "".html_safe
      end
    else
      text = step[field.to_s]
      if text.present? && variables.present?
        render_step_markdown(VariableInterpolator.interpolate(text, variables))
      elsif text.present?
        render_step_markdown(text)
      else
        "".html_safe
      end
    end
  end

  # Get steps from a workflow, preferring AR steps over JSONB
  def workflow_display_steps(workflow)
    if workflow.workflow_steps.any?
      workflow.workflow_steps.includes(:transitions)
    else
      workflow.steps || []
    end
  end
end
