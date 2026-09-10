require "application_system_test_case"

# The admin Users screens move their dialogs onto native <dialog> + showModal(),
# which only a real browser can prove opens, closes and carries its result.
class AdminUsersTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(email: "wf-system-test-admin-#{SecureRandom.hex(4)}@example.com",
                          password: "password123!", password_confirmation: "password123!", role: "admin")
    @agent = User.create!(email: "wf-system-test-agent-#{SecureRandom.hex(4)}@example.com",
                          password: "password123!", password_confirmation: "password123!", role: "regular")
    sign_in_as @admin
  end

  teardown do
    Group.where("name LIKE ?", "wf-system-test-%").destroy_all
  end

  test "resetting a password confirms first, then shows the temporary password once" do
    visit admin_user_path(@agent)

    click_on "Reset password"
    assert_selector "dialog[open]", wait: 3
    assert_text "Generate a temporary password for"

    click_on "Generate password"
    assert_selector "[data-password-reset-target=password]", text: /\A[a-zA-Z0-9]{16}\z/, wait: 5

    click_on "Done"
    assert_no_selector "dialog[open]"
  end

  # Turbo snapshots the page as you leave it, and a modal does not stop every way
  # of leaving — a scripted visit (the session-timeout redirect) or history.back().
  # Without turbo:before-cache handling the snapshot holds the open dialog, restored
  # on Forward as a bare <dialog open> with no backdrop, and the password shown in it.
  #
  # history.back() runs in the page on purpose: Capybara's go_back goes through
  # WebDriver, and on that path Chrome closes the modal itself, so the test passed
  # with the fix removed.
  test "leaving with the dialog open caches neither the open dialog nor the password" do
    visit admin_users_path
    # A Turbo visit, not a page load: only Turbo's own history restores from its cache.
    execute_script("Turbo.visit(#{admin_user_path(@agent).to_json})")
    assert_selector "h1", text: @agent.email, wait: 5

    click_on "Reset password"
    click_on "Generate password"
    assert_selector "[data-password-reset-target=password]", text: /\A[a-zA-Z0-9]{16}\z/, wait: 5

    execute_script("history.back()")
    # Wait for the index to render, not just the URL: popstate changes the URL
    # before Turbo has cached the page being left, and Forward with nothing
    # cached fetches a fresh page — which would pass with the fix removed.
    assert_selector "turbo-frame#users-table", wait: 5
    execute_script("history.forward()")
    assert_selector "h1", text: @agent.email, wait: 5

    assert_no_selector "dialog[open]"
    assert_equal "", find("[data-password-reset-target=password]", visible: :all).text(:all)
  end
end
