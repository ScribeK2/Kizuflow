require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 900] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
  end

  # System tests run with a separate Puma server thread that cannot see
  # records created inside an uncommitted transaction. Disable transactional
  # tests so records are committed and visible to the server.
  self.use_transactional_tests = false

  teardown do
    # Clean up records created during system tests to avoid cross-test pollution.
    # Tests create users with emails matching "builder-test-*" and "system-test-*".
    User.where("email LIKE ?", "wf-system-test-%").destroy_all
  end

  # Sign in via the login form (works with any Capybara driver)
  def sign_in_as(user, password: "password123")
    visit "/users/sign_in"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"
    # Wait for successful redirect away from sign-in page
    assert_no_current_path "/users/sign_in", wait: 5
  end
end
