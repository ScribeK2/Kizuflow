require "test_helper"

module Admin
  class AnalyticsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin = User.create!(
        email: "admin-analytics-#{SecureRandom.hex(4)}@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        role: "admin"
      )
      @editor = User.create!(
        email: "editor-analytics-#{SecureRandom.hex(4)}@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        role: "editor"
      )
      @regular_user = User.create!(
        email: "user-analytics-#{SecureRandom.hex(4)}@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        role: "user"
      )
      @workflow = Workflow.create!(title: "Analytics Test Workflow", user: @admin)
      Steps::Question.create!(workflow: @workflow, position: 0, uuid: "s1", title: "Q1", question: "Test?")
    end

    # Drop-off is about live agent behaviour. Until the idle sweep existed almost
    # nothing carried outcome "abandoned", so mixing purposes cost nothing; now
    # that abandoned runs are produced at volume, builder test-runs would swamp
    # the signal. See docs/designs/idle-sweep-spike-findings.md.
    def abandoned_run(purpose:, step_title:)
      Scenario.create!(
        workflow: @workflow, user: @admin, purpose: purpose,
        status: "timeout", outcome: "abandoned",
        started_at: 2.days.ago, completed_at: 1.day.ago,
        execution_path: [{ "step_title" => step_title }], results: {}, inputs: {}
      )
    end

    test "drop-off points exclude simulation runs by default" do
      abandoned_run(purpose: "live", step_title: "Real Agent Step")
      abandoned_run(purpose: "simulation", step_title: "Builder Test Step")
      sign_in @admin

      get admin_analytics_path

      assert_response :success
      assert_match "Real Agent Step", response.body
      assert_no_match(/Builder Test Step/, response.body,
                      "an editor abandoning a test run is not agent drop-off")
    end

    test "drop-off points honour an explicit purpose filter" do
      abandoned_run(purpose: "simulation", step_title: "Builder Test Step")
      sign_in @admin

      get admin_analytics_path(purpose: "simulation")

      assert_response :success
      assert_match "Builder Test Step", response.body,
                   "the default must not become a lock — asking for simulations shows them"
    end

    def rolled_up_day(day, outcome:, count:, purpose: "live", duration_sum: 0, duration_count: 0)
      ScenarioRollup.create!(
        workflow: @workflow, day: day, purpose: purpose, outcome: outcome,
        runs_count: count, duration_sum_seconds: duration_sum, duration_count: duration_count
      )
    end

    # "All" claimed all time and could not deliver it: runs are deleted at the
    # retention horizon, so the widest raw range was 90 days wearing a wider
    # label. It now reads a different SOURCE — the daily rollups — rather than a
    # wider window on the same one.
    test "the all-time range reads rollups and reaches past the retention horizon" do
      rolled_up_day(400.days.ago.to_date, outcome: "completed", count: 7,
                                          duration_sum: 700, duration_count: 7)
      rolled_up_day(400.days.ago.to_date, outcome: "escalated", count: 3)
      sign_in @admin

      get admin_analytics_path(range: "all")

      assert_response :success
      assert_match(/All time/, response.body)
      assert_match(/10/, response.body, "totals come from rollups, not from surviving runs")
      assert_match(/Daily totals/, response.body,
                   "the page has to say which source it is reading")
    end

    test "the all-time view does not offer filters it cannot honour" do
      rolled_up_day(400.days.ago.to_date, outcome: "completed", count: 1)
      sign_in @admin

      get admin_analytics_path(range: "all")

      assert_response :success
      assert_no_match(/All Agents/, response.body,
                      "a rollup has no per-agent grain, so the control must not be offered")
      assert_no_match(/All Groups/, response.body)
    end

    test "panels with no rollup behind them say so rather than looking empty" do
      rolled_up_day(400.days.ago.to_date, outcome: "completed", count: 1)
      sign_in @admin

      get admin_analytics_path(range: "all")

      assert_response :success
      assert_match(/Not available for all time/, response.body,
                   "an empty table reads as 'nobody did anything', which is a different claim")
    end

    test "a range within retention still reads runs and keeps every filter" do
      sign_in @admin

      get admin_analytics_path(range: "90d")

      assert_response :success
      assert_match(/All Agents/, response.body, "raw mode keeps the run-level filters")
      assert_match(/Individual runs, with every filter/, response.body)
    end

    # The seam is explicit precisely so a CSV of the last 90 days can never be
    # handed over labelled "all time" — that is the lie being removed.
    test "CSV export from the all-time view redirects rather than mislabelling itself" do
      sign_in @admin

      get admin_analytics_path(range: "all", format: :csv)

      assert_redirected_to admin_analytics_path(range: "90d")
      assert_match(/individual runs/i, flash[:alert])
    end

    test "admin can access analytics page" do
      sign_in @admin
      get admin_analytics_path

      assert_response :success
      assert_select "h1", text: /Analytics/
    end

    test "editor cannot access analytics page" do
      sign_in @editor
      get admin_analytics_path

      assert_redirected_to root_path
    end

    test "regular user cannot access analytics page" do
      sign_in @regular_user
      get admin_analytics_path

      assert_redirected_to root_path
    end

    test "analytics page shows stat cards" do
      sign_in @admin
      get admin_analytics_path

      assert_select ".stat-cell", minimum: 4
    end

    test "analytics page filters by date range" do
      Scenario.create!(
        workflow: @workflow,
        user: @admin,
        inputs: {},
        purpose: "simulation",
        started_at: 5.days.ago,
        outcome: "completed",
        completed_at: 5.days.ago + 30.seconds,
        duration_seconds: 30
      )

      sign_in @admin
      get admin_analytics_path, params: { range: "7d" }

      assert_response :success
    end

    test "analytics page filters by workflow" do
      sign_in @admin
      get admin_analytics_path, params: { workflow_id: @workflow.id }

      assert_response :success
    end

    test "analytics page CSV export" do
      Scenario.create!(
        workflow: @workflow,
        user: @admin,
        inputs: {},
        purpose: "simulation",
        started_at: 1.day.ago,
        outcome: "completed",
        completed_at: 1.day.ago + 30.seconds,
        duration_seconds: 30
      )

      sign_in @admin
      get admin_analytics_path(format: :csv)

      assert_response :success
      assert_equal "text/csv", response.content_type.split(";").first
    end
  end
end
