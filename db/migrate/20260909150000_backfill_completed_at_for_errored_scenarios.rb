# An errored scenario was terminal by status but never carried a completed_at:
# neither writer (Scenario#count_iteration! on MAX_ITERATIONS,
# ScenarioStepProcessor#process_subflow_step on a missing target) called
# record_completion. Both cleanup scopes filter on `completed_at < N.days.ago`,
# and `NULL < date` is never true in SQL, so every errored run was immortal —
# a leak distinct from the abandoned-run one, and invisible because the rows
# read as terminal everywhere else.
#
# Stamped from `updated_at`, the run's last real activity, not from now: `now`
# would grant ancient rows a fresh retention window and collapse every historical
# error onto one timestamp, manufacturing a spike in the time series.
#
# Consequence worth knowing before running this: rows older than the retention
# horizon become collectable immediately, so the next CleanupScenariosJob pass
# will delete them. That is the leak draining, but check the count first.
class BackfillCompletedAtForErroredScenarios < ActiveRecord::Migration[8.1]
  # Bare AR class on purpose: the real Scenario carries enums, validations and
  # callbacks that will keep changing, and a migration has to keep meaning the
  # same thing years from now. `status` here is the raw DB value.
  class Scenario < ActiveRecord::Base
  end

  def up
    scope = Scenario.where(status: "error", completed_at: nil)
    say_with_time "Backfilling completed_at for #{scope.count} errored scenario(s)" do
      scope.find_each do |s|
        Scenario.where(id: s.id).update_all(
          completed_at: s.updated_at,
          outcome: s.outcome.presence || "error",
          duration_seconds: s.duration_seconds || (s.started_at && (s.updated_at - s.started_at).to_i)
        )
      end
    end
  end

  def down
    # The original NULL carried no information, and nulling these again would
    # restore the leak. Nothing to reverse to.
    raise ActiveRecord::IrreversibleMigration
  end
end
