require "test_helper"

class WorkflowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Don't use fixtures - create data directly to avoid JSON fixture teardown issues
  self.use_transactional_tests = true

  def setup
    # Create users with different roles (using unique emails)
    @admin = User.create!(
      email: "admin-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    @editor = User.create!(
      email: "editor-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    @user = User.create!(
      email: "user-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    @workflow = Workflow.create!(
      title: "Test Workflow",
      description: "A test workflow",
      user: @editor,
      steps: [{ type: "question", title: "Question 1", question: "What is your name?" }]
    )
    @public_workflow = Workflow.create!(
      title: "Public Workflow",
      description: "A public workflow",
      user: @editor,
      is_public: true,
      steps: [{ type: "question", title: "Question 1", question: "What is your name?" }]
    )
    sign_in @editor
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
            { type: "question", title: "Question 1", question: "What is your name?", description: "First question" }
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
    # Description is ActionText::RichText, check body content
    assert_equal "Updated description", @workflow.description.to_plain_text
  end

  test "should update workflow with steps" do
    patch workflow_path(@workflow), params: {
      workflow: {
        title: "Updated Title",
        steps: [
          { type: "question", title: "New Question", question: "What is your name?", index: 0 },
          { type: "action", title: "New Action", index: 1 }
        ]
      }
    }

    assert_redirected_to workflow_path(@workflow)
    @workflow.reload
    assert_equal 2, @workflow.steps.length
  end

  test "should update workflow with is_public flag" do
    patch workflow_path(@workflow), params: {
      workflow: {
        title: @workflow.title,
        is_public: true
      }
    }

    assert_redirected_to workflow_path(@workflow)
    @workflow.reload
    assert @workflow.is_public?
  end

  test "should destroy workflow" do
    assert_difference("Workflow.count", -1) do
      delete workflow_path(@workflow)
    end

    assert_redirected_to workflows_path
  end

  test "should require authentication" do
    sign_out @editor
    get workflows_path
    assert_redirected_to new_user_session_path
  end

  # Authorization Tests
  test "index should show workflows visible to user based on role" do
    # Editor should see own workflows + public workflows
    sign_in @editor
    get workflows_path
    assert_response :success
    assert_select "h1", text: /My Workflows/
    
    # User should see only public workflows
    sign_in @user
    get workflows_path
    assert_response :success
    assert_select "h1", text: /Public Workflows/
  end

  test "admin should be able to view any workflow" do
    sign_in @admin
    get workflow_path(@workflow)
    assert_response :success
  end

  test "editor should be able to view own workflow" do
    sign_in @editor
    get workflow_path(@workflow)
    assert_response :success
  end

  test "editor should be able to view public workflow" do
    sign_in @editor
    get workflow_path(@public_workflow)
    assert_response :success
  end

  test "user should be able to view public workflow" do
    sign_in @user
    get workflow_path(@public_workflow)
    assert_response :success
  end

  test "user should not be able to view private workflow" do
    sign_in @user
    get workflow_path(@workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to view this workflow.", flash[:alert]
  end

  test "admin should be able to create workflows" do
    sign_in @admin
    get new_workflow_path
    assert_response :success
  end

  test "editor should be able to create workflows" do
    sign_in @editor
    get new_workflow_path
    assert_response :success
  end

  test "user should not be able to create workflows" do
    sign_in @user
    get new_workflow_path
    assert_redirected_to root_path
    assert_equal "You don't have permission to perform this action.", flash[:alert]
  end

  test "admin should be able to edit any workflow" do
    sign_in @admin
    get edit_workflow_path(@workflow)
    assert_response :success
  end

  test "editor should be able to edit own workflow" do
    sign_in @editor
    get edit_workflow_path(@workflow)
    assert_response :success
  end

  test "editor should not be able to edit other user's workflow" do
    other_workflow = Workflow.create!(
      title: "Other Workflow",
      user: @admin,
      is_public: false
    )
    sign_in @editor
    get edit_workflow_path(other_workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to edit this workflow.", flash[:alert]
  end

  test "user should not be able to edit workflows" do
    sign_in @user
    get edit_workflow_path(@public_workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to edit this workflow.", flash[:alert]
  end

  test "admin should be able to delete any workflow" do
    workflow_to_delete = Workflow.create!(
      title: "To Delete",
      user: @editor,
      is_public: false
    )
    sign_in @admin
    assert_difference("Workflow.count", -1) do
      delete workflow_path(workflow_to_delete)
    end
  end

  test "editor should be able to delete own workflow" do
    sign_in @editor
    assert_difference("Workflow.count", -1) do
      delete workflow_path(@workflow)
    end
  end

  test "editor should not be able to delete other user's workflow" do
    other_workflow = Workflow.create!(
      title: "Other Workflow",
      user: @admin,
      is_public: false
    )
    sign_in @editor
    assert_no_difference("Workflow.count") do
      delete workflow_path(other_workflow)
    end
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to delete this workflow.", flash[:alert]
  end

  test "user should not be able to delete workflows" do
    sign_in @user
    assert_no_difference("Workflow.count") do
      delete workflow_path(@public_workflow)
    end
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to delete this workflow.", flash[:alert]
  end

  test "admin should be able to export any workflow" do
    sign_in @admin
    get export_workflow_path(@workflow)
    assert_response :success
    assert_match(/application\/json/, response.content_type)
  end

  test "user should be able to export public workflow" do
    sign_in @user
    get export_workflow_path(@public_workflow)
    assert_response :success
  end

  test "user should not be able to export private workflow" do
    sign_in @user
    get export_workflow_path(@workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to view this workflow.", flash[:alert]
  end

  test "should export workflow as PDF" do
    sign_in @editor
    get export_pdf_workflow_path(@workflow)
    assert_response :success
    assert_match(/application\/pdf/, response.content_type)
  end
end

