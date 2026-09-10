require "test_helper"

# Members are managed on the group page (spec Q15): a search that stays open,
# Add per result, direct members only, and Remove with no confirm, the flash
# naming who was removed.
class Admin::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "members-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    sign_in @admin
    @tag = SecureRandom.hex(4)
    @group = Group.create!(name: "Members Team #{@tag}")
    @ada = person("ada", display_name: "Ada Lovelace")
    @bob = person("bob")
  end

  test "the search finds people by email or name, leaving out members and deactivated accounts" do
    UserGroup.create!(user: @bob, group: @group)
    person("gone").deactivate!

    get admin_group_memberships_path(@group, q: @tag)

    assert_response :success
    found = css_select("turbo-frame#group-member-search .admin-group__item .admin-group__name").map { it.text.strip }
    assert_equal [@ada.email], found

    get admin_group_memberships_path(@group, q: "Lovelace")

    assert_select "turbo-frame#group-member-search .admin-group__name", text: @ada.email
  end

  test "Add streams the member in, keeps the search open for the same words, and names them" do
    post admin_group_memberships_path(@group), params: { user_id: @ada.id, q: @tag }, as: :turbo_stream

    assert_response :success
    assert UserGroup.exists?(user: @ada, group: @group)

    members = stream_content("group-members", action: "replace")
    listed = members.css("section > .card__body > .admin-group__list .admin-group__name").map { it.text.strip }
    offered = members.css("turbo-frame#group-member-search .admin-group__name").map { it.text.strip }
    assert_equal [@ada.email], listed
    assert_equal @tag, members.at_css("input[name=q]")["value"]
    assert_equal [@bob.email], offered
    assert_match "Added #{@ada.email} to #{@group.name}.", stream_content("flash", action: "update").text
  end

  # The field sits outside the frame it fills, so an answer never replaces the
  # input someone is typing in (spec Q63).
  test "the search field sits outside its results and submits into them as you type" do
    get admin_group_path(@group)

    assert_select "#group-members form[data-turbo-frame=group-member-search][data-controller=debounced-submit] " \
                  "input[name=q][data-action=?]", "input->debounced-submit#submit"
    assert_select "turbo-frame#group-member-search input[name=q]", 0
  end

  test "Add without Turbo returns to the group page with the flash" do
    post admin_group_memberships_path(@group), params: { user_id: @ada.id }

    assert_redirected_to admin_group_path(@group)
    follow_redirect!
    assert_select "#flash .flash__text", text: "Added #{@ada.email} to #{@group.name}."
  end

  test "Remove needs no confirm, and the flash names who was removed" do
    membership = UserGroup.create!(user: @bob, group: @group)

    get admin_group_path(@group)

    assert_select "#group-members form[action=?]", admin_group_membership_path(@group, membership)
    assert_select "#group-members [data-turbo-confirm]", 0

    delete admin_group_membership_path(@group, membership), as: :turbo_stream

    assert_not UserGroup.exists?(membership.id)
    assert_match "Removed #{@bob.email} from #{@group.name}.", stream_content("flash", action: "update").text
  end

  test "the page lists direct members, and names access through parent groups" do
    parent = Group.create!(name: "Members Parent #{@tag}")
    child = Group.create!(name: "Members Child", parent:)
    UserGroup.create!(user: @ada, group: parent)
    UserGroup.create!(user: @bob, group: child)

    get admin_group_path(child)

    names = css_select("#group-members > .card__body > .admin-group__list .admin-group__name").map { it.text.strip }
    assert_equal [@bob.email], names
    assert_select "#group-members a[href=?]", admin_group_path(parent), text: "1 member of #{parent.name}"
  end

  test "Global takes no members: no card, and a hand-made request is refused with the reason" do
    global = global_group

    get admin_group_path(global)
    assert_select "#group-members", 0

    post admin_group_memberships_path(global), params: { user_id: @ada.id }

    assert_redirected_to admin_group_path(global)
    assert_match "Global has no members", flash[:alert]
    assert_not UserGroup.exists?(user: @ada, group: global)
  end

  test "only administrators manage members" do
    sign_out @admin
    sign_in person("editor", role: "editor")

    post admin_group_memberships_path(@group), params: { user_id: @ada.id }

    assert_redirected_to root_path
    assert_not UserGroup.exists?(user: @ada, group: @group)
  end

  private

  def person(label, role: "regular", display_name: nil)
    User.create!(email: "members-#{label}-#{@tag}@example.com", password: "password123!",
                 password_confirmation: "password123!", role:, display_name:)
  end

  # The markup a stream carries. Parsed from the template's inner HTML so the
  # assertion doesn't depend on how the HTML parser treats <template> content.
  def stream_content(target, action:)
    stream = css_select("turbo-stream[action=#{action}][target=#{target}]").first
    assert stream, "no #{action} stream for ##{target}"
    Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)
  end
end
