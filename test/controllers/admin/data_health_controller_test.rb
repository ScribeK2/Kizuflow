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
  # forever. It is on the dashboard so that "is the leak closed" is answerable by
  # looking, rather than by reasoning about the job.
  test "data health reports unfinished scenarios and the idle timeout" do
    workflow = Workflow.create!(title: "Health WF #{SecureRandom.hex(3)}", user: @admin)
    2.times do
      Scenario.create!(workflow: workflow, user: @admin, purpose: "live", status: "active",
                       started_at: 1.hour.ago, execution_path: [], results: {}, inputs: {})
    end
    sign_in @admin

    get admin_data_health_path

    assert_response :success
    assert_select "h2", text: /Open Runs/
    assert_match(/#{Scenario.outstanding_non_terminal}/, response.body)
    assert_match(/#{Scenario.idle_timeout_hours} hours/, response.body)
  end

  test "data health explains that the sweep runs before cleanup" do
    sign_in @admin

    get admin_data_health_path

    assert_response :success
    assert_match(/2:00 AM/, response.body, "the sweep's slot")
    assert_match(/3:00 AM/, response.body, "and cleanup's, after it")
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

  test "data health page displays table names" do
    sign_in @admin
    get admin_data_health_path

    assert_response :success
    assert_select "td", /scenarios/
    assert_select "td", /step_responses/
  end

  test "data health page displays retention configuration" do
    sign_in @admin
    get admin_data_health_path

    assert_response :success
    assert_match(/\d+ days/, response.body)
  end

  test "data health page displays draft workflow stats" do
    sign_in @admin
    # Create a draft so there's at least one
    Workflow.create!(title: "Untitled Workflow", user: @admin, status: "draft")

    get admin_data_health_path

    assert_response :success
    assert_select "h2", /Draft Workflows/
    assert_select "td", /Total Drafts/
    assert_select "td", /Expired/
    assert_select "td", /Orphaned/
  end

  test "admin can trigger manual draft cleanup" do
    sign_in @admin
    expired = Workflow.create!(title: "Expired Draft", user: @admin, status: "draft")
    expired.update_columns(draft_expires_at: 1.day.ago)

    assert_difference("Workflow.count", -1) do
      post admin_data_health_cleanup_drafts_path
    end

    assert_redirected_to admin_data_health_path
    assert_match(/Cleaned up/, flash[:notice])
  end

  test "non-admin cannot trigger manual draft cleanup" do
    sign_in @regular
    post admin_data_health_cleanup_drafts_path

    assert_redirected_to root_path
  end
end
