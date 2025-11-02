namespace :workflows do
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
end

