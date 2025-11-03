# CSV Parser for Kizuflow workflow imports
require 'csv'

module WorkflowParsers
  class CsvParser < BaseParser
    def parse
      begin
        csv = CSV.parse(@file_content, headers: true, header_converters: :symbol)
        
        if csv.headers.nil? || csv.headers.empty?
          add_error("CSV file must have a header row")
          return nil
        end

        # Required columns
        required_columns = [:type, :title]
        missing_columns = required_columns - csv.headers
        if missing_columns.any?
          add_error("Missing required columns: #{missing_columns.join(', ')}")
          return nil
        end

        # Extract workflow title from first row or use default
        title = csv.headers.include?(:workflow_title) ? csv.first[:workflow_title] : nil
        title ||= csv.headers.include?(:title) ? csv.first[:title] : nil
        title ||= "Imported Workflow"

        description = csv.headers.include?(:workflow_description) ? csv.first[:workflow_description] : nil
        description ||= csv.headers.include?(:description) ? csv.first[:description] : nil
        description ||= ""

        # Parse steps from rows
        steps = []
        csv.each_with_index do |row, index|
          # Skip empty rows
          next if row[:type].blank? && row[:title].blank?

          step = parse_csv_row(row, index + 1)
          steps << step if step
        end

        if steps.empty?
          add_error("No valid steps found in CSV file")
          return nil
        end

        parsed_data = {
          title: title,
          description: description,
          steps: steps
        }

        to_workflow_data(parsed_data)
      rescue CSV::MalformedCSVError => e
        add_error("Invalid CSV format: #{e.message}")
        nil
      rescue => e
        add_error("Error parsing CSV: #{e.message}")
        nil
      end
    end

    private

    def parse_csv_row(row, row_number)
      step_type = (row[:type] || row[:step_type] || 'action').to_s.downcase.strip
      
      unless ['question', 'decision', 'action'].include?(step_type)
        add_warning("Row #{row_number}: Invalid step type '#{step_type}', defaulting to 'action'")
        step_type = 'action'
      end

      step = {
        type: step_type,
        title: row[:title] || row[:step_title] || "Step #{row_number}",
        description: row[:description] || row[:step_description] || ''
      }

      case step_type
      when 'question'
        step[:question] = row[:question] || row[:question_text] || ''
        step[:answer_type] = (row[:answer_type] || row[:answer] || 'text').to_s.downcase
        step[:variable_name] = row[:variable_name] || row[:variable] || ''
        
        # Parse options
        if row[:options]
          step[:options] = parse_options(row[:options])
        end
      when 'decision'
        # Parse branches
        if row[:condition] && row[:path]
          step[:branches] = [{
            condition: row[:condition],
            path: row[:path]
          }]
        elsif row[:branches]
          step[:branches] = parse_branches(row[:branches])
        end
        
        step[:else_path] = row[:else_path] || row[:else] || ''
      when 'action'
        step[:instructions] = row[:instructions] || row[:action] || ''
        step[:action_type] = row[:action_type] || ''
      end

      step
    end

    def parse_options(options_string)
      return [] if options_string.blank?

      # Try to parse as JSON first
      begin
        parsed = JSON.parse(options_string)
        return parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        # Fall through to comma-separated parsing
      end

      # Parse as comma-separated values
      options_string.split(',').map do |opt|
        opt = opt.strip
        # Try to parse as "label:value" format
        if opt.include?(':')
          parts = opt.split(':', 2)
          { label: parts[0].strip, value: parts[1].strip }
        else
          { label: opt, value: opt }
        end
      end
    end

    def parse_branches(branches_string)
      return [] if branches_string.blank?

      # Try to parse as JSON first
      begin
        parsed = JSON.parse(branches_string)
        return parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        # Fall through to comma-separated parsing
      end

      # Parse as comma-separated "condition:path" format
      branches_string.split(',').map do |branch|
        branch = branch.strip
        if branch.include?(':')
          parts = branch.split(':', 2)
          { condition: parts[0].strip, path: parts[1].strip }
        else
          { condition: branch, path: '' }
        end
      end
    end
  end
end

