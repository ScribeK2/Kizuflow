require "test_helper"

# /admin/users/:id — one person's page. The table and its bulk actions are
# covered in users_controller_test.rb.
class Admin::UserPageTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "page-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    @editor = User.create!(email: "page-editor-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
    @user = User.create!(email: "page-user-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                         password_confirmation: "password123!", role: "regular")
  end

  test "the user page says who they are, what they own, when they were last active and their groups" do
    group = Group.create!(name: "Page Group #{SecureRandom.hex(3)}")
    UserGroup.create!(user: @user, group: group)
    workflow = Workflow.create!(title: "Owned #{SecureRandom.hex(3)}", user: @user)
    Workflow.create!(title: "Owned too #{SecureRandom.hex(3)}", user: @user)
    Scenario.create!(workflow: workflow, user: @user, purpose: "live", status: "active",
                     started_at: 2.hours.ago, execution_path: [], results: {}, inputs: {})
    sign_in @admin

    get admin_user_path(@user)

    assert_response :success
    assert_select "h1", text: @user.email
    assert_select "a.page-back[href=?]", admin_users_path
    assert_select "#user-workflows-owned", text: "2"
    assert_select "#user-last-active", text: /ago/
    assert_select "form[action=?] [data-controller=group-picker] input[value=?][checked]",
                  update_groups_admin_user_path(@user), group.id.to_s
    assert_select "form[action=?] select[name=role]", update_role_admin_user_path(@user)
    assert_select "form[action=?]", deactivate_admin_user_path(@user)
    assert_select "[data-controller~=password-reset][data-password-reset-url-value=?] dialog.dialog",
                  reset_password_admin_user_path(@user)
  end

  test "the user page labels a deactivated account apart from a locked-out one" do
    @user.deactivate!
    @editor.lock_access!(send_instructions: false)
    sign_in @admin

    get admin_user_path(@user)
    assert_select ".badge--alert", text: "Deactivated"
    assert_select "form[action=?]", reactivate_admin_user_path(@user)

    get admin_user_path(@editor)
    assert_select ".badge--warning", text: "Locked out"
    assert_select ".badge--alert", text: "Deactivated", count: 0
  end

  test "your own page offers no role change, password reset or deactivation" do
    sign_in @admin
    get admin_user_path(@admin)

    assert_response :success
    assert_select "select[name=role]", 0
    assert_select "[data-controller~=password-reset]", 0
    assert_select "form[action=?]", deactivate_admin_user_path(@admin), 0
    assert_select ".form-hint", text: /Another administrator/
  end

  test "a non-admin cannot open a user page" do
    sign_in @editor
    get admin_user_path(@user)

    assert_redirected_to root_path
  end

  test "saving groups, deactivating and reactivating return to the user page" do
    sign_in @admin

    patch update_groups_admin_user_path(@user), params: { group_ids: [] }
    assert_redirected_to admin_user_path(@user)

    patch deactivate_admin_user_path(@user)
    assert_redirected_to admin_user_path(@user)

    patch reactivate_admin_user_path(@user)
    assert_redirected_to admin_user_path(@user)
  end

  test "a role change returns to the page it was made on" do
    sign_in @admin

    patch update_role_admin_user_path(@user), params: { role: "editor" },
                                              headers: { "HTTP_REFERER" => admin_user_url(@user) }
    assert_redirected_to admin_user_url(@user)

    patch update_role_admin_user_path(@user), params: { role: "regular" }
    assert_redirected_to admin_users_path
  end
end
