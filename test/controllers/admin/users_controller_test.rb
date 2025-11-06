require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.use_transactional_tests = true

  def setup
    @admin = User.create!(
      email: "admin-users-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    @editor = User.create!(
      email: "editor-users-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    @user = User.create!(
      email: "user-users-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
  end

  test "admin should be able to access user management" do
    sign_in @admin
    get admin_users_path
    assert_response :success
  end

  test "non-admin should not be able to access user management" do
    sign_in @editor
    get admin_users_path
    assert_redirected_to root_path
    assert_equal "You don't have permission to access this page.", flash[:alert]
  end

  test "admin should be able to update user role" do
    sign_in @admin
    patch update_role_admin_user_path(@user), params: { role: "editor" }
    assert_redirected_to admin_users_path
    @user.reload
    assert_equal "editor", @user.role
  end

  test "admin should not be able to set invalid role" do
    sign_in @admin
    original_role = @user.role
    patch update_role_admin_user_path(@user), params: { role: "invalid_role" }
    assert_redirected_to admin_users_path
    @user.reload
    assert_equal original_role, @user.role
  end

  # Group assignment tests
  test "admin should be able to assign groups to user" do
    sign_in @admin
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")
    
    assert_difference("@user.groups.count", 2) do
      patch update_groups_admin_user_path(@user), params: {
        group_ids: [group1.id, group2.id]
      }
    end
    
    assert_redirected_to admin_users_path
    @user.reload
    assert_includes @user.groups.map(&:id), group1.id
    assert_includes @user.groups.map(&:id), group2.id
  end

  test "admin should be able to update user groups" do
    sign_in @admin
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")
    group3 = Group.create!(name: "Group 3")
    
    # Initially assign group1 and group2
    UserGroup.create!(group: group1, user: @user)
    UserGroup.create!(group: group2, user: @user)
    
    # Update to group2 and group3
    patch update_groups_admin_user_path(@user), params: {
      group_ids: [group2.id, group3.id]
    }
    
    @user.reload
    assert_not_includes @user.groups.map(&:id), group1.id
    assert_includes @user.groups.map(&:id), group2.id
    assert_includes @user.groups.map(&:id), group3.id
  end

  test "admin should be able to bulk assign groups to multiple users" do
    sign_in @admin
    user1 = User.create!(
      email: "user1-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    user2 = User.create!(
      email: "user2-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group = Group.create!(name: "Bulk Group")
    
    assert_difference("UserGroup.count", 2) do
      patch bulk_assign_groups_admin_users_path, params: {
        user_ids: [user1.id, user2.id],
        group_ids: [group.id]
      }
    end
    
    assert_redirected_to admin_users_path
    user1.reload
    user2.reload
    assert_includes user1.groups.map(&:id), group.id
    assert_includes user2.groups.map(&:id), group.id
  end

  test "bulk assign should replace existing group assignments" do
    sign_in @admin
    user = User.create!(
      email: "user-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    group1 = Group.create!(name: "Group 1")
    group2 = Group.create!(name: "Group 2")
    
    # Initially assign group1
    UserGroup.create!(group: group1, user: user)
    
    # Bulk assign group2
    patch bulk_assign_groups_admin_users_path, params: {
      user_ids: [user.id],
      group_ids: [group2.id]
    }
    
    user.reload
    assert_not_includes user.groups.map(&:id), group1.id
    assert_includes user.groups.map(&:id), group2.id
  end
end

