require "test_helper"

# The tree and the group page print these numbers beside links, so each is
# tested as equal to what its link lists (spec Q34), not merely as a number.
class GroupCountsTest < ActiveSupport::TestCase
  setup do
    @owner = User.create!(email: "counts-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "editor")
    @root = Group.create!(name: "Counts Root #{SecureRandom.hex(3)}")
    @child = Group.create!(name: "Counts Child", parent: @root)
    @grandchild = Group.create!(name: "Counts Grandchild", parent: @child)
  end

  test "member counts are direct, and match the Users filter" do
    UserGroup.create!(user: person("a"), group: @root)
    2.times { |i| UserGroup.create!(user: person("c#{i}"), group: @child) }

    counts = Group.member_counts

    assert_equal 1, counts[@root.id]
    assert_equal 2, counts[@child.id]
    assert_nil counts[@grandchild.id]
    [@root, @child].each { assert_equal User.by_group(it.id).count, counts[it.id] }
  end

  test "workflow counts include subgroups, once each, and match /workflows?group_id=" do
    workflow_in(@grandchild)
    workflow_in(@child, @grandchild) # filed twice in one subtree: counted once
    workflow_in(@root)

    counts = Group.workflow_counts_including_subgroups

    assert_equal 3, counts[@root.id]
    assert_equal 2, counts[@child.id]
    assert_equal 2, counts[@grandchild.id]
    [@root, @child, @grandchild].each { assert_equal Workflow.in_group(it).count, counts[it.id] }
  end

  test "a group can't sit under itself, its subgroups or Global" do
    global = global_group
    sibling = Group.create!(name: "Counts Sibling", parent: @root)

    options = Group.parent_options_for(@child)
    ids = options.map(&:id)

    assert_not_includes ids, @child.id
    assert_not_includes ids, @grandchild.id
    assert_not_includes ids, global.id
    assert_includes ids, @root.id
    assert_equal "#{@root.name} / Counts Sibling", options.find { it.id == sibling.id }.path
  end

  test "a new group may sit under any group but Global" do
    global = global_group

    ids = Group.parent_options_for(Group.new).map(&:id)

    assert_includes ids, @grandchild.id
    assert_not_includes ids, global.id
  end

  private

  def person(label)
    User.create!(email: "counts-#{label}-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                 password_confirmation: "password123!", role: "regular")
  end

  def workflow_in(*groups)
    workflow = Workflow.create!(title: "Counts WF #{SecureRandom.hex(3)}", user: @owner)
    groups.each_with_index { |group, i| GroupWorkflow.create!(group:, workflow:, is_primary: i.zero?) }
    workflow
  end
end
