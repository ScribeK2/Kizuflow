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

    # "All" claimed all time and could not deliver it: runs are deleted at the
    # retention horizon. Rolling runs up before deleting them is the durable fix;
    # until that exists the label must not overstate what the database holds.
    test "the widest range does not claim to be all time" do
      sign_in @admin

      get admin_analytics_path

      assert_response :success
      assert_match(/All kept/, response.body)
      assert_match(/#{Scenario.live_retention_days} days \(live\)/, response.body,
                   "the horizon has to be stated, or the label is just a different vague word")
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
