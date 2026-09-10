require "test_helper"

class WorkflowGroupsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "wf-groups-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                         password_confirmation: "password123!", role: "editor")
    @support = Group.create!(name: "Support #{SecureRandom.hex(3)}")
    @billing = Group.create!(name: "Billing #{SecureRandom.hex(3)}")
    @folder = Folder.create!(name: "Escalations", group: @support)
    @workflow = Workflow.create!(title: "Grouped", user: @user)
    GroupWorkflow.create!(group: @support, workflow: @workflow, folder: @folder, is_primary: true)
  end

  # The builder's Details panel autosaves every field at once, group ticks
  # included, so replace_groups! ran on every description edit. It destroyed and
  # recreated every row, and folder_id lives on the row.
  test "saving the groups a workflow is already in keeps its folder" do
    @workflow.replace_groups!([@support.id.to_s])

    assert_equal @folder.id, @workflow.group_workflows.find_by(group: @support).folder_id
  end

  test "adding a group keeps the existing group's folder and primary" do
    @workflow.replace_groups!([@billing.id, @support.id])

    rows = @workflow.group_workflows.reload.index_by(&:group_id)
    assert_equal @folder.id, rows[@support.id].folder_id
    assert_predicate rows[@support.id], :is_primary?
    assert_not rows[@billing.id].is_primary?
  end

  test "dropping the primary makes the first remaining group that is not Global primary" do
    @workflow.replace_groups!([global_group.id, @billing.id])

    assert_equal @billing, @workflow.reload.primary_group
  end

  test "Global is primary only when it is the only group" do
    @workflow.replace_groups!([global_group.id])

    assert_equal global_group, @workflow.reload.primary_group
  end

  test "an empty choice leaves the workflow in no groups" do
    @workflow.replace_groups!([""])

    assert_empty @workflow.reload.groups
  end

  test "a non-admin can neither add nor remove a group they don't reach" do
    UserGroup.create!(user: @user, group: @billing)
    unreached = Group.create!(name: "Unreached #{SecureRandom.hex(3)}")

    ids = Group.assignable_ids_for(@user, [@billing.id.to_s, unreached.id.to_s], current_ids: [@support.id])

    assert_equal [@billing.id, @support.id], ids
  end

  test "an admin's choice stands" do
    admin = User.create!(email: "wf-groups-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                         password_confirmation: "password123!", role: "admin")

    assert_equal [@billing.id], Group.assignable_ids_for(admin, [@billing.id.to_s], current_ids: [@support.id])
  end
end
