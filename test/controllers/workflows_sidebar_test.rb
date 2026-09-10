require "test_helper"

# Spec Q38. The sidebar listed root groups only, so an editor assigned to a
# subgroup — the normal case once groups mirror departments — had an empty one.
class WorkflowsSidebarTest < ActionDispatch::IntegrationTest
  setup do
    @editor = User.create!(email: "sidebar-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
    @department = Group.create!(name: "Department #{SecureRandom.hex(3)}")
    @team = Group.create!(name: "Team", parent: @department)
    UserGroup.create!(user: @editor, group: @team)
    sign_in @editor
  end

  test "an editor in a subgroup finds that subgroup in the sidebar, under Global" do
    global_group

    get workflows_path

    names = css_select(".group-sidebar__nav-list > li.group-sidebar-item > div a.group-sidebar__link span.flex-1")
            .map { it.text.strip }
    assert_equal [Group::GLOBAL_NAME, "Team"], names
  end

  test "the breadcrumb names a parent group the editor cannot open, without linking it" do
    get workflows_path(group_id: @team.id)

    assert_select ".wf-breadcrumb a", text: @department.name, count: 0
    assert_select ".wf-breadcrumb span", text: @department.name
  end

  test "an admin's breadcrumb still links every parent" do
    admin = User.create!(email: "sidebar-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                         password_confirmation: "password123!", role: "admin")
    sign_in admin

    get workflows_path(group_id: @team.id)

    assert_select ".wf-breadcrumb a[href=?]", workflows_path(group_id: @department.id)
  end
end
