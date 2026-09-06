require "test_helper"

class NavControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :workflows

  def setup
    @admin = users(:admin_user)
    @editor = users(:editor_user)
    @regular = users(:regular_user)
  end

  # --- menu action ---

  test "menu requires authentication" do
    get nav_menu_path
    assert_redirected_to new_user_session_path
  end

  test "menu renders turbo frame for admin" do
    sign_in @admin
    get nav_menu_path
    assert_response :success
    assert_select "turbo-frame#nav_menu"
  end

  test "admin menu includes admin section" do
    sign_in @admin
    get nav_menu_path
    assert_response :success
    assert_select "a[href='#{admin_users_path}']"
    assert_select "a[href='#{admin_workflows_path}']"
    assert_select "a[href='#{admin_groups_path}']"
    assert_select "a[href='#{admin_analytics_path}']"
  end

  test "admin menu includes actions section" do
    sign_in @admin
    get nav_menu_path
    assert_select "a[href='#{new_workflow_path}']"
  end

  test "editor menu includes actions but not admin" do
    sign_in @editor
    get nav_menu_path
    assert_response :success
    assert_select "a[href='#{new_workflow_path}']"
    assert_select "a[href='#{admin_users_path}']", count: 0
  end

  test "regular user menu has navigation only" do
    sign_in @regular
    get nav_menu_path
    assert_response :success
    assert_select "a[href='#{root_path}']"
    assert_select "a[href='#{workflows_path}']"
    assert_select "a[href='#{new_workflow_path}']", count: 0
    assert_select "a[href='#{admin_users_path}']", count: 0
  end

  # --- search_data action ---

  test "search_data requires authentication" do
    get nav_search_data_path(format: :json)
    assert_response :unauthorized
  end

  test "search_data returns JSON array of workflows" do
    sign_in @admin
    Workflow.create!(title: "Test Flow", user: @admin, status: "draft")
    Workflow.create!(title: "Draft Flow", user: @admin, status: "draft")

    get nav_search_data_path(format: :json)
    assert_response :success

    data = response.parsed_body
    assert_kind_of Array, data
    assert_operator data.length, :>=, 2, "Expected at least 2 workflows"

    first = data.first
    assert first.key?("id")
    assert first.key?("title")
    assert first.key?("description")
    assert first.key?("status")
    assert first.key?("path")
  end

  test "search_data scopes workflows to user access" do
    other_user = users(:one)
    Workflow.create!(title: "Public Flow", user: other_user, status: "published", is_public: true)
    Workflow.create!(title: "Private Flow", user: other_user, status: "draft", is_public: false)
    Workflow.create!(title: "My Flow", user: @regular, status: "draft")

    sign_in @regular
    get nav_search_data_path(format: :json)

    data = response.parsed_body
    titles = data.pluck("title")
    assert_includes titles, "Public Flow"
    assert_includes titles, "My Flow"
    assert_not_includes titles, "Private Flow"
  end

  # A regular user cannot open the builder or the execution landing page, so
  # every search result used to resolve to the bare Player index: twelve
  # workflows, one destination, and no sign the app had heard which one you
  # picked. Confirmed live during the role pass —
  # {"count": 12, "distinctPaths": ["/play"]}.
  test "a regular user's search results name the workflow they picked" do
    regular = User.create!(email: "nav-reg-#{SecureRandom.hex(4)}@example.com",
                           password: "password123!", password_confirmation: "password123!")
    group = Group.create!(name: "Nav Group #{SecureRandom.hex(3)}")
    regular.user_groups.create!(group: group)
    owner = User.create!(email: "nav-own-#{SecureRandom.hex(4)}@example.com",
                         password: "password123!", password_confirmation: "password123!", role: "editor")
    a = Workflow.create!(title: "Alpha Flow #{SecureRandom.hex(3)}", user: owner, status: "published")
    b = Workflow.create!(title: "Beta Flow #{SecureRandom.hex(3)}", user: owner, status: "published")
    [a, b].each { |w| w.groups << group }

    sign_in regular
    get nav_search_data_path, as: :json

    assert_response :success
    rows = response.parsed_body.select { |r| [a.title, b.title].include?(r["title"]) }

    assert_equal 2, rows.size, "precondition: both workflows are visible to this user"
    assert_equal 2, rows.pluck("path").uniq.size,
                 "two different workflows must not resolve to one destination"
    rows.each do |row|
      assert_includes row["path"], "/play"
      assert_includes CGI.unescape(row["path"]), row["title"],
                      "the result has to carry the workflow it names"
    end
  end
end
