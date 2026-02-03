namespace :workflows do
  desc "Generate UUIDs for existing workflow steps that don't have IDs"
  task generate_step_ids: :environment do
    puts "Generating step IDs for existing workflows..."

    migrated_count = 0
    error_count = 0

    Workflow.find_each do |workflow|
      begin
        # Check if workflow needs step IDs
        needs_ids = false

        if workflow.steps.present?
          workflow.steps.each do |step|
            if step.is_a?(Hash) && step['id'].blank?
              needs_ids = true
              break
            end
          end
        end

        if needs_ids
          puts "Adding step IDs to workflow #{workflow.id}: #{workflow.title}"

          # Generate IDs for steps that don't have them
          workflow.ensure_step_ids

          # Save the workflow
          workflow.save(validate: false)

          migrated_count += 1
        end
      rescue => e
        puts "Error generating step IDs for workflow #{workflow.id}: #{e.message}"
        error_count += 1
      end
    end

    puts "\nStep ID generation complete!"
    puts "Updated: #{migrated_count} workflows"
    puts "Errors: #{error_count} workflows"
  end

  desc "Migrate existing workflows from legacy format to new multi-branch format"
  task migrate_legacy_format: :environment do
    puts "Starting migration of legacy workflows..."
    
    migrated_count = 0
    error_count = 0
    
    Workflow.find_each do |workflow|
      begin
        # Check if workflow needs migration
        needs_migration = false
        
        if workflow.steps.present?
          workflow.steps.each do |step|
            if step.is_a?(Hash) && step['type'] == 'decision'
              has_legacy_format = step['condition'].present? && 
                                 (step['true_path'].present? || step['false_path'].present?) &&
                                 (step['branches'].blank? || (step['branches'].is_a?(Array) && step['branches'].empty?))
              
              if has_legacy_format
                needs_migration = true
                break
              end
            end
          end
        end
        
        if needs_migration
          puts "Migrating workflow #{workflow.id}: #{workflow.title}"
          
          # Use normalize_steps_on_save to convert format
          workflow.normalize_steps_on_save
          
          # Save without validation (since normalization might create temporary invalid state)
          workflow.save(validate: false)
          
          migrated_count += 1
        end
      rescue => e
        puts "Error migrating workflow #{workflow.id}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\nMigration complete!"
    puts "Migrated: #{migrated_count} workflows"
    puts "Errors: #{error_count} workflows"
  end

  desc "Convert linear workflows to graph mode (DAG-based)"
  task migrate_to_graph: :environment do
    puts "Converting linear workflows to graph mode..."
    puts "=" * 60

    converted_count = 0
    skipped_count = 0
    error_count = 0
    error_details = []

    Workflow.find_each do |workflow|
      begin
        # Skip if already in graph mode
        if workflow.graph_mode?
          puts "  [SKIP] Workflow #{workflow.id}: Already in graph mode"
          skipped_count += 1
          next
        end

        # Skip if no steps
        unless workflow.steps.present?
          puts "  [SKIP] Workflow #{workflow.id}: No steps"
          skipped_count += 1
          next
        end

        puts "  [CONVERTING] Workflow #{workflow.id}: #{workflow.title}"

        converter = WorkflowGraphConverter.new(workflow)
        converted_steps = converter.convert

        if converted_steps
          workflow.steps = converted_steps
          workflow.graph_mode = true
          workflow.start_node_uuid = converted_steps.first&.dig('id')

          if workflow.save
            puts "    ✓ Converted successfully"
            converted_count += 1
          else
            error_msg = "Validation failed: #{workflow.errors.full_messages.join(', ')}"
            puts "    ✗ #{error_msg}"
            error_details << { id: workflow.id, title: workflow.title, error: error_msg }
            error_count += 1
          end
        else
          error_msg = "Conversion failed: #{converter.errors.join(', ')}"
          puts "    ✗ #{error_msg}"
          error_details << { id: workflow.id, title: workflow.title, error: error_msg }
          error_count += 1
        end
      rescue => e
        error_msg = "Exception: #{e.message}"
        puts "    ✗ #{error_msg}"
        error_details << { id: workflow.id, title: workflow.title, error: error_msg }
        error_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Graph conversion complete!"
    puts "  Converted: #{converted_count} workflows"
    puts "  Skipped:   #{skipped_count} workflows"
    puts "  Errors:    #{error_count} workflows"

    if error_details.any?
      puts "\nError details:"
      error_details.each do |detail|
        puts "  - Workflow #{detail[:id]} (#{detail[:title]}): #{detail[:error]}"
      end
    end
  end

  desc "Preview graph conversion for a single workflow (dry run)"
  task :preview_graph_conversion, [:workflow_id] => :environment do |_t, args|
    workflow_id = args[:workflow_id]

    unless workflow_id
      puts "Usage: rake workflows:preview_graph_conversion[WORKFLOW_ID]"
      exit 1
    end

    workflow = Workflow.find_by(id: workflow_id)

    unless workflow
      puts "Workflow #{workflow_id} not found"
      exit 1
    end

    puts "Preview graph conversion for: #{workflow.title}"
    puts "=" * 60

    if workflow.graph_mode?
      puts "Workflow is already in graph mode"
      exit 0
    end

    converter = WorkflowGraphConverter.new(workflow)
    converted_steps = converter.convert

    if converted_steps
      puts "Conversion would succeed!"
      puts "\nConverted steps:"

      converted_steps.each_with_index do |step, index|
        puts "\n#{index + 1}. #{step['title']} (#{step['type']})"
        puts "   ID: #{step['id']}"

        transitions = step['transitions'] || []
        if transitions.any?
          puts "   Transitions:"
          transitions.each do |t|
            condition = t['condition'] ? " when: #{t['condition']}" : " (default)"
            label = t['label'] ? " [#{t['label']}]" : ""
            puts "     → #{t['target_uuid']}#{condition}#{label}"
          end
        else
          puts "   Transitions: (terminal node)"
        end
      end
    else
      puts "Conversion would fail:"
      converter.errors.each do |error|
        puts "  - #{error}"
      end
    end
  end

  desc "Revert a workflow from graph mode to linear mode"
  task :revert_from_graph, [:workflow_id] => :environment do |_t, args|
    workflow_id = args[:workflow_id]

    unless workflow_id
      puts "Usage: rake workflows:revert_from_graph[WORKFLOW_ID]"
      exit 1
    end

    workflow = Workflow.find_by(id: workflow_id)

    unless workflow
      puts "Workflow #{workflow_id} not found"
      exit 1
    end

    unless workflow.graph_mode?
      puts "Workflow is not in graph mode"
      exit 0
    end

    puts "Reverting workflow from graph mode: #{workflow.title}"

    # Remove transitions from all steps
    workflow.steps.each do |step|
      step.delete('transitions') if step.is_a?(Hash)
    end

    workflow.graph_mode = false
    workflow.start_node_uuid = nil

    if workflow.save
      puts "Successfully reverted to linear mode"
    else
      puts "Failed to revert: #{workflow.errors.full_messages.join(', ')}"
    end
  end
end

