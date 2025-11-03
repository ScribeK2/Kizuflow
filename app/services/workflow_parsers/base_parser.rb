# Workflow Import Parser Service
# Base class for all import parsers
module WorkflowParsers
  class BaseParser
    attr_reader :file_content, :errors, :warnings

    def initialize(file_content)
      @file_content = file_content
      @errors = []
      @warnings = []
    end

    def parse
      raise NotImplementedError, "Subclasses must implement parse method"
    end

    def valid?
      @errors.empty?
    end

    protected

    def add_error(message)
      @errors << message
    end

    def add_warning(message)
      @warnings << message
    end

    # Convert parsed data to Kizuflow workflow format
    def to_workflow_data(parsed_data)
      {
        title: parsed_data[:title] || "Imported Workflow",
        description: parsed_data[:description] || "",
        steps: normalize_steps(parsed_data[:steps] || []),
        import_metadata: {
          source_format: self.class.name.demodulize.downcase.gsub('parser', ''),
          imported_at: Time.current.iso8601,
          warnings: @warnings,
          errors: @errors
        }
      }
    end

    # Normalize steps to ensure they match Kizuflow format
    def normalize_steps(steps)
      return [] unless steps.is_a?(Array)

      normalized_steps = steps.map.with_index do |step, index|
        normalized = {
          'type' => step[:type] || step['type'] || 'action',
          'title' => step[:title] || step['title'] || "Step #{index + 1}",
          'description' => step[:description] || step['description'] || ''
        }

        # Add type-specific fields
        case normalized['type']
        when 'question'
          normalized['question'] = step[:question] || step['question'] || ''
          normalized['answer_type'] = step[:answer_type] || step['answer_type'] || 'text'
          normalized['variable_name'] = step[:variable_name] || step['variable_name'] || ''
          normalized['options'] = normalize_options(step[:options] || step['options'] || [])
        when 'decision'
          normalized['branches'] = normalize_branches(step[:branches] || step['branches'] || [])
          normalized['else_path'] = step[:else_path] || step['else_path'] || ''
        when 'action'
          normalized['instructions'] = step[:instructions] || step['instructions'] || ''
          normalized['action_type'] = step[:action_type] || step['action_type'] || ''
        end

        # Mark incomplete steps
        normalized['_import_incomplete'] = is_step_incomplete?(normalized)
        normalized['_import_errors'] = step_errors(normalized) if normalized['_import_incomplete']

        normalized
      end

      # Resolve step references for markdown imports (after normalization so we have final titles)
      if self.class.name == 'WorkflowParsers::MarkdownParser' || self.class.name.include?('MarkdownParser')
        normalized_steps = resolve_step_references(normalized_steps)
      end
      
      # Mark decision steps as incomplete if they reference non-existent steps
      step_titles = normalized_steps.map { |s| s['title'] }.compact
      normalized_steps.each do |step|
        if step['type'] == 'decision' && step['branches'].present?
          step['branches'].each do |branch|
            if branch['path'].present? && !step_titles.include?(branch['path'])
              step['_import_incomplete'] = true
              step['_import_errors'] ||= []
              step['_import_errors'] << "Branch references non-existent step: #{branch['path']}"
            end
          end
          if step['else_path'].present? && !step_titles.include?(step['else_path'])
            step['_import_incomplete'] = true
            step['_import_errors'] ||= []
            step['_import_errors'] << "'Else' path references non-existent step: #{step['else_path']}"
          end
        end
      end

      normalized_steps
    end

    def normalize_options(options)
      return [] unless options.is_a?(Array)
      options.map do |opt|
        if opt.is_a?(Hash)
          {
            'label' => opt[:label] || opt['label'] || opt[:value] || opt['value'] || '',
            'value' => opt[:value] || opt['value'] || opt[:label] || opt['label'] || ''
          }
        else
          { 'label' => opt.to_s, 'value' => opt.to_s }
        end
      end
    end

    def normalize_branches(branches)
      return [] unless branches.is_a?(Array)
      branches.map do |branch|
        {
          'condition' => branch[:condition] || branch['condition'] || '',
          'path' => branch[:path] || branch['path'] || ''
        }
      end
    end

    def is_step_incomplete?(step)
      case step['type']
      when 'question'
        step['question'].blank?
      when 'decision'
        branches = step['branches'] || []
        # Check if branches are empty OR if any branch references invalid steps
        if branches.empty?
          true
        else
          # Check if all branches have both condition and path
          branches.all? { |b| b['condition'].blank? && b['path'].blank? }
        end
      when 'action'
        step['instructions'].blank?
      else
        false
      end
    end

    def step_errors(step)
      errors = []
      case step['type']
      when 'question'
        errors << "Question text is required" if step['question'].blank?
      when 'decision'
        branches = step['branches'] || []
        if branches.empty?
          errors << "At least one decision branch is required"
        else
          branches.each_with_index do |branch, idx|
            if branch['condition'].present? && branch['path'].blank?
              errors << "Branch #{idx + 1}: Path is required when condition is set"
            elsif branch['path'].present? && branch['condition'].blank?
              errors << "Branch #{idx + 1}: Condition is required when path is set"
            end
          end
        end
      when 'action'
        errors << "Instructions are required" if step['instructions'].blank?
      end
      errors
    end

    # Resolve step number references (e.g., "Step 3" -> actual step title)
    # This is called after normalization so we have the final step titles
    def resolve_step_references(normalized_steps)
      return normalized_steps unless normalized_steps.is_a?(Array) && normalized_steps.length > 0

      # Build a map of step number references to actual step titles
      step_title_map = {}
      normalized_steps.each_with_index do |step, index|
        step_num = index + 1
        step_title = step['title'] || "Step #{step_num}"
        
        # Map variations: "Step 3", "Step 3:", "3", etc. to actual title
        step_title_map["Step #{step_num}"] = step_title
        step_title_map["Step #{step_num}:"] = step_title
        step_title_map["step #{step_num}"] = step_title
        step_title_map["step #{step_num}:"] = step_title
        step_title_map[step_num.to_s] = step_title
        step_title_map["Go to Step #{step_num}"] = step_title
        step_title_map["go to step #{step_num}"] = step_title
        
        # Also check if step title starts with "Step X" and map that
        if step_title.match(/^Step\s+(\d+)/i)
          step_num_from_title = $1.to_i
          step_title_map["Step #{step_num_from_title}"] = step_title
          step_title_map["step #{step_num_from_title}"] = step_title
        end
      end

      # Resolve references in each step
      normalized_steps.map do |step|
        resolved_step = step.dup

        # Resolve branch paths
        if resolved_step['branches'].present? && resolved_step['branches'].is_a?(Array)
          resolved_step['branches'] = resolved_step['branches'].map do |branch|
            resolved_branch = branch.dup
            path = resolved_branch['path']
            
            if path.present?
              original_path = path
              # Try to resolve step number references
              resolved_path = step_title_map[path] || step_title_map[path.strip]
              
              # If not found, try to extract step number from phrases like "Go to Step 3"
              if resolved_path.nil?
                if path.match(/step\s+(\d+)/i)
                  step_num = $1.to_i
                  if step_num > 0 && step_num <= normalized_steps.length
                    resolved_path = step_title_map["Step #{step_num}"]
                  end
                end
              end
              
              # If still not resolved, try case-insensitive match
              if resolved_path.nil?
                step_title_map.each do |key, title|
                  if key.downcase == path.downcase || key.downcase.strip == path.downcase.strip
                    resolved_path = title
                    break
                  end
                end
              end
              
              # Use resolved path or keep original if couldn't resolve
              resolved_branch['path'] = resolved_path || path
            end
            
            resolved_branch
          end
        end

        # Resolve else_path
        else_path = resolved_step['else_path']
        if else_path.present?
          original_else_path = else_path
          resolved_else_path = step_title_map[else_path] || step_title_map[else_path.strip]
          
          # If not found, try to extract step number from phrases like "Go to Step 4"
          if resolved_else_path.nil?
            if else_path.match(/step\s+(\d+)/i)
              step_num = $1.to_i
              if step_num > 0 && step_num <= normalized_steps.length
                resolved_else_path = step_title_map["Step #{step_num}"]
              end
            end
          end
          
          # If still not resolved, try case-insensitive match
          if resolved_else_path.nil?
            step_title_map.each do |key, title|
              if key.downcase == else_path.downcase || key.downcase.strip == else_path.downcase.strip
                resolved_else_path = title
                break
              end
            end
          end
          
          # Use resolved path or keep original if couldn't resolve
          resolved_step['else_path'] = resolved_else_path || else_path
        end

        resolved_step
      end
    end
  end
end

