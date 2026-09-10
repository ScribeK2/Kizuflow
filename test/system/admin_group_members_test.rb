require "application_system_test_case"

# The stream responses land inside and around a turbo-frame, which only a browser
# proves: Add keeps the search open, and Remove asks nothing.
class AdminGroupMembersTest < ApplicationSystemTestCase
  MEMBER_ROWS = "#group-members > .card__body > .admin-group__list".freeze
  RESULTS = "turbo-frame#group-member-search".freeze

  setup do
    @tag = SecureRandom.hex(4)
    @admin = User.create!(email: "wf-system-test-members-admin-#{@tag}@example.com",
                          password: "password123!", password_confirmation: "password123!", role: "admin")
    @ada = User.create!(email: "wf-system-test-ada-#{@tag}@example.com",
                        password: "password123!", password_confirmation: "password123!", role: "regular")
    @bob = User.create!(email: "wf-system-test-bob-#{@tag}@example.com",
                        password: "password123!", password_confirmation: "password123!", role: "regular")
    @group = Group.create!(name: "wf-system-test-Members")
    sign_in_as @admin
  end

  teardown do
    Group.where("name LIKE ?", "wf-system-test-%").destroy_all
  end

  test "adding from the search keeps it open, and removing needs no confirm" do
    visit admin_group_path(@group)

    find("#group-members input[name=q]").set("#{@tag}@")
    assert_selector "#{RESULTS} .admin-group__name", text: @bob.email
    assert_equal "q", page.evaluate_script("document.activeElement.name"), "typing keeps the field focused"

    find("#{RESULTS} li", text: @ada.email).click_on("Add")

    assert_selector "#{MEMBER_ROWS} a", text: @ada.email
    assert_selector "#{RESULTS} .admin-group__name", text: @bob.email
    assert_no_selector "#{RESULTS} .admin-group__name", text: @ada.email
    assert_selector "#flash .flash", text: "Added #{@ada.email}"

    find("#{MEMBER_ROWS} li", text: @ada.email).click_on("Remove")

    assert_no_selector "#{MEMBER_ROWS} a", text: @ada.email
    assert_selector "#flash .flash", text: "Removed #{@ada.email}"
    assert_eventually { !UserGroup.exists?(user: @ada, group: @group) }
  end
end
