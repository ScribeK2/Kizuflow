require "test_helper"

# New and edit share one form (spec Q40). Its Parent select names groups by full
# path, never a bare "Support", and offers nowhere the save would refuse.
class Admin::GroupFormTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "form-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    sign_in @admin
    @dept = Group.create!(name: "Form Dept #{SecureRandom.hex(3)}")
    @team = Group.create!(name: "Form Team", parent: @dept)
    @tier = Group.create!(name: "Form Tier", parent: @team)
  end

  test "the parent select lists full paths and leaves out the group, its subgroups and Global" do
    global = global_group
    other = Group.create!(name: "Form Other", parent: @dept)

    get edit_admin_group_path(@team)

    options = css_select("select[name='group[parent_id]'] option")
    assert_equal "None — a top-level group", options.first.text.strip
    assert_includes options.map { it.text.strip }, "#{@dept.name} / Form Other"
    values = options.pluck("value")
    [@team, @tier, global].each { assert_not_includes values, it.id.to_s }
    assert_includes values, other.id.to_s
    assert_select "select[name='group[parent_id]'] option[selected][value=?]", @dept.id.to_s
  end

  test "the new subgroup form preselects its parent" do
    get new_admin_group_path(parent_id: @team.id)

    assert_select "select[name='group[parent_id]'] option[selected][value=?]", @team.id.to_s
  end

  test "neither form offers a position, and a posted position is ignored" do
    get new_admin_group_path
    assert_select "[name='group[position]']", 0
    get edit_admin_group_path(@team)
    assert_select "[name='group[position]']", 0

    patch admin_group_path(@team), params: { group: { name: "Form Team Renamed", position: 7 } }

    assert_redirected_to admin_group_path(@team)
    assert_equal "Form Team Renamed", @team.reload.name
    assert_nil @team.position
  end

  # shared/_error_messages renders a position: fixed .flash, which inside a form
  # card floats to the corner of the screen.
  test "a failed save lists its problems inside the form" do
    patch admin_group_path(@team), params: { group: { name: "" } }

    assert_response :unprocessable_content
    assert_select "form .admin-info-box[role=alert] li", text: /Name can't be blank/
    assert_select "form .flash", 0
  end

  test "creating a group opens its page" do
    name = "Form New #{SecureRandom.hex(3)}"

    post admin_groups_path, params: { group: { name:, parent_id: @dept.id } }

    assert_redirected_to admin_group_path(Group.find_by!(name:))
  end

  test "Global's edit page sends you back to Global" do
    global = global_group

    get edit_admin_group_path(global)

    assert_redirected_to admin_group_path(global)
    assert_equal "Global can't be renamed or moved.", flash[:alert]
  end
end
