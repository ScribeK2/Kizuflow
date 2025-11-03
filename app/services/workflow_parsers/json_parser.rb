# JSON Parser for Kizuflow workflow imports
require 'json'

module WorkflowParsers
  class JsonParser < BaseParser
    def parse
      begin
        data = JSON.parse(@file_content)
        
        # Handle both direct workflow objects and wrapped formats
        workflow_data = if data['workflow']
          data['workflow']
        elsif data['title'] || data['steps']
          data
        else
          add_error("Invalid JSON structure: expected workflow object with 'title' and 'steps'")
          return nil
        end

        # Extract title and description
        title = workflow_data['title'] || workflow_data[:title]
        description = workflow_data['description'] || workflow_data[:description] || ''
        steps = workflow_data['steps'] || workflow_data[:steps] || []

        if title.blank?
          add_error("Workflow title is required")
        end

        if !steps.is_a?(Array)
          add_error("Steps must be an array")
        end

        # Convert string keys to symbols for consistency
        parsed_data = {
          title: title,
          description: description,
          steps: normalize_step_keys(steps)
        }

        to_workflow_data(parsed_data)
      rescue JSON::ParserError => e
        add_error("Invalid JSON format: #{e.message}")
        nil
      rescue => e
        add_error("Error parsing JSON: #{e.message}")
        nil
      end
    end

    private

    def normalize_step_keys(steps)
      steps.map do |step|
        if step.is_a?(Hash)
          # Convert symbol keys to string keys
          step.stringify_keys
        else
          step
        end
      end
    end
  end
end

