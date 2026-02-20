require "test_helper"

class FolderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "folder_test@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
    @group = Group.create!(name: "Test Group for Folders")
  end

  # Validations
  test "should create folder with valid attributes" do
    folder = Folder.new(name: "Website Issues", group: @group)

    assert_predicate folder, :valid?
    assert folder.save
  end

  test "should not create folder without name" do
    folder = Folder.new(group: @group)

    assert_not folder.valid?
    assert_includes folder.errors[:name], "can't be blank"
  end

  test "should not create folder without group" do
    folder = Folder.new(name: "Orphan Folder")

    assert_not folder.valid?
    assert_includes folder.errors[:group], "must exist"
  end

  test "should not allow duplicate names within same group" do
    Folder.create!(name: "DNS", group: @group)
    duplicate = Folder.new(name: "DNS", group: @group)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should allow duplicate names across different groups" do
    other_group = Group.create!(name: "Other Group for Folders")
    Folder.create!(name: "DNS", group: @group)
    folder2 = Folder.new(name: "DNS", group: other_group)

    assert_predicate folder2, :valid?
  end

  test "should validate name length" do
    folder = Folder.new(name: "A" * 256, group: @group)

    assert_not folder.valid?
    assert_includes folder.errors[:name], "is too long (maximum is 255 characters)"
  end

  # Associations
  test "should belong to group" do
    folder = Folder.create!(name: "Test Folder", group: @group)

    assert_equal @group, folder.group
  end

  test "should have many group_workflows" do
    folder = Folder.create!(name: "Test Folder", group: @group)
    workflow = Workflow.create!(title: "Test WF", user: @user)
    gw = GroupWorkflow.create!(group: @group, workflow: workflow, folder: folder)

    assert_includes folder.group_workflows, gw
  end

  test "should have many workflows through group_workflows" do
    folder = Folder.create!(name: "Test Folder", group: @group)
    workflow1 = Workflow.create!(title: "WF 1", user: @user)
    workflow2 = Workflow.create!(title: "WF 2", user: @user)
    GroupWorkflow.create!(group: @group, workflow: workflow1, folder: folder, is_primary: true)
    GroupWorkflow.create!(group: @group, workflow: workflow2, folder: folder)

    assert_equal 2, folder.workflows.count
    assert_includes folder.workflows, workflow1
    assert_includes folder.workflows, workflow2
  end

  # Scopes
  test "ordered scope should sort by position then name" do
    folder_c = Folder.create!(name: "Charlie", group: @group, position: 2)
    folder_a = Folder.create!(name: "Alpha", group: @group, position: 1)
    folder_b = Folder.create!(name: "Bravo", group: @group, position: 1)

    ordered = @group.folders.ordered
    assert_equal folder_a, ordered.first
    assert_equal folder_b, ordered.second
    assert_equal folder_c, ordered.third
  end

  # Workflow count
  test "workflows_count should return count of workflows in folder" do
    folder = Folder.create!(name: "Test Folder", group: @group)
    workflow1 = Workflow.create!(title: "WF 1", user: @user)
    workflow2 = Workflow.create!(title: "WF 2", user: @user)
    GroupWorkflow.create!(group: @group, workflow: workflow1, folder: folder, is_primary: true)
    GroupWorkflow.create!(group: @group, workflow: workflow2, folder: folder)

    assert_equal 2, folder.workflows_count
  end

  # Destroying folder should nullify group_workflows folder_id
  test "destroying folder should nullify folder_id on group_workflows" do
    folder = Folder.create!(name: "Test Folder", group: @group)
    workflow = Workflow.create!(title: "WF", user: @user)
    gw = GroupWorkflow.create!(group: @group, workflow: workflow, folder: folder, is_primary: true)

    folder.destroy

    gw.reload
    assert_nil gw.folder_id
  end
end
