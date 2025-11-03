# Markdown Parser for Kizuflow workflow imports
module WorkflowParsers
  class MarkdownParser < BaseParser
    def parse
      begin
        # Parse markdown content
        lines = @file_content.split("\n")
        
        # Extract title (first H1 or frontmatter)
        title = extract_title(lines)
        description = extract_description(lines)
        steps = extract_steps(lines)

        if title.blank?
          add_warning("No title found, using default")
          title = "Imported Workflow"
        end

        if steps.empty?
          add_error("No steps found in markdown file")
          return nil
        end

        parsed_data = {
          title: title,
          description: description,
          steps: steps
        }

        # Parse and normalize steps
        workflow_data = to_workflow_data(parsed_data)
        
        # Explicitly resolve step references for markdown (in case base parser doesn't catch it)
        if workflow_data[:steps].present?
          workflow_data[:steps] = resolve_step_references(workflow_data[:steps])
        end
        
        workflow_data
      rescue => e
        add_error("Error parsing Markdown: #{e.message}")
        nil
      end
    end

    private

    def extract_title(lines)
      # Check for frontmatter title
      if lines.first.strip == "---"
        lines.each_with_index do |line, index|
          next if index == 0
          break if line.strip == "---"
          if line.match(/^title:\s*(.+)$/i)
            return $1.strip.gsub(/^["']|["']$/, '')
          end
        end
      end

      # Check for H1 title
      lines.each do |line|
        if line.match(/^#\s+(.+)$/)
          return $1.strip
        end
      end

      nil
    end

    def extract_description(lines)
      description_lines = []
      in_frontmatter = false
      found_title = false
      in_description = false

      lines.each_with_index do |line, index|
        stripped = line.strip

        # Handle frontmatter
        if stripped == "---"
          in_frontmatter = !in_frontmatter
          next
        end

        if in_frontmatter
          if stripped.match(/^description:\s*(.+)$/i)
            desc = $1.strip.gsub(/^["']|["']$/, '')
            return desc unless desc.empty?
          end
          next
        end

        # Skip H1 title
        if stripped.match(/^#\s+/)
          found_title = true
          next
        end

        # Collect description after title and before first step
        if found_title && !stripped.match(/^##\s+Step|^##\s+Steps|^###\s+Step|^\d+\./)
          if stripped.match(/^##\s+(.+)$/)
            # Found a section header, stop collecting description
            break
          elsif !stripped.empty?
            description_lines << stripped
            in_description = true
          elsif in_description && stripped.empty?
            # Empty line after description, stop collecting
            break
          end
        end
      end

      description_lines.join(" ").strip
    end

    def extract_steps(lines)
      steps = []
      current_step = nil
      in_step = false
      step_index = 0

      lines.each do |line|
        stripped = line.strip

        # Skip frontmatter
        next if stripped == "---"
        next if stripped.match(/^title:|^description:/i)

        # Detect step headers (## Step X, ### Step X, or numbered list)
        if match = stripped.match(/^##\s+Step\s+(\d+)[:.]?\s*(.+)$/i)
          step_num = match[1]
          step_title_text = match[2].strip
          # Preserve "Step X: Title" format for reference resolution
          title = "Step #{step_num}: #{step_title_text}"
          
          # Save previous step if exists
          if current_step && current_step[:title].present?
            steps << normalize_step(current_step, step_index)
            step_index += 1
          end

          # Start new step
          current_step = {
            type: 'action', # Default type
            title: title,
            description: '',
            question: '',
            instructions: '',
            answer_type: 'text',
            variable_name: '',
            branches: [],
            else_path: ''
          }
          in_step = true
          next
        elsif stripped.match(/^###\s+Step\s+\d+[:.]?\s*(.+)$/i) ||
           stripped.match(/^##\s+(.+)$/) ||
           stripped.match(/^\d+\.\s+\*\*(.+?)\*\*/)

          # Save previous step if exists
          if current_step && current_step[:title].present?
            steps << normalize_step(current_step, step_index)
            step_index += 1
          end

          # Start new step (for non-Step X format)
          title = $1.strip
          current_step = {
            type: 'action', # Default type
            title: title,
            description: '',
            question: '',
            instructions: '',
            answer_type: 'text',
            variable_name: '',
            branches: [],
            else_path: ''
          }
          in_step = true
          next
        end

        # Parse step content
        if in_step && current_step
          # Extract type
          if stripped.match(/^\*\*Type\*\*:\s*(.+)$/i)
            current_step[:type] = $1.strip.downcase
          elsif stripped.match(/^Type:\s*(.+)$/i)
            current_step[:type] = $1.strip.downcase
          end

          # Extract question
          if stripped.match(/^\*\*Question\*\*:\s*(.+)$/i)
            current_step[:question] = $1.strip
          elsif stripped.match(/^Question:\s*(.+)$/i)
            current_step[:question] = $1.strip
          end

          # Extract answer type
          if stripped.match(/^\*\*Answer\s+Type\*\*:\s*(.+)$/i)
            current_step[:answer_type] = $1.strip.downcase
          elsif stripped.match(/^Answer\s+Type:\s*(.+)$/i)
            current_step[:answer_type] = $1.strip.downcase
          end

          # Extract variable name
          if stripped.match(/^\*\*Variable\*\*:\s*(.+)$/i)
            current_step[:variable_name] = $1.strip
          elsif stripped.match(/^Variable:\s*(.+)$/i)
            current_step[:variable_name] = $1.strip
          end

          # Extract instructions
          if stripped.match(/^\*\*Instructions\*\*:\s*(.+)$/i)
            current_step[:instructions] = $1.strip
          elsif stripped.match(/^Instructions:\s*(.+)$/i)
            current_step[:instructions] = $1.strip
          end

          # Extract condition
          if stripped.match(/^\*\*Condition\*\*:\s*(.+)$/i)
            current_step[:branches] = [{
              condition: $1.strip,
              path: ''
            }]
          elsif stripped.match(/^Condition:\s*(.+)$/i)
            current_step[:branches] = [{
              condition: $1.strip,
              path: ''
            }]
          end

          # Extract path/branches
          if stripped.match(/^\*\*If\s+true\*\*:\s*(.+)$/i) || stripped.match(/^If\s+true:\s*(.+)$/i)
            if current_step[:branches].empty?
              current_step[:branches] = [{ condition: '', path: $1.strip }]
            else
              current_step[:branches][0][:condition] ||= ''
              current_step[:branches][0][:path] = $1.strip
            end
          end

          if stripped.match(/^\*\*If\s+false\*\*:\s*(.+)$/i) || stripped.match(/^If\s+false:\s*(.+)$/i)
            current_step[:else_path] = $1.strip
          end

          # Extract description (everything else that's not a field)
          if !stripped.match(/^\*\*|\*\*:\s*|Type:|Question:|Answer|Variable:|Instructions:|Condition:|If\s+(true|false):/i) &&
             !stripped.match(/^##|^###|^\d+\./) &&
             !stripped.empty?
            current_step[:description] += " #{stripped}" unless current_step[:description].include?(stripped)
          end
        end
      end

      # Save last step
      if current_step && current_step[:title].present?
        steps << normalize_step(current_step, step_index)
      end

      steps
    end

    def normalize_step(step, index)
      normalized = {
        type: step[:type] || 'action',
        title: step[:title] || "Step #{index + 1}",
        description: step[:description].strip,
        question: step[:question] || '',
        answer_type: step[:answer_type] || 'text',
        variable_name: step[:variable_name] || '',
        instructions: step[:instructions] || '',
        branches: step[:branches] || [],
        else_path: step[:else_path] || ''
      }

      # Clean up description
      normalized[:description] = normalized[:description].gsub(/\s+/, ' ').strip

      normalized
    end
  end
end

