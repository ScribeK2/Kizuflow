require "test_helper"

class AdminGroupPickerPartialTest < ActionView::TestCase
  test "every group is a checkbox named by the caller, with its path, and the selected ones checked" do
    root = Group.create!(name: "Pick Root #{SecureRandom.hex(3)}")
    child = Group.create!(name: "Pick Child", parent: root)

    render partial: "admin/group_picker",
           locals: { nodes: Group.tree_nodes, field_name: "group_ids[]", selected_ids: [child.id] }

    assert_select "[data-controller=group-picker] input[data-group-picker-target=filter]"
    assert_select "input[type=checkbox][name=?][value=?]", "group_ids[]", root.id.to_s
    assert_select "input[type=checkbox][value=?][checked]", child.id.to_s
    assert_select "input[type=checkbox][value=?][checked]", root.id.to_s, count: 0
    assert_select "li[data-path=?] .group-picker__path", "#{root.name} / Pick Child".downcase,
                  text: "#{root.name} / Pick Child"
    assert_select "li[data-path=?] .group-picker__path", root.name.downcase, count: 0
  end

  test "with no groups it says where to make one" do
    render partial: "admin/group_picker", locals: { nodes: [], field_name: "group_ids[]" }

    assert_select "input[type=checkbox]", 0
    assert_select ".form-hint", text: /No groups yet/
  end
end
