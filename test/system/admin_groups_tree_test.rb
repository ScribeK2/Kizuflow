require "application_system_test_case"

# Showing, hiding and filtering happen in the browser, so only a browser can
# show the tree opens where the spec says it does (Q35).
class AdminGroupsTreeTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(email: "wf-system-test-tree-#{SecureRandom.hex(4)}@example.com",
                          password: "password123!", password_confirmation: "password123!", role: "admin")
    @dept = Group.create!(name: "wf-system-test-Dept")
    @team = Group.create!(name: "wf-system-test-Team", parent: @dept)
    @tier = Group.create!(name: "wf-system-test-Tier Two", parent: @team)
    sign_in_as @admin
  end

  teardown do
    Group.where("name LIKE ?", "wf-system-test-%").destroy_all
  end

  test "starts at the roots, and a toggle opens one level" do
    visit admin_groups_path

    assert_selector row(@dept)
    assert_no_selector row(@team)

    within(row(@dept)) { find("button.group-tree__toggle").click }

    assert_selector row(@team)
    assert_no_selector row(@tier)
  end

  test "the filter finds a deep group, shows its path and opens the groups above it" do
    visit admin_groups_path

    find("[data-group-tree-target=filter]").set("tier two")

    assert_selector row(@tier), text: "wf-system-test-Dept / wf-system-test-Team / wf-system-test-Tier Two"
    assert_selector row(@team)

    find("[data-group-tree-target=filter]").set("", clear: :backspace)

    assert_selector row(@tier), text: "wf-system-test-Tier Two"
    assert_no_selector "#{row(@tier)} .group-tree__path"
  end

  test "Expand All shows every row and Collapse All returns to the roots" do
    visit admin_groups_path

    click_on "Expand All"
    assert_selector row(@tier)

    click_on "Collapse All"
    assert_no_selector row(@team)
    assert_selector row(@dept)
  end

  private

  def row(group)
    "li.group-tree__row[data-id='#{group.id}']"
  end
end
