require "test_helper"

# Who sees a workflow is decided by the groups it is filed in (Stage 4a). This
# replaced backward_compatibility_test.rb, which pinned the auto-filing into
# Uncategorized that Global retired.
class WorkflowAudienceTest < ActiveSupport::TestCase
  setup do
    @owner = create_user("editor")
    @admin = create_user("admin")
    @regular = create_user("regular")
  end

  test "a workflow with no groups is visible to its owner" do
    workflow = Workflow.create!(title: "Nobody Chosen", user: @owner)

    assert_includes Workflow.visible_to(@owner), workflow
  end

  test "a workflow with no groups is visible to admins" do
    workflow = Workflow.create!(title: "Nobody Chosen", user: @owner)

    assert_includes Workflow.visible_to(@admin), workflow
  end

  test "a workflow filed in a group is not visible to someone outside it" do
    group = Group.create!(name: "Restricted #{SecureRandom.hex(3)}")
    workflow = Workflow.create!(title: "Restricted", user: @owner)
    GroupWorkflow.create!(group: group, workflow: workflow, is_primary: true)

    assert_not_includes Workflow.visible_to(@regular), workflow
  end

  private

  def create_user(role)
    User.create!(email: "audience-#{role}-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                 password_confirmation: "password123!", role: role)
  end
end
