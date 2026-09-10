require "test_helper"

class Admin::DataHealthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "admin-health-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "admin"
    )
    @regular = User.create!(
      email: "user-health-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "user"
    )
  end

  test "admin can access data health page" do
    sign_in @admin
    get admin_data_health_path

    assert_response :success
    assert_select "h1", /Data Health/
  end

  # The leak indicator. Retention can only collect runs that ended, and until the
  # idle sweep existed nothing ended an abandoned one, so this number grew
  # forever. It is on the page so that "is the leak closed" is answerable by
  # looking, rather than by reasoning about the job.
  test "data health reports unfinished runs, the idle timeout and retention" do
    workflow = Workflow.create!(title: "Health WF #{SecureRandom.hex(3)}", user: @admin)
    2.times do
      Scenario.create!(workflow: workflow, user: @admin, purpose: "live", status: "active",
                       started_at: 1.hour.ago, execution_path: [], results: {}, inputs: {})
    end
    sign_in @admin

    get admin_data_health_path

    assert_response :success
    assert_select "#runs-and-retention .stat-cell__value", text: Scenario.outstanding_non_terminal.to_s
    assert_select "#runs-and-retention .stat-cell__value", text: "#{Scenario.idle_timeout_hours} hours"
    assert_select "#runs-and-retention .stat-cell__value", text: "#{Scenario.live_retention_days} days"
  end

  test "sections come in the order an admin needs them (Q54)" do
    sign_in @admin

    get admin_data_health_path

    assert_equal %w[background-jobs runs-and-retention drafts versions storage],
                 css_select(".admin-health > section.list-section").pluck("id")
  end

  test "the server disclosure lists settings, commands and the schedule, sweep before cleanup" do
    sign_in @admin

    get admin_data_health_path

    assert_select "details#server summary", text: "For whoever runs the server"
    assert_select "details#server code", text: "SCENARIO_IDLE_TIMEOUT_HOURS"
    assert_select "details#server code", text: "WORKFLOW_VERSION_RESTORE_LIMIT"
    assert_select "details#server code", text: "bin/rails scenarios:sweep_idle DRY_RUN=1"
    schedule = css_select("details#server .admin-health__schedule li").map { it.text.squish }
    sweep = schedule.index { it.start_with?("Sweep idle scenarios") }
    cleanup = schedule.index { it.start_with?("Cleanup scenarios") }
    assert_operator sweep, :<, cleanup, "the sweep settles runs so cleanup can collect them"
    assert_includes schedule, "Sweep idle scenarios Daily at 02:00"
    assert_select "details#server ol.admin-health__steps > li", 3
    assert_select "details#server ol.admin-health__steps code",
                  text: "bin/rails runner 'puts SolidQueue::Process.pluck(:kind, :hostname, :last_heartbeat_at)'"
    assert_select "details#server ol.admin-health__steps code", text: "bin/rails restart"
  end

  test "non-admin is redirected from data health page" do
    sign_in @regular
    get admin_data_health_path

    assert_redirected_to root_path
  end

  test "unauthenticated user is redirected from data health page" do
    get admin_data_health_path

    assert_response :redirect
  end

  test "storage counts records, and shows a size only where the database reports one (Q55)" do
    sign_in @admin

    get admin_data_health_path

    assert_select "#storage .stat-cell__label", text: "Runs"
    assert_select "#storage .stat-cell__label", text: "Step responses"
    assert_no_match(%r{N/A}, response.body)
    if ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      assert_select "#storage .stat-cell__detail", 4
    else
      assert_select "#storage .stat-cell__detail", 0
    end
  end

  test "data health page displays draft workflow stats and Clean Up Now" do
    sign_in @admin
    Workflow.create!(title: "Untitled Workflow", user: @admin, status: "draft")

    get admin_data_health_path

    assert_response :success
    assert_select "#drafts .stat-cell__label", text: "Drafts"
    assert_select "#drafts .stat-cell__label", text: "Expired"
    assert_select "#drafts .stat-cell__label", text: "Orphaned"
    assert_select "#drafts form[action=?] button", admin_data_health_cleanup_drafts_path, text: "Clean Up Now"
  end

  test "admin can trigger manual draft cleanup" do
    sign_in @admin
    expired = Workflow.create!(title: "Expired Draft", user: @admin, status: "draft")
    expired.update_columns(draft_expires_at: 1.day.ago)

    assert_difference("Workflow.count", -1) do
      post admin_data_health_cleanup_drafts_path
    end

    assert_redirected_to admin_data_health_path(anchor: "drafts")
    assert_match(/Cleaned up/, flash[:notice])
  end

  test "non-admin cannot trigger manual draft cleanup" do
    sign_in @regular
    post admin_data_health_cleanup_drafts_path

    assert_redirected_to root_path
  end

  # The Overview's job rows link here, so this page must say what they found.
  test "data health reports background job health, and says when there is nothing to track" do
    sign_in @admin
    get admin_data_health_path

    assert_select "#background-jobs h2", text: "Background Jobs"
    assert_select "#background-jobs", text: /nothing to report/
  end

  test "Data Health has no filled button" do
    sign_in @admin
    get admin_data_health_path

    assert_select ".admin-health .btn--primary", 0
  end
end
