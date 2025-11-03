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
end

