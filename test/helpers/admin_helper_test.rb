require "test_helper"

class AdminHelperTest < ActionView::TestCase
  include AdminHelper

  # admin_section reads controller_path, which ActionView::TestCase does not set.
  # Each test declares the page it is standing on (same idiom as NavHelperTest).
  attr_accessor :controller_path

  test "each admin controller lights its own section" do
    {
      "admin/dashboard" => :overview,
      "admin/users" => :users,
      "admin/groups" => :groups,
      "admin/analytics" => :analytics,
      "admin/data_health" => :data_health,
      "admin/smtp_settings" => :email
    }.each do |path, section|
      self.controller_path = path
      assert_equal section, admin_section, path
    end
  end

  test "folders light Groups, because a folder belongs to a group" do
    self.controller_path = "admin/folders"
    assert_equal :groups, admin_section
  end

  test "admin_nav_current marks only the current section" do
    self.controller_path = "admin/users"
    assert_equal "page", admin_nav_current(:users)
    assert_nil admin_nav_current(:groups)
  end

  test "a controller outside the map lights nothing" do
    self.controller_path = "workflows"
    assert_nil admin_section
  end

  test "admin_group_trail runs from Groups through every ancestor, root first" do
    root = Group.create!(name: "Trail Root #{SecureRandom.hex(3)}")
    mid = Group.create!(name: "Trail Mid", parent: root)
    leaf = Group.create!(name: "Trail Leaf", parent: mid)

    assert_equal [["Groups", admin_groups_path], [root.name, admin_group_path(root)], ["Trail Mid", admin_group_path(mid)]],
                 admin_group_trail(leaf)
    assert_equal ["Trail Leaf", admin_group_path(leaf)], admin_group_trail(leaf, include_self: true).last
    assert_equal [["Groups", admin_groups_path]], admin_group_trail(nil)
  end

  test "admin_group_trail keeps the saved name while an edit is invalid" do
    group = Group.create!(name: "Saved Name #{SecureRandom.hex(3)}")
    saved = group.name
    group.name = ""

    assert_equal saved, admin_group_trail(group, include_self: true).last.first
  end
end
