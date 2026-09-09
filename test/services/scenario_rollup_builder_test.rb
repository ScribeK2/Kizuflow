require "test_helper"

# Rollups exist so trend history outlives the runs behind it. The test that
# matters most is `a closed day is not recomputed as its runs are deleted`:
# cleanup keys on `completed_at` while a rollup keys on `started_at`, so a day's
# runs are deleted across several nights. Any rule that re-rolls a day merely
# because it still has raw rows will recompute it from the survivors, undercount,
# and freeze at the wrong number — failing exactly at the horizon this table
# exists to protect.
class ScenarioRollupBuilderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "rollup-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    @workflow = Workflow.create!(title: "Rollup WF #{SecureRandom.hex(3)}", user: @user)
    Steps::Resolve.create!(workflow: @workflow, position: 0, title: "Done", resolution_type: "success")
  end

  def run_on(day, outcome: "completed", purpose: "live", duration: 60, path: nil, status: "completed")
    Scenario.create!(
      workflow: @workflow, user: @user, purpose: purpose, status: status,
      outcome: outcome, started_at: day.to_time(:utc) + 9.hours,
      completed_at: duration && (day.to_time(:utc) + 9.hours + duration.seconds),
      duration_seconds: duration, execution_path: path || [], results: {}, inputs: {}
    )
  end

  def rollups_for(day)
    ScenarioRollup.where(workflow: @workflow, day: day)
  end

  # --- the property the design turns on --------------------------------------

  test "a closed day is not recomputed as its runs are deleted" do
    day = 40.days.ago.to_date
    runs = Array.new(4) { run_on(day) }
    ScenarioRollupBuilder.rebuild!

    assert_equal 4, rollups_for(day).sum(:runs_count)

    # Cleanup takes the first tranche. The day still has raw rows, which is
    # exactly the trap: recomputing now would write 2.
    Scenario.where(id: runs.first(2).map(&:id)).delete_all
    ScenarioRollupBuilder.rebuild!

    assert_equal 4, rollups_for(day).sum(:runs_count),
                 "a closed day must keep the number it was rolled with"

    # And when the rest go, the history is still there.
    Scenario.where(id: runs.map(&:id)).delete_all
    ScenarioRollupBuilder.rebuild!

    assert_equal 4, rollups_for(day).sum(:runs_count),
                 "this is the whole point: the trend outlives the transcripts"
  end

  test "a day inside the refresh window is still recomputed" do
    day = Date.current - 1
    run_on(day)
    ScenarioRollupBuilder.rebuild!

    assert_equal 1, rollups_for(day).sum(:runs_count)

    run_on(day)
    ScenarioRollupBuilder.rebuild!

    assert_equal 2, rollups_for(day).sum(:runs_count),
                 "recent days are still moving — runs settle a day or two after they start"
  end

  test "a run that settles inside the window replaces its pending row" do
    day = Date.current - 1
    pending = run_on(day, outcome: nil, status: "active", duration: nil)
    ScenarioRollupBuilder.rebuild!

    assert_equal 1, rollups_for(day).where(outcome: ScenarioRollup::PENDING).sum(:runs_count)

    pending.update!(status: "completed", outcome: "completed", duration_seconds: 30,
                    completed_at: Time.current)
    ScenarioRollupBuilder.rebuild!

    assert_equal 0, rollups_for(day).where(outcome: ScenarioRollup::PENDING).sum(:runs_count),
                 "delete-then-insert, not upsert — an upsert leaves the stale pending row"
    assert_equal 1, rollups_for(day).sum(:runs_count), "and the run is counted once, not twice"
  end

  # --- grain ------------------------------------------------------------------

  test "the grain separates purpose and outcome" do
    day = 40.days.ago.to_date
    run_on(day, purpose: "live", outcome: "completed")
    run_on(day, purpose: "live", outcome: "abandoned")
    run_on(day, purpose: "simulation", outcome: "completed")
    ScenarioRollupBuilder.rebuild!

    assert_equal 3, rollups_for(day).count, "three distinct grain rows"
    assert_equal 1, rollups_for(day).find_by(purpose: "live", outcome: "abandoned").runs_count
    assert_equal 1, rollups_for(day).find_by(purpose: "simulation", outcome: "completed").runs_count
  end

  test "durations are stored so averages compose across days" do
    busy = 40.days.ago.to_date
    quiet = 41.days.ago.to_date
    3.times { run_on(busy, duration: 10) }
    run_on(quiet, duration: 100)
    ScenarioRollupBuilder.rebuild!

    scope = ScenarioRollup.where(workflow: @workflow, day: [busy, quiet])
    # (10+10+10+100) / 4 = 32.5 -> 33. Averaging the daily means would give
    # (10 + 100) / 2 = 55, weighting one quiet day like three busy ones.
    assert_equal 33, scope.average_duration_seconds
  end

  test "runs with no duration do not drag the average down" do
    day = 40.days.ago.to_date
    run_on(day, duration: 60)
    run_on(day, duration: nil)
    ScenarioRollupBuilder.rebuild!

    scope = ScenarioRollup.where(workflow: @workflow, day: day)
    assert_equal 2, scope.sum(:runs_count)
    assert_equal 1, scope.sum(:duration_count), "only one run had a duration"
    assert_equal 60, scope.average_duration_seconds
  end

  # --- drop-off ---------------------------------------------------------------

  test "drop-off is rolled up by the step the run stopped on" do
    day = 40.days.ago.to_date
    2.times { run_on(day, outcome: "abandoned", path: [{ "step_title" => "Verify Account" }]) }
    run_on(day, outcome: "abandoned", path: [{ "step_title" => "Check Balance" }])
    run_on(day, outcome: "completed", path: [{ "step_title" => "Verify Account" }])
    ScenarioRollupBuilder.rebuild!

    rows = ScenarioDropoffRollup.where(workflow: @workflow, day: day)
    assert_equal 2, rows.count
    assert_equal 2, rows.find_by(step_title: "Verify Account").runs_count,
                 "a completed run on the same step is not a drop-off"
    assert_equal 1, rows.find_by(step_title: "Check Balance").runs_count
  end

  test "drop-off history also survives its runs" do
    day = 40.days.ago.to_date
    run = run_on(day, outcome: "abandoned", path: [{ "step_title" => "Verify Account" }])
    ScenarioRollupBuilder.rebuild!
    Scenario.where(id: run.id).delete_all
    ScenarioRollupBuilder.rebuild!

    assert_equal 1, ScenarioDropoffRollup.where(workflow: @workflow, day: day).sum(:runs_count),
                 "the report that would otherwise die at the horizon"
  end

  # --- safety -----------------------------------------------------------------

  test "rebuilding twice changes nothing" do
    day = 40.days.ago.to_date
    2.times { run_on(day) }
    ScenarioRollupBuilder.rebuild!
    before = rollups_for(day).order(:outcome).pluck(:outcome, :runs_count)

    ScenarioRollupBuilder.rebuild!

    assert_equal before, rollups_for(day).order(:outcome).pluck(:outcome, :runs_count)
  end

  test "a missed night is caught up rather than lost" do
    old = 40.days.ago.to_date
    older = 45.days.ago.to_date
    run_on(old)
    run_on(older)

    # Both are outside the refresh window and neither has been rolled: the job
    # has to pick them up anyway, or a night's outage loses that day forever.
    ScenarioRollupBuilder.rebuild!

    assert_equal 1, rollups_for(old).sum(:runs_count)
    assert_equal 1, rollups_for(older).sum(:runs_count)
  end

  test "no runs is not an error" do
    assert_equal({ days: 0, rollups: 0, dropoffs: 0 }, ScenarioRollupBuilder.rebuild!)
  end

  test "the job rolls up" do
    day = 40.days.ago.to_date
    run_on(day)

    RollUpScenariosJob.perform_now

    assert_equal 1, rollups_for(day).sum(:runs_count)
  end
end
