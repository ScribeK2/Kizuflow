require "test_helper"

# The slim users table (Stage 3): a row is who, role, groups and joined, and
# everything else about a person lives on their page. Sorting, filtering, paging
# and the bulk actions are covered in users_controller_test.rb.
class Admin::UsersTableTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "table-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    @user = User.create!(email: "table-user-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                         password_confirmation: "password123!", role: "regular")
    sign_in @admin
  end

  test "each row links its email to the user page, outside the table's frame" do
    get admin_users_path(q: @user.email)

    assert_select "tbody a.admin-users__email[href=?][data-turbo-frame=_top]", admin_user_path(@user),
                  text: @user.email
  end

  test "the table renders no per-row buttons or dialogs" do
    get admin_users_path

    assert_select "[id^=group-modal-]", 0
    assert_select "tbody button", 0
    assert_select "tbody form[action$=deactivate]", 0
    assert_select "[data-admin-users-target=resetModal]", 0
  end

  test "a row shows two group names, then a count whose title lists every path" do
    parent = Group.create!(name: "Row Parent #{SecureRandom.hex(3)}")
    groups = %w[Alpha Beta Gamma].map { Group.create!(name: it, parent: parent) }
    groups.each { UserGroup.create!(user: @user, group: it) }

    get admin_users_path(q: @user.email)

    row = css_select("tbody tr:has(a[href='#{admin_user_path(@user)}'])").first
    assert row, "no row for #{@user.email}"
    shown = row.css(".admin-users__group").map { it.text.strip }
    assert_equal %w[Alpha Beta], shown
    more = row.css(".admin-users__more").first
    assert_equal "+1", more.text.strip
    groups.each { assert_includes more["title"], "#{parent.name} / #{it.name}" }
  end

  test "the bulk dialogs are native dialogs, and assigning groups uses the path-aware picker" do
    parent = Group.create!(name: "Bulk Parent #{SecureRandom.hex(3)}")
    child = Group.create!(name: "Bulk Child", parent: parent)

    get admin_users_path

    assert_select ".dialog-overlay", 0
    assert_select "dialog.dialog[data-admin-users-target=roleModal] form[action=?]", bulk_update_role_admin_users_path
    assert_select "dialog.dialog[data-admin-users-target=bulkModal] form[action=?] [data-controller=group-picker]",
                  bulk_assign_groups_admin_users_path
    assert_select "dialog[data-admin-users-target=bulkModal] input[name='group_ids[]'][value=?]", child.id.to_s
    assert_select "dialog[data-admin-users-target=bulkModal] .group-picker__path", text: "#{parent.name} / Bulk Child"
  end
end
