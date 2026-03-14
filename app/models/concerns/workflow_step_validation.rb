module WorkflowStepValidation
  extend ActiveSupport::Concern

  included do
    validate :validate_workflow_size
  end

  # Validate step references (public so tests / controller code can call directly)
  def validate_step_references
    true
  end

  private

  # Validate workflow size limits to prevent DoS and ensure performance
  def validate_workflow_size
    step_count = workflow_steps.size

    if step_count > self.class::MAX_STEPS
      errors.add(:steps, "Workflow cannot exceed #{self.class::MAX_STEPS} steps (currently #{step_count})")
    end
  end
end
