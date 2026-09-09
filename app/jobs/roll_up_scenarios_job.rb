# Writes daily aggregates before retention deletes the runs behind them.
#
# Scheduled BETWEEN the sweep (02:00) and cleanup (03:00), and the three-way
# order is load-bearing on the very first night: the sweep settles a backlog of
# abandoned runs stamped with their real last-activity times, this captures that
# abandonment history, and cleanup then deletes the ones already past the
# horizon. Run cleanup before this and that history is gone, unrecoverably.
class RollUpScenariosJob < ApplicationJob
  queue_as :default

  def perform
    result = ScenarioRollupBuilder.rebuild!
    Rails.logger.info(
      "[RollUpScenariosJob] Rolled up #{result[:days]} day(s): " \
      "#{result[:rollups]} rollup row(s), #{result[:dropoffs]} drop-off row(s)"
    )
  end
end
