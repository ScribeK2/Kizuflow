# frozen_string_literal: true

# Service for merging submitted workflow steps with existing steps.
# Preserves fields that weren't in the form submission (like variable_name for question steps)
# while allowing explicit updates to take precedence.
class StepMergeService
  # @param existing_steps [Array<Hash>] The current workflow steps
  # @param submitted_steps [Array<Hash>] The steps from form submission
  def initialize(existing_steps:, submitted_steps:)
    @existing_steps = existing_steps || []
    @submitted_steps = submitted_steps || []
  end

  # Merge submitted steps with existing steps
  # @return [Array<Hash>] The merged steps array
  def call
    return @submitted_steps if @existing_steps.blank?
    return @existing_steps if @submitted_steps.blank?

    # Build lookup hash from existing steps by ID
    existing_steps_hash = build_existing_steps_hash

    # Merge each submitted step with its existing counterpart
    @submitted_steps.map do |submitted_step|
      merge_step(submitted_step, existing_steps_hash)
    end
  end

  private

  def build_existing_steps_hash
    @existing_steps.each_with_object({}) do |step, hash|
      step_id = step['id']
      hash[step_id] = step.dup if step_id.present?
    end
  end

  def merge_step(submitted_step, existing_steps_hash)
    step_hash = normalize_step(submitted_step)
    step_id = step_hash['id']

    # If no matching existing step, use submitted data as-is
    return step_hash if step_id.blank? || existing_steps_hash[step_id].blank?

    # Merge: start with existing step, overlay submitted values
    existing_step = existing_steps_hash[step_id]
    merged = existing_step.deep_dup
    submitted_keys = step_hash.keys

    # Apply all submitted values
    step_hash.each do |key, value|
      merged[key] = value
    end

    # Preserve important fields based on step type
    preserve_fields_by_type(merged, step_hash, existing_step, submitted_keys)

    merged
  end

  def normalize_step(step)
    step.is_a?(Hash) ? step.stringify_keys : step.to_h.stringify_keys
  end

  def preserve_fields_by_type(merged, submitted, existing, submitted_keys)
    case merged['type']
    when 'question'
      preserve_question_fields(merged, submitted, existing, submitted_keys)
    end
  end

  # Preserve variable_name for question steps if not intentionally changed
  def preserve_question_fields(merged, submitted, existing, submitted_keys)
    submitted_var_name = submitted['variable_name']
    existing_var_name = existing['variable_name']

    if !submitted_keys.include?('variable_name')
      # Not in submission - preserve existing
      merged['variable_name'] = existing_var_name if existing_var_name.present?
    elsif submitted_var_name.blank? && existing_var_name.present?
      # Submitted as empty but existing has value - preserve existing
      merged['variable_name'] = existing_var_name
    else
      # Submitted with a value (or both are empty) - use submitted value
      merged['variable_name'] = submitted_var_name
    end
  end
end
