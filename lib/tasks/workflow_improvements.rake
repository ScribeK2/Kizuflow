namespace :workflows do
  namespace :sprint1 do
    desc "Sprint 1: Decision Step Revolution - Migrate step references from title-based to ID-based"
    task migrate_references_to_ids: :environment do
      puts "=" * 60
      puts "Sprint 1: Migrating Step References to ID-Based System"
      puts "=" * 60
      puts ""
      
      workflows = Workflow.all
      total = workflows.count
      migrated = 0
      skipped = 0
      errors = 0
      
      puts "Found #{total} workflows to process..."
      puts ""
      
      workflows.find_each.with_index do |workflow, index|
        print "\rProcessing workflow #{index + 1}/#{total}: #{workflow.title.truncate(40)}..."
        
        begin
          # First ensure all steps have IDs
          workflow.ensure_step_ids
          
          # Then migrate references
          if workflow.migrate_step_references_to_ids!
            migrated += 1
            puts " ✓ Migrated"
          else
            skipped += 1
          end
        rescue => e
          errors += 1
          puts " ✗ Error: #{e.message}"
        end
      end
      
      puts ""
      puts "=" * 60
      puts "Migration Complete!"
      puts "-" * 60
      puts "  Total workflows: #{total}"
      puts "  Migrated:        #{migrated}"
      puts "  Skipped:         #{skipped} (already using IDs or no references)"
      puts "  Errors:          #{errors}"
      puts "=" * 60
    end

    desc "Sprint 1: Verify all steps have UUIDs"
    task verify_step_ids: :environment do
      puts "=" * 60
      puts "Sprint 1: Verifying All Steps Have UUIDs"
      puts "=" * 60
      puts ""
      
      workflows = Workflow.all
      total = workflows.count
      fixed = 0
      issues = []
      
      workflows.find_each do |workflow|
        next unless workflow.steps.present?
        
        missing_ids = workflow.steps.count { |step| step['id'].blank? }
        
        if missing_ids > 0
          workflow.ensure_step_ids
          if workflow.save
            fixed += 1
            puts "✓ Fixed #{missing_ids} steps in: #{workflow.title}"
          else
            issues << "#{workflow.title}: #{workflow.errors.full_messages.join(', ')}"
          end
        end
      end
      
      puts ""
      puts "=" * 60
      puts "Verification Complete!"
      puts "-" * 60
      puts "  Workflows fixed: #{fixed}"
      
      if issues.any?
        puts "  Issues found:"
        issues.each { |issue| puts "    - #{issue}" }
      else
        puts "  All workflows have valid step IDs!"
      end
      puts "=" * 60
    end

    desc "Sprint 1: Audit decision steps for Yes/No question patterns"
    task audit_yes_no_patterns: :environment do
      puts "=" * 60
      puts "Sprint 1: Auditing Yes/No Question Patterns"
      puts "=" * 60
      puts ""
      puts "This audit identifies workflows that could benefit from the"
      puts "new Yes/No Branch Quick Setup feature."
      puts ""
      
      workflows_with_yes_no = []
      
      Workflow.find_each do |workflow|
        next unless workflow.steps.present?
        
        yes_no_questions = workflow.steps.select { |s| 
          s['type'] == 'question' && s['answer_type'] == 'yes_no' 
        }
        
        decision_steps = workflow.steps.select { |s| s['type'] == 'decision' }
        
        if yes_no_questions.any? && decision_steps.any?
          # Check if any decision steps branch on yes/no variables
          yes_no_vars = yes_no_questions.map { |q| q['variable_name'] }.compact
          
          matching_decisions = decision_steps.select do |d|
            next false unless d['branches'].present?
            
            d['branches'].any? do |branch|
              condition = branch['condition'] || ''
              yes_no_vars.any? { |var| condition.include?(var) }
            end
          end
          
          if matching_decisions.any?
            workflows_with_yes_no << {
              workflow: workflow,
              yes_no_questions: yes_no_questions.length,
              decision_steps: decision_steps.length,
              matching_decisions: matching_decisions.length
            }
          end
        end
      end
      
      if workflows_with_yes_no.any?
        puts "Found #{workflows_with_yes_no.length} workflows using Yes/No branching:"
        puts ""
        
        workflows_with_yes_no.each do |info|
          w = info[:workflow]
          puts "  #{w.title}"
          puts "    - #{info[:yes_no_questions]} Yes/No questions"
          puts "    - #{info[:decision_steps]} decision steps"
          puts "    - #{info[:matching_decisions]} using Yes/No variables"
          puts ""
        end
      else
        puts "No workflows currently use Yes/No branching patterns."
      end
      
      puts "=" * 60
    end

    desc "Sprint 1: Generate report of decision step complexity"
    task decision_complexity_report: :environment do
      puts "=" * 60
      puts "Sprint 1: Decision Step Complexity Report"
      puts "=" * 60
      puts ""
      
      stats = {
        total_workflows: 0,
        total_decision_steps: 0,
        single_branch: 0,
        two_branches: 0,
        multi_branch: 0,
        no_branches: 0,
        using_legacy_format: 0
      }
      
      Workflow.find_each do |workflow|
        next unless workflow.steps.present?
        
        stats[:total_workflows] += 1
        
        workflow.steps.each do |step|
          next unless step['type'] == 'decision'
          
          stats[:total_decision_steps] += 1
          
          branches = step['branches']
          
          if branches.blank? || !branches.is_a?(Array)
            if step['condition'].present?
              stats[:using_legacy_format] += 1
            else
              stats[:no_branches] += 1
            end
          else
            case branches.length
            when 0
              stats[:no_branches] += 1
            when 1
              stats[:single_branch] += 1
            when 2
              stats[:two_branches] += 1
            else
              stats[:multi_branch] += 1
            end
          end
        end
      end
      
      puts "Summary:"
      puts "-" * 40
      puts "  Total workflows analyzed: #{stats[:total_workflows]}"
      puts "  Total decision steps:     #{stats[:total_decision_steps]}"
      puts ""
      puts "Branch Distribution:"
      puts "-" * 40
      puts "  No branches:      #{stats[:no_branches]}"
      puts "  Single branch:    #{stats[:single_branch]}"
      puts "  Two branches:     #{stats[:two_branches]} (typical Yes/No)"
      puts "  Multi-branch:     #{stats[:multi_branch]} (3+ branches)"
      puts "  Legacy format:    #{stats[:using_legacy_format]}"
      puts ""
      
      if stats[:two_branches] > 0
        pct = (stats[:two_branches].to_f / stats[:total_decision_steps] * 100).round(1)
        puts "📊 #{pct}% of decision steps have 2 branches (Yes/No pattern)"
        puts "   The Yes/No Branch Quick Setup will help with these!"
      end
      
      puts "=" * 60
    end
  end
end

