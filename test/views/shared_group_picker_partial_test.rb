require "test_helper"

class SharedGroupPickerPartialTest < ActionView::TestCase
  test "every group is a checkbox named by the caller, with its path, and the selected ones checked" do
    root = Group.create!(name: "Pick Root #{SecureRandom.hex(3)}")
    child = Group.create!(name: "Pick Child", parent: root)

    render partial: "shared/group_picker",
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
    render partial: "shared/group_picker", locals: { nodes: [], field_name: "group_ids[]" }

    assert_select "input[type=checkbox]", 0
    assert_select ".form-hint", text: /No groups yet/
  end

  # Spec Q50: Global is the answer "everyone", so it sits above the list and
  # outside the filter rather than as one department among the rest.
  test "Global gets its own row outside the filtered list" do
    global = global_group
    department = Group.create!(name: "Pick Department #{SecureRandom.hex(3)}")

    render partial: "shared/group_picker", locals: { nodes: Group.tree_nodes, field_name: "group_ids[]" }

    assert_select ".group-picker__global input[type=checkbox][value=?]", global.id.to_s
    assert_select ".group-picker__global .group-picker__hint", text: "Everyone signed in"
    assert_select "li[data-group-picker-target=option] input[value=?]", global.id.to_s, count: 0
    assert_select "li[data-group-picker-target=option] input[value=?]", department.id.to_s
  end

  test "input_data lands on every checkbox" do
    global_group
    Group.create!(name: "Pick Data #{SecureRandom.hex(3)}")

    render partial: "shared/group_picker",
           locals: { nodes: Group.tree_nodes, field_name: "group_ids[]", input_data: { action: "change->x#y" } }

    assert_select "input[type=checkbox]", minimum: 2
    assert_select "input[type=checkbox]:not([data-action='change->x#y'])", 0
  end
end
