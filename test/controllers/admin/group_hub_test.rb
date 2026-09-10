require "test_helper"

# A group's page is where its department is run (spec Q9, Q16, Q39): what's in
# it counted, not listed, its subgroups by name, and a delete that says what it
# takes with it — or why it can't happen yet.
class Admin::GroupHubTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "hub-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    sign_in @admin
    @dept = Group.create!(name: "Hub Dept #{SecureRandom.hex(3)}")
  end

  test "the header counts workflows including subgroups and links to them in Workflows" do
    team = Group.create!(name: "Hub Team", parent: @dept)
    GroupWorkflow.create!(group: team, workflow: Workflow.create!(title: "Hub Filed WF", user: @admin), is_primary: true)

    get admin_group_path(@dept)

    assert_select ".page-header-section__ident", text: /1 workflow, including subgroups/
    assert_select ".page-header-section__ident a[href=?]", workflows_path(group_id: @dept.id), text: "View in Workflows"
    assert_no_match "Hub Filed WF", response.body, "the page counts workflows; it doesn't list them (Q16)"
    assert_select "a[href=?]", edit_admin_group_path(@dept), text: "Edit Group"
  end

  test "subgroups list by name ignoring case, with their counts" do
    Group.create!(name: "Zulu", parent: @dept)
    alpha = Group.create!(name: "alpha", parent: @dept)
    UserGroup.create!(user: person, group: alpha)

    get admin_group_path(@dept)

    rows = css_select("section[aria-labelledby=group-subgroups-heading] .admin-group__item")
    names = rows.map { it.css(".admin-group__name").text.strip }
    assert_equal %w[alpha Zulu], names
    assert_match(/1 member\s+·\s+0 workflows/, rows.first.text)
    assert_select "a[href=?]", new_admin_group_path(parent_id: @dept.id), text: /Add Subgroup/
  end

  test "a group at the depth limit hides Add Subgroup and says why" do
    chain = [@dept]
    4.times { |i| chain << Group.create!(name: "Hub Level #{i + 2}", parent: chain.last) }

    get admin_group_path(chain[4])

    assert_select "a[href=?]", new_admin_group_path(parent_id: chain[4].id), 0
    assert_select "section[aria-labelledby=group-subgroups-heading] .form-hint",
                  text: "Groups nest up to 5 levels; this one is at the limit."

    get admin_group_path(chain[3])

    assert_select "a[href=?]", new_admin_group_path(parent_id: chain[3].id), text: /Add Subgroup/
  end

  test "an empty group offers Delete, and the confirm names its members and folders" do
    UserGroup.create!(user: person, group: @dept)
    2.times { |i| Folder.create!(name: "Hub Folder #{i}", group: @dept) }

    get admin_group_path(@dept)

    form = css_select("section[aria-labelledby=group-danger-heading] form[action='#{admin_group_path(@dept)}']").first
    assert form, "no delete form"
    assert_equal "Delete #{@dept.name}? Its 1 member loses the access it gives, " \
                 "and its 2 folders are deleted. This can't be undone.", form["data-turbo-confirm"]
  end

  test "a group still holding subgroups or workflows says why instead of offering Delete" do
    Group.create!(name: "Hub Sub", parent: @dept)
    GroupWorkflow.create!(group: @dept, workflow: Workflow.create!(title: "Hub Held", user: @admin), is_primary: true)

    get admin_group_path(@dept)

    assert_select "section[aria-labelledby=group-danger-heading]", text: /It still holds 1 subgroup and 1 workflow/
    assert_select "section[aria-labelledby=group-danger-heading] form", 0
  end

  test "Global's page offers no edit, subgroups or delete, and says why" do
    global = global_group

    get admin_group_path(global)

    assert_response :success
    assert_select "a[href=?]", edit_admin_group_path(global), 0
    assert_select "section[aria-labelledby=group-subgroups-heading]", 0
    assert_select "section[aria-labelledby=group-danger-heading]", 0
    assert_match "It can't be renamed, moved or deleted", response.body
    assert_select ".page-header-section__ident", text: /\A\s*0 workflows ·/, message: "Global has no subgroups to include"
  end

  test "a refused delete returns to the group's page" do
    Group.create!(name: "Hub Sub", parent: @dept)

    assert_no_difference("Group.count") { delete admin_group_path(@dept) }

    assert_redirected_to admin_group_path(@dept)
  end

  test "the page runs as many queries with 8 subgroups as with 1" do
    Group.create!(name: "Hub Q 0", parent: @dept)
    get admin_group_path(@dept)
    few = count_queries { get admin_group_path(@dept) }
    7.times { |i| Group.create!(name: "Hub Q #{i + 1}", parent: @dept) }
    many = count_queries { get admin_group_path(@dept) }

    assert_equal few, many
  end

  private

  def person
    User.create!(email: "hub-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                 password_confirmation: "password123!", role: "regular")
  end
end
