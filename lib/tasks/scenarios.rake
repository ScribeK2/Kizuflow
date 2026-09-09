namespace :scenarios do
  # Recommended cron: 0 3 * * * cd /path/to/app && bin/rails scenarios:cleanup
  desc "Settle runs idle past SCENARIO_IDLE_TIMEOUT_HOURS (DRY_RUN=1 reports only)"
  task sweep_idle: :environment do
    dry = ENV["DRY_RUN"].present?
    count = Scenario.sweep_idle_runs(dry_run: dry)
    verb = dry ? "Would settle" : "Settled"
    puts "#{verb} #{count} idle run(s) (threshold: #{Scenario.idle_timeout_hours}h)"
    puts "Non-terminal rows remaining: #{Scenario.outstanding_non_terminal}"
    Rails.logger.info("[scenarios:sweep_idle] #{verb} #{count} idle run(s)") unless dry
  end

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
