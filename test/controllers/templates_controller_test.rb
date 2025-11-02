require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
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
    @template = Template.create!(
      name: "Test Template",
      description: "A test template",
      category: "post-onboarding",
      is_public: true,
      workflow_data: [{ type: "question", title: "Question 1" }]
    )
    sign_in @user
  end

  test "should get index" do
    get templates_path
    assert_response :success
  end

  test "should get show" do
    get template_path(@template)
    assert_response :success
  end

  test "should search templates" do
    Template.create!(
      name: "Post-Onboarding Checklist",
      category: "post-onboarding",
      is_public: true,
      workflow_data: []
    )
    Template.create!(
      name: "Troubleshooting Guide",
      category: "troubleshooting",
      is_public: true,
      workflow_data: []
    )

    get templates_path, params: { search: "Post-Onboarding" }
    assert_response :success
    assert_select "h3", text: /Post-Onboarding/
  end

  test "should use template to create workflow" do
    assert_difference("Workflow.count") do
      post use_template_path(@template)
    end

    workflow = Workflow.last
    assert_redirected_to edit_workflow_path(workflow)
    assert workflow.title.include?(@template.name)
    assert_equal @template.workflow_data, workflow.steps
  end
end

