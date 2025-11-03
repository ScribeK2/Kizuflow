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
end

