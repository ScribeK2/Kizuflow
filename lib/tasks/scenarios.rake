namespace :scenarios do
  # Recommended cron: 0 3 * * * cd /path/to/app && bin/rails scenarios:cleanup
  desc "Delete stale scenarios based on tiered retention policy"
  task cleanup: :environment do
    count = Scenario.cleanup_stale
    if count.positive?
      Rails.logger.info("Cleaned up #{count} stale scenario(s)")
      puts "Cleaned up #{count} stale scenario(s)"
    else
      puts "No stale scenarios to clean up"
    end
  end
end
