# frozen_string_literal: true

# Handles step normalization, variable name generation, and format conversion
# for workflows. Ensures backward compatibility with legacy step formats.
module WorkflowNormalization
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_steps_on_save
  end

  # Ensure all steps have unique IDs
  # This assigns UUIDs to steps that don't have them yet
  def ensure_step_ids
    return unless steps.present?

    steps.each do |step|
      next unless step.is_a?(Hash)
      step['id'] ||= SecureRandom.uuid
    end
  end

  # Auto-generate variable names for question steps that don't have one
  # Uses the step title to create a snake_case variable name
  def ensure_variable_names
    return unless steps.present?

    # Collect existing variable names to avoid conflicts
    existing_names = steps
      .select { |s| s.is_a?(Hash) && s['variable_name'].present? }
      .map { |s| s['variable_name'] }

    steps.each do |step|
      next unless step.is_a?(Hash)
      next unless step['type'] == 'question'
      next if step['variable_name'].present?
      next if step['title'].blank?

      # Generate base name from title
      base_name = generate_variable_name(step['title'])
      next if base_name.blank?

      # Ensure uniqueness by appending a number if needed
      final_name = base_name
      counter = 2
      while existing_names.include?(final_name)
        final_name = "#{base_name}_#{counter}"
        counter += 1
      end

      step['variable_name'] = final_name
      existing_names << final_name
    end
  end

  # Generate a valid variable name from a title string
  # Example: "Customer Name" -> "customer_name"
  # Example: "What is your issue?" -> "what_is_your_issue"
  def generate_variable_name(title)
    return nil if title.blank?

    title
      .to_s
      .strip
      .gsub(/[?!.,;:'"(){}\[\]]/, '')  # Remove punctuation
      .parameterize(separator: '_')     # Convert to snake_case
      .gsub(/-/, '_')                   # Replace any remaining dashes
      .gsub(/_+/, '_')                  # Collapse multiple underscores
      .gsub(/^_|_$/, '')                # Remove leading/trailing underscores
      .first(30)                        # Limit length
      .gsub(/_$/, '')                   # Remove trailing underscore from truncation
  end

  # Normalize steps to convert legacy format to new format
  # This ensures backward compatibility with old workflows
  # Called before validation to convert old format to new format
  def normalize_steps_on_save
    return unless steps.present?

    # First ensure all steps have IDs
    ensure_step_ids

    # Auto-generate variable names for question steps that don't have one
    ensure_variable_names

    # Filter out completely empty steps (no type, no title, no data)
    # But preserve steps that have data even if type is missing (they're still being filled out)
    self.steps = steps.select { |step|
      step.is_a?(Hash) && (
        step['type'].present? ||
        step['title'].present? ||
        step['description'].present? ||
        step['question'].present? ||
        step['action_type'].present? ||
        step['condition'].present?
      )
    }

    return unless steps.present?

    steps.each do |step|
      next unless step.is_a?(Hash) && step['type'] == 'decision'

      # Check if this step uses legacy format (has condition + true_path/false_path but no branches)
      has_legacy_format = step['condition'].present? &&
                         (step['true_path'].present? || step['false_path'].present?) &&
                         (step['branches'].blank? || (step['branches'].is_a?(Array) && step['branches'].empty?))

      if has_legacy_format
        # Convert to new multi-branch format
        step['branches'] = []

        # Add true_path as a branch
        if step['true_path'].present?
          step['branches'] << {
            'condition' => step['condition'],
            'path' => step['true_path']
          }
        end

        # Add false_path as else_path
        if step['false_path'].present?
          step['else_path'] = step['false_path']
        end

        # Note: We keep the legacy fields (condition, true_path, false_path) for now
        # to ensure backward compatibility. They can be removed in a future migration.
      end

      # Normalize branches to ensure they have string keys (not symbols) and preserve paths
      if step['branches'].present? && step['branches'].is_a?(Array)
        step['branches'] = step['branches'].map do |branch|
          next nil unless branch.is_a?(Hash)

          # Convert symbol keys to string keys and ensure both condition and path are preserved
          normalized_branch = {
            'condition' => (branch['condition'] || branch[:condition] || '').to_s.strip,
            'path' => (branch['path'] || branch[:path] || '').to_s.strip
          }

          # Only include branch if it has at least one field set
          (normalized_branch['condition'].present? || normalized_branch['path'].present?) ? normalized_branch : nil
        end.compact
      end
    end
  end

  # Get normalized steps (for reading/display)
  # This method normalizes steps on read without modifying the database
  def normalized_steps
    return [] unless steps.present?

    steps.map do |step|
      next step unless step.is_a?(Hash) && step['type'] == 'decision'

      # Check if needs normalization
      has_legacy_format = step['condition'].present? &&
                         (step['true_path'].present? || step['false_path'].present?) &&
                         (step['branches'].blank? || (step['branches'].is_a?(Array) && step['branches'].empty?))

      if has_legacy_format
        # Create a copy to avoid modifying the original
        normalized_step = step.dup

        # Convert to new format
        normalized_step['branches'] = []

        if normalized_step['true_path'].present?
          normalized_step['branches'] << {
            'condition' => normalized_step['condition'],
            'path' => normalized_step['true_path']
          }
        end

        if normalized_step['false_path'].present?
          normalized_step['else_path'] = normalized_step['false_path']
        end

        normalized_step
      else
        step
      end
    end
  end

  # Extract all variable names from question steps
  def variables
    return [] unless steps.present?

    variable_names = []

    # Get variables from question steps
    steps.select { |step| step['type'] == 'question' && step['variable_name'].present? }
        .each { |step| variable_names << step['variable_name'] }

    # Get variables from action step output_fields
    steps.select { |step| step['type'] == 'action' && step['output_fields'].present? && step['output_fields'].is_a?(Array) }
        .each do |step|
          step['output_fields'].each do |output_field|
            variable_names << output_field['name'] if output_field.is_a?(Hash) && output_field['name'].present?
          end
        end

    variable_names.compact.uniq
  end
end
