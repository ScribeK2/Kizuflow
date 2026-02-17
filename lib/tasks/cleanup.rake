namespace :workflows do
  desc "Delete orphaned draft workflows (untitled, no steps, older than 24 hours)"
  task cleanup_orphaned_drafts: :environment do
    orphans = Workflow.where(status: 'draft', title: 'Untitled Workflow')
                      .where("created_at < ?", 24.hours.ago)
                      .select { |w| w.steps.blank? || w.steps.empty? }

    count = orphans.size
    orphans.each(&:destroy)
    puts "Cleaned up #{count} orphaned draft workflow(s)."
  end
end
