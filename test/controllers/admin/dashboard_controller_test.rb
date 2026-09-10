require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "admin-dash-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "admin"
    )
    @editor = User.create!(
      email: "editor-dash-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    @user = User.create!(
      email: "user-dash-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "user"
    )
  end

  test "admin should be able to access admin dashboard" do
    sign_in @admin
    get admin_root_path

    assert_response :success
  end

  test "editor should not be able to access admin dashboard" do
    sign_in @editor
    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You don't have permission to access this page.", flash[:alert]
  end

  test "user should not be able to access admin dashboard" do
    sign_in @user
    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You don't have permission to access this page.", flash[:alert]
  end

  # setup creates @editor and @user with no groups, so both are waiting.
  test "overview lists accounts waiting for a group, never admins" do
    sign_in @admin
    get admin_root_path

    assert_response :success
    assert_select "h1", text: "Overview"
    assert_select "#attention-awaiting-groups", text: /#{Regexp.escape(@user.email)}/
    assert_select "#attention-awaiting-groups", text: /#{Regexp.escape(@editor.email)}/
    assert_select "#attention-awaiting-groups a[href=?]", admin_user_path(@user), text: @user.email
    assert_select "#attention-awaiting-groups a", text: @admin.email, count: 0
    assert_select "#attention-awaiting-groups a[href=?]",
                  admin_users_path(group: Admin::UsersFilter::AWAITING_GROUPS), text: "View all"
  end

  test "overview says so in one line when nothing is waiting" do
    group = Group.create!(name: "Dash #{SecureRandom.hex(3)}")
    User.awaiting_groups.find_each { |user| UserGroup.create!(user: user, group: group) }
    sign_in @admin

    get admin_root_path

    assert_select ".admin-attention__clear", text: /Nothing needs attention/
    assert_select ".list-section", 0
    assert_select "nav.admin-nav .admin-nav__count", 0
  end

  test "the Overview sidebar item carries the number of waiting items on every admin page" do
    sign_in @admin
    get admin_groups_path

    assert_select "nav.admin-nav a[href=?] .admin-nav__count", admin_root_path, text: "1"
  end
end
