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
end
