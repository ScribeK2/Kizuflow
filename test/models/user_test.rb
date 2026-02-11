require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Load fixtures only for model tests that need them
  fixtures :users

  test "should create valid user" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.valid?
  end

  test "should not create user without email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should not create user without password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
  end

  test "should have many workflows" do
    user = users(:one)
    assert_respond_to user, :workflows
  end

  test "should destroy workflows when user is destroyed" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workflow = Workflow.create!(title: "Test", user: user)

    assert_difference("Workflow.count", -1) do
      user.destroy
    end
  end

  # Role Tests
  test "should default to user role" do
    user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert_equal "user", user.role
  end

  test "should validate role inclusion" do
    user = User.new(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "invalid_role"
    )
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "admin? should return true for admin users" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    assert admin.admin?
  end

  test "admin? should return false for non-admin users" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    assert_not user.admin?
  end

  test "editor? should return true for editor users" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    assert editor.editor?
  end

  test "user? should return true for regular users" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    assert user.user?
  end

  test "can_create_workflows? should return true for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    assert admin.can_create_workflows?
  end

  test "can_create_workflows? should return true for editor" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    assert editor.can_create_workflows?
  end

  test "can_create_workflows? should return false for user" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    assert_not user.can_create_workflows?
  end

  test "can_manage_templates? should return true only for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )

    assert admin.can_manage_templates?
    assert_not editor.can_manage_templates?
    assert_not user.can_manage_templates?
  end

  test "can_access_admin? should return true only for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )

    assert admin.can_access_admin?
    assert_not editor.can_access_admin?
  end

  test "admins scope should return only admin users" do
    admin1 = User.create!(
      email: "admin1@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    admin2 = User.create!(
      email: "admin2@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )

    admins = User.admins
    assert_includes admins.map(&:id), admin1.id
    assert_includes admins.map(&:id), admin2.id
    assert_not_includes admins.map(&:id), editor.id
  end

  test "editors scope should return only editor users" do
    editor1 = User.create!(
      email: "editor1@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    editor2 = User.create!(
      email: "editor2@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )

    editors = User.editors
    assert_includes editors.map(&:id), editor1.id
    assert_includes editors.map(&:id), editor2.id
    assert_not_includes editors.map(&:id), user.id
  end

  # Group association tests
  test "should have many groups through user_groups" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")

    UserGroup.create!(group: group1, user: user)
    UserGroup.create!(group: group2, user: user)

    assert_equal 2, user.groups.count
    assert_includes user.groups.map(&:id), group1.id
    assert_includes user.groups.map(&:id), group2.id
  end

  test "accessible_groups should return all groups for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")

    accessible = admin.accessible_groups
    assert_includes accessible.map(&:id), group1.id
    assert_includes accessible.map(&:id), group2.id
  end

  test "accessible_groups should return only assigned groups for non-admin" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assigned_group = Group.create!(name: "Assigned Group")
    other_group = Group.create!(name: "Other Group")

    UserGroup.create!(group: assigned_group, user: user)

    accessible = user.accessible_groups
    assert_includes accessible.map(&:id), assigned_group.id
    assert_not_includes accessible.map(&:id), other_group.id
  end

  test "should destroy user_groups when user is destroyed" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group = Group.create!(name: "Test Group")
    UserGroup.create!(group: group, user: user)

    assert_difference("UserGroup.count", -1) do
      user.destroy
    end
  end

  test "should destroy user_groups when group is destroyed" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group = Group.create!(name: "Test Group")
    UserGroup.create!(group: group, user: user)

    assert_difference("UserGroup.count", -1) do
      group.destroy
    end
  end
end
