require "test_helper"

class GroupAssignmentIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "admin-integration-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "admin"
    )
    @editor = User.create!(
      email: "editor-integration-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
  end

  test "admin can create workflow and assign it to a group" do
    sign_in @admin
    group = Group.create!(name: "Test Group")

    # Create workflow with group assignment
    post workflows_path, params: {
      workflow: {
        title: "Grouped Workflow",
        group_ids: [group.id]
      }
    }

    assert_redirected_to workflow_path(Workflow.last)
    workflow = Workflow.last

    assert_includes workflow.groups.map(&:id), group.id
  end

  test "admin can update workflow group assignment" do
    sign_in @admin
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")
    workflow = Workflow.create!(title: "Test Workflow", user: @admin)
    GroupWorkflow.create!(group: group1, workflow: workflow, is_primary: true)

    # Update to group2
    patch workflow_path(workflow), params: {
      workflow: {
        title: workflow.title,
        group_ids: [group2.id]
      }
    }

    workflow.reload

    assert_not_includes workflow.groups.map(&:id), group1.id
    assert_includes workflow.groups.map(&:id), group2.id
  end

  test "a workflow created without groups is filed nowhere" do
    sign_in @editor

    post workflows_path, params: { workflow: { title: "Default Workflow" } }

    assert_empty Workflow.last.groups
  end
end
