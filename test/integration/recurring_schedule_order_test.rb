require "test_helper"

# The nightly jobs have an order dependency that lives in a YAML file, where
# nothing type-checks it and a tidy-up can silently undo the reasoning.
#
# The sweep is what gives an abandoned run a `completed_at`; cleanup can only
# collect runs that have one. Both at "0 3 * * *" leaves the order undefined, and
# a run settled after the night's cleanup waits a whole extra day to be removed —
# which is invisible, because the rows do eventually go.
class RecurringScheduleOrderTest < ActiveSupport::TestCase
  SCHEDULE = Rails.application.config_for(:recurring, env: "production").freeze

  # "0 2 * * *" -> 2. Only the plain daily form is used here; anything else is a
  # deliberate change and should fail loudly rather than be guessed at.
  def daily_hour(cron)
    minute, hour, rest = cron.split(" ", 3)
    assert_equal "* * *", rest, "expected a plain daily schedule, got #{cron.inspect}"
    assert_equal "0", minute, "expected the job to run on the hour, got #{cron.inspect}"
    Integer(hour)
  end

  test "both nightly scenario jobs are still scheduled" do
    assert SCHEDULE.key?(:sweep_idle_scenarios), "the sweep is what closes the retention leak"
    assert SCHEDULE.key?(:cleanup_scenarios)
    assert_equal "SweepIdleScenariosJob", SCHEDULE[:sweep_idle_scenarios][:class]
    assert_equal "CleanupScenariosJob",   SCHEDULE[:cleanup_scenarios][:class]
  end

  test "the sweep runs strictly before cleanup" do
    sweep   = daily_hour(SCHEDULE[:sweep_idle_scenarios][:schedule])
    cleanup = daily_hour(SCHEDULE[:cleanup_scenarios][:schedule])

    assert_operator sweep, :<, cleanup,
                    "cleanup can only collect runs that already have a completed_at, and the " \
                    "sweep is what stamps one — equal times leave the order undefined"
  end
end
