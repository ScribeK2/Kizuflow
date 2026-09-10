require "test_helper"

# Global replaced Uncategorized. Everyone signed in sees what is filed there, so
# it is a fixed point: nobody renames it, moves it, deletes it or joins it.
class GlobalGroupTest < ActiveSupport::TestCase
  setup do
    @global = global_group
  end

  test "only the root group named Global is Global" do
    parent = Group.create!(name: "Global Parent #{SecureRandom.hex(3)}")
    nested = Group.create!(name: Group::GLOBAL_NAME, parent: parent)

    assert_predicate @global, :global?
    assert_not nested.global?
    assert_equal @global.id, Group.global_id
  end

  test "looking Global up never creates it" do
    user = create_user("regular")
    Group.where(id: @global.id).delete_all

    assert_no_difference -> { Group.count } do
      assert_nil Group.global_id
      assert_equal [], Group.reachable_ids_for(user)
    end
  end

  test "Global cannot be renamed" do
    assert_not @global.update(name: "Everyone")
    assert_equal Group::GLOBAL_NAME, @global.reload.name
  end

  test "Global cannot be moved under another group" do
    parent = Group.create!(name: "Mover #{SecureRandom.hex(3)}")

    assert_not @global.update(parent: parent)
    assert_nil @global.reload.parent_id
  end

  test "Global cannot be deleted" do
    assert_not @global.destroy
    assert Group.exists?(@global.id)
    assert_includes @global.errors[:base], "Global can't be deleted"
  end

  test "nothing nests under Global" do
    child = Group.new(name: "Under Global", parent: @global)

    assert_not child.valid?
    assert_includes child.errors[:parent_id], "can't be Global — Global has no subgroups"
  end

  test "nobody joins Global" do
    membership = UserGroup.new(user: create_user("regular"), group: @global)

    assert_not membership.valid?
  end

  test "every signed-in user can open Global" do
    assert @global.can_be_viewed_by?(create_user("regular"))
    assert_not @global.can_be_viewed_by?(nil)
  end

  test "a person reaches their groups, those groups' subgroups, and Global" do
    user = create_user("regular")
    parent = Group.create!(name: "Reach Parent #{SecureRandom.hex(3)}")
    child = Group.create!(name: "Reach Child", parent: parent)
    Group.create!(name: "Unreached #{SecureRandom.hex(3)}")
    UserGroup.create!(user: user, group: parent)

    assert_equal [parent.id, child.id, @global.id].sort, Group.reachable_ids_for(user).sort
  end

  test "a person with no groups still reaches Global" do
    assert_equal [@global.id], Group.reachable_ids_for(create_user("regular"))
  end

  test "a workflow created without groups is filed nowhere" do
    workflow = Workflow.create!(title: "Nobody Chosen", user: create_user("editor"))

    assert_empty workflow.groups
  end

  test "membership pickers never offer Global" do
    assert_not_includes Group.assignable_tree_nodes.map(&:id), @global.id
    assert_includes Group.tree_nodes.map(&:id), @global.id
  end

  private

  def create_user(role)
    User.create!(email: "global-#{role}-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                 password_confirmation: "password123!", role: role)
  end
end
