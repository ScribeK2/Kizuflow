require "test_helper"

class GroupTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # Validations
  test "should create group with valid attributes" do
    group = Group.new(name: "Test Group", description: "A test group")

    assert_predicate group, :valid?
    assert group.save
  end

  test "should not create group without name" do
    group = Group.new(description: "A test group")

    assert_not group.valid?
    assert_includes group.errors[:name], "can't be blank"
  end

  test "should allow duplicate names with different parents" do
    parent1 = Group.create!(name: "Parent 1")
    parent2 = Group.create!(name: "Parent 2")
    child1 = Group.create!(name: "Child", parent: parent1)
    child2 = Group.create!(name: "Child", parent: parent2)

    assert_predicate child1, :valid?
    assert_predicate child2, :valid?
  end

  test "should not allow duplicate names with same parent" do
    parent = Group.create!(name: "Parent")
    Group.create!(name: "Child", parent: parent)
    duplicate = Group.new(name: "Child", parent: parent)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  # Associations
  test "should belong to parent" do
    parent = Group.create!(name: "Parent")
    child = Group.create!(name: "Child", parent: parent)

    assert_equal parent, child.parent
  end

  test "should have many children" do
    parent = Group.create!(name: "Parent")
    child1 = Group.create!(name: "Child 1", parent: parent)
    child2 = Group.create!(name: "Child 2", parent: parent)

    assert_equal 2, parent.children.count
    assert_includes parent.children.map(&:id), child1.id
    assert_includes parent.children.map(&:id), child2.id
  end

  test "should have many workflows through group_workflows" do
    group = Group.create!(name: "Test Group")
    workflow1 = Workflow.create!(title: "Workflow 1", user: @user)
    workflow2 = Workflow.create!(title: "Workflow 2", user: @user)

    GroupWorkflow.create!(group: group, workflow: workflow1, is_primary: true)
    GroupWorkflow.create!(group: group, workflow: workflow2, is_primary: false)

    assert_equal 2, group.workflows.count
    assert_includes group.workflows.map(&:id), workflow1.id
    assert_includes group.workflows.map(&:id), workflow2.id
  end

  test "should have many users through user_groups" do
    group = Group.create!(name: "Test Group")
    user1 = User.create!(email: "user1@test.com", password: "password123", password_confirmation: "password123")
    user2 = User.create!(email: "user2@test.com", password: "password123", password_confirmation: "password123")

    UserGroup.create!(group: group, user: user1)
    UserGroup.create!(group: group, user: user2)

    assert_equal 2, group.users.count
    assert_includes group.users.map(&:id), user1.id
    assert_includes group.users.map(&:id), user2.id
  end

  # Scopes
  test "roots scope should return only root groups" do
    root1 = Group.create!(name: "Root 1")
    root2 = Group.create!(name: "Root 2")
    child = Group.create!(name: "Child", parent: root1)

    roots = Group.roots

    assert_includes roots.map(&:id), root1.id
    assert_includes roots.map(&:id), root2.id
    assert_not_includes roots.map(&:id), child.id
  end

  test "children_of scope should return children of parent" do
    parent = Group.create!(name: "Parent")
    child1 = Group.create!(name: "Child 1", parent: parent)
    child2 = Group.create!(name: "Child 2", parent: parent)
    other = Group.create!(name: "Other")

    children = Group.children_of(parent)

    assert_equal 2, children.count
    assert_includes children.map(&:id), child1.id
    assert_includes children.map(&:id), child2.id
    assert_not_includes children.map(&:id), other.id
  end

  test "visible_to scope should return all groups for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")

    visible = Group.visible_to(admin)

    assert_includes visible.map(&:id), group1.id
    assert_includes visible.map(&:id), group2.id
  end

  test "visible_to scope should return assigned groups plus Uncategorized for regular user" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assigned_group = Group.create!(name: "Assigned Group")
    other_group = Group.create!(name: "Other Group")
    uncategorized = Group.uncategorized

    UserGroup.create!(group: assigned_group, user: user)

    visible = Group.visible_to(user)

    assert_includes visible.map(&:id), assigned_group.id
    assert_includes visible.map(&:id), uncategorized.id
    assert_not_includes visible.map(&:id), other_group.id
  end

  # Tree traversal methods
  test "root? should return true for root groups" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)

    assert_predicate root, :root?
    assert_not child.root?
  end

  test "leaf? should return true for groups without children" do
    parent = Group.create!(name: "Parent")
    child = Group.create!(name: "Child", parent: parent)

    assert_not parent.leaf?
    assert_predicate child, :leaf?
  end

  test "depth should calculate depth correctly" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)
    grandchild = Group.create!(name: "Grandchild", parent: child)

    assert_equal 0, root.depth
    assert_equal 1, child.depth
    assert_equal 2, grandchild.depth
  end

  test "ancestors should return all ancestors" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)
    grandchild = Group.create!(name: "Grandchild", parent: child)

    ancestors = grandchild.ancestors

    assert_equal 2, ancestors.length
    assert_includes ancestors.map(&:id), root.id
    assert_includes ancestors.map(&:id), child.id
  end

  test "descendants should return all descendants recursively" do
    root = Group.create!(name: "Root")
    child1 = Group.create!(name: "Child 1", parent: root)
    child2 = Group.create!(name: "Child 2", parent: root)
    grandchild = Group.create!(name: "Grandchild", parent: child1)

    descendants = root.descendants

    assert_equal 3, descendants.length
    assert_includes descendants.map(&:id), child1.id
    assert_includes descendants.map(&:id), child2.id
    assert_includes descendants.map(&:id), grandchild.id
  end

  test "full_path should return full path with separator" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)
    grandchild = Group.create!(name: "Grandchild", parent: child)

    assert_equal "Root", root.full_path
    assert_equal "Root > Child", child.full_path
    assert_equal "Root > Child > Grandchild", grandchild.full_path
  end

  test "full_path should accept custom separator" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)

    assert_equal "Root / Child", child.full_path(separator: " / ")
  end

  test "workflows_count should count workflows including descendants" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)

    workflow1 = Workflow.create!(title: "Workflow 1", user: @user)
    workflow2 = Workflow.create!(title: "Workflow 2", user: @user)

    GroupWorkflow.create!(group: root, workflow: workflow1, is_primary: true)
    GroupWorkflow.create!(group: child, workflow: workflow2, is_primary: true)

    assert_equal 2, root.workflows_count(include_descendants: true)
    assert_equal 1, root.workflows_count(include_descendants: false)
    assert_equal 1, child.workflows_count(include_descendants: true)
  end

  # Circular reference prevention
  test "should prevent setting group as its own parent" do
    group = Group.create!(name: "Test Group")
    group.parent_id = group.id

    assert_not group.valid?
    assert_includes group.errors[:parent_id], "cannot be set to itself"
  end

  test "should prevent direct circular reference" do
    parent = Group.create!(name: "Parent")
    child = Group.create!(name: "Child", parent: parent)

    parent.parent_id = child.id

    assert_not parent.valid?
    assert_includes parent.errors[:parent_id], "cannot create circular reference"
  end

  test "should prevent indirect circular reference" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)
    grandchild = Group.create!(name: "Grandchild", parent: child)

    root.parent_id = grandchild.id

    assert_not root.valid?
    assert_includes root.errors[:parent_id], "cannot create circular reference"
  end

  test "should prevent setting parent that is a descendant" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)

    root.parent_id = child.id

    assert_not root.valid?
    assert_includes root.errors[:parent_id], "cannot create circular reference"
  end

  # Max depth validation
  test "should allow up to 5 levels deep" do
    level1 = Group.create!(name: "Level 1")
    level2 = Group.create!(name: "Level 2", parent: level1)
    level3 = Group.create!(name: "Level 3", parent: level2)
    level4 = Group.create!(name: "Level 4", parent: level3)
    level5 = Group.create!(name: "Level 5", parent: level4)

    assert_predicate level5, :valid?
  end

  test "should not allow more than 5 levels deep" do
    level1 = Group.create!(name: "Level 1")
    level2 = Group.create!(name: "Level 2", parent: level1)
    level3 = Group.create!(name: "Level 3", parent: level2)
    level4 = Group.create!(name: "Level 4", parent: level3)
    level5 = Group.create!(name: "Level 5", parent: level4)
    level6 = Group.new(name: "Level 6", parent: level5)

    assert_not level6.valid?
    assert_includes level6.errors[:parent_id], "maximum depth of 5 levels exceeded"
  end

  # Class methods
  test "uncategorized should return or create Uncategorized group" do
    uncategorized1 = Group.uncategorized
    uncategorized2 = Group.uncategorized

    assert_equal uncategorized1.id, uncategorized2.id
    assert_equal "Uncategorized", uncategorized1.name
  end

  # Permission methods
  test "can_be_viewed_by? should return true for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    group = Group.create!(name: "Test Group")

    assert group.can_be_viewed_by?(admin)
  end

  test "can_be_viewed_by? should return true for assigned user" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group = Group.create!(name: "Test Group")
    UserGroup.create!(group: group, user: user)

    assert group.can_be_viewed_by?(user)
  end

  test "can_be_viewed_by? should return true if user assigned to ancestor" do
    root = Group.create!(name: "Root")
    child = Group.create!(name: "Child", parent: root)
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    UserGroup.create!(group: root, user: user)

    assert child.can_be_viewed_by?(user)
  end

  # Folder associations
  test "should have many folders" do
    group = Group.create!(name: "Folder Group")
    folder1 = Folder.create!(name: "F1", group: group)
    folder2 = Folder.create!(name: "F2", group: group)

    assert_equal 2, group.folders.count
    assert_includes group.folders, folder1
    assert_includes group.folders, folder2
  end

  test "uncategorized_workflows should return workflows without folder" do
    group = Group.create!(name: "Folder Group")
    folder = Folder.create!(name: "Categorized", group: group)
    user = User.create!(email: "foldertestuser@example.com", password: "password123", password_confirmation: "password123")
    wf_in_folder = Workflow.create!(title: "In Folder", user: user)
    wf_uncategorized = Workflow.create!(title: "Uncategorized", user: user)

    GroupWorkflow.create!(group: group, workflow: wf_in_folder, folder: folder, is_primary: true)
    GroupWorkflow.create!(group: group, workflow: wf_uncategorized, is_primary: true)

    uncategorized = group.uncategorized_workflows
    assert_includes uncategorized, wf_uncategorized
    assert_not_includes uncategorized, wf_in_folder
  end

  test "can_be_viewed_by? should return false for unassigned user" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group = Group.create!(name: "Test Group")

    assert_not group.can_be_viewed_by?(user)
  end
end
