require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Don't use fixtures - create data directly
  self.use_transactional_tests = true

  def setup
    # Create user directly instead of using fixtures
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @user
  end

  test "should get index" do
    get root_path
    assert_response :success
  end

  test "should show user's workflows" do
    Workflow.create!(
      title: "Workflow 1",
      user: @user
    )
    Workflow.create!(
      title: "Workflow 2",
      user: @user
    )

    get root_path
    assert_response :success
    assert_select "h3", text: /Workflow/
  end

  test "should require authentication" do
    sign_out @user
    get root_path
    assert_redirected_to new_user_session_path
  end
end

