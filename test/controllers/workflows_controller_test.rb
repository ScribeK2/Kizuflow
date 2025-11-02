require "test_helper"

class WorkflowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Don't use fixtures - create data directly to avoid JSON fixture teardown issues
  self.use_transactional_tests = true

  def setup
    # Create user directly instead of using fixtures to avoid JSON fixture issues
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @workflow = Workflow.create!(
      title: "Test Workflow",
      description: "A test workflow",
      user: @user,
      steps: [{ type: "question", title: "Question 1" }]
    )
    sign_in @user
  end

  test "should get index" do
    get workflows_path
    assert_response :success
  end

  test "should get show" do
    get workflow_path(@workflow)
    assert_response :success
  end

  test "should get new" do
    get new_workflow_path
    assert_response :success
  end

  test "should create workflow" do
    assert_difference("Workflow.count") do
      post workflows_path, params: {
        workflow: {
          title: "New Workflow",
          description: "New description",
          steps: [
            { type: "question", title: "Question 1", description: "First question" }
          ]
        }
      }
    end

    assert_redirected_to workflow_path(Workflow.last)
    assert_equal "Workflow was successfully created.", flash[:notice]
  end

  test "should get edit" do
    get edit_workflow_path(@workflow)
    assert_response :success
  end

  test "should update workflow" do
    patch workflow_path(@workflow), params: {
      workflow: {
        title: "Updated Title",
        description: "Updated description"
      }
    }

    assert_redirected_to workflow_path(@workflow)
    @workflow.reload
    assert_equal "Updated Title", @workflow.title
    assert_equal "Updated description", @workflow.description
  end

  test "should update workflow with steps" do
    patch workflow_path(@workflow), params: {
      workflow: {
        title: "Updated Title",
        steps: [
          { type: "question", title: "New Question", index: 0 },
          { type: "action", title: "New Action", index: 1 }
        ]
      }
    }

    assert_redirected_to workflow_path(@workflow)
    @workflow.reload
    assert_equal 2, @workflow.steps.length
  end

  test "should destroy workflow" do
    assert_difference("Workflow.count", -1) do
      delete workflow_path(@workflow)
    end

    assert_redirected_to workflows_path
  end

  test "should not allow editing other user's workflow" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    other_workflow = Workflow.create!(
      title: "Other Workflow",
      user: other_user
    )

    get edit_workflow_path(other_workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to access this workflow.", flash[:alert]
  end

  test "should export workflow as JSON" do
    get export_workflow_path(@workflow)
    assert_response :success
    assert_match(/application\/json/, response.content_type)
  end

  test "should export workflow as PDF" do
    get export_pdf_workflow_path(@workflow)
    assert_response :success
    assert_match(/application\/pdf/, response.content_type)
  end

  test "should require authentication" do
    sign_out @user
    get workflows_path
    assert_redirected_to new_user_session_path
  end
end

