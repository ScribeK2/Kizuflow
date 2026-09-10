require "test_helper"

# The groups index is a tree that will hold hundreds of department groups
# (spec Q10, Q34, Q35): flat rows from one query, roots showing, counts that
# match their links, and no per-row buttons.
class Admin::GroupsTreeTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "tree-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    sign_in @admin
    @root = Group.create!(name: "Tree Root #{SecureRandom.hex(3)}")
    @child = Group.create!(name: "Tree Child", parent: @root)
  end

  test "every group is a row carrying its ancestors and path; only roots show at first" do
    grandchild = Group.create!(name: "Tree Grandchild", parent: @child)

    get admin_groups_path

    assert_response :success
    root_row, child_row, grand_row = [@root, @child, grandchild].map { row_for(it) }
    assert_equal "", root_row["data-ancestors"]
    assert_equal "#{@root.id} #{@child.id}", grand_row["data-ancestors"]
    assert_equal "#{@root.name} / Tree Child / Tree Grandchild".downcase, grand_row["data-path"]
    assert_not_includes root_row["class"], "is-hidden"
    assert_includes child_row["class"], "is-hidden"
    assert_includes grand_row["class"], "is-hidden"
    assert_not_empty root_row.css("button.group-tree__toggle[aria-expanded=false]")
    assert_empty grand_row.css("button.group-tree__toggle")
  end

  test "Global comes first, then names ignoring case, whatever the old positions say" do
    global = global_group
    zebra = Group.create!(name: "Zebra #{SecureRandom.hex(3)}", position: 0)
    aardvark = Group.create!(name: "aardvark #{SecureRandom.hex(3)}", position: 99)

    get admin_groups_path

    ids = css_select("li.group-tree__row").map { it["data-id"].to_i }
    assert_equal global.id, ids.first
    assert_operator ids.index(aardvark.id), :<, ids.index(zebra.id)
  end

  test "rows count direct members and workflows including subgroups; Global counts everyone" do
    global = global_group
    member = User.create!(email: "tree-member-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "regular")
    UserGroup.create!(user: member, group: @child)
    workflow = Workflow.create!(title: "Tree WF", user: @admin)
    GroupWorkflow.create!(group: @child, workflow:, is_primary: true)

    get admin_groups_path

    assert_equal ["0 members", "1 workflow"], counts_in(row_for(@root))
    assert_equal ["1 member", "1 workflow"], counts_in(row_for(@child))
    assert_equal "Everyone signed in", counts_in(row_for(global)).first
  end

  test "rows carry a link to the group page and no action buttons" do
    get admin_groups_path

    assert_select "li.group-tree__row a[href=?]", admin_group_path(@root), text: @root.name
    assert_select "li.group-tree__row a[href=?]", edit_admin_group_path(@root), 0
    assert_select "li.group-tree__row [data-turbo-method=delete]", 0
    assert_select "li.group-tree__row form", 0
  end

  test "the page runs as many queries with 30 groups as with 3" do
    get admin_groups_path # warm per-process caches
    few = count_queries { get admin_groups_path }
    27.times { |i| Group.create!(name: "Tree Bulk #{i}", parent: i.even? ? @root : @child) }
    many = count_queries { get admin_groups_path }

    assert_equal few, many
  end

  private

  def row_for(group)
    css_select("li.group-tree__row[data-id='#{group.id}']").first
  end

  def counts_in(row)
    row.css(".group-tree__count").map { it.text.strip }
  end
end
