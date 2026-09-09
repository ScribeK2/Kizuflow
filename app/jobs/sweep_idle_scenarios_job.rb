# Settles runs nobody came back to, so they enter the retention pools at all.
#
# Scheduled BEFORE CleanupScenariosJob rather than alongside it: both at
# "0 3 * * *" leaves the order undefined, and a run settled after the night's
# cleanup waits a further day to be collected.
class SweepIdleScenariosJob < ApplicationJob
  queue_as :default

  def perform
    count = Scenario.sweep_idle_runs
    Rails.logger.info("[SweepIdleScenariosJob] Settled #{count} idle run(s) as abandoned")
  end
end
