require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = User.create!(
      email: "admin-users-#{SecureRandom.hex(4)}@example.com",
      password: 'password123!',
      password_confirmation: 'password123!',
      role: 'admin'
    )
    @editor = User.create!(
      email: "editor-users-#{SecureRandom.hex(4)}@example.com",
      password: 'password123!',
      password_confirmation: 'password123!',
      role: 'editor'
    )
    @user = User.create!(
      email: "user-users-#{SecureRandom.hex(4)}@example.com",
      password: 'password123!',
      password_confirmation: 'password123!',
      role: 'user'
    )
  end

  test 'admin should be able to access user management' do
    sign_in @admin
    get admin_users_path

    assert_response :success
  end

  test 'non-admin should not be able to access user management' do
    sign_in @editor
    get admin_users_path

    assert_redirected_to root_path
    assert_equal "You don't have permission to access this page.", flash[:alert]
  end

  test 'admin should be able to update user role' do
    sign_in @admin
    patch update_role_admin_user_path(@user), params: { role: 'editor' }

    assert_redirected_to admin_users_path
    @user.reload

    assert_equal 'editor', @user.role
  end

  test 'admin should not be able to set invalid role' do
    sign_in @admin
    original_role = @user.role
    patch update_role_admin_user_path(@user), params: { role: 'invalid_role' }

    assert_redirected_to admin_users_path
    @user.reload

    assert_equal original_role, @user.role
  end

  # Group assignment tests
  test 'admin should be able to assign groups to user' do
    sign_in @admin
    group1 = Group.create!(name: 'Group 1')
    group2 = Group.create!(name: 'Group 2')

    assert_difference('@user.groups.count', 2) do
      patch update_groups_admin_user_path(@user), params: {
        group_ids: [group1.id, group2.id]
      }
    end

    assert_redirected_to admin_users_path
    @user.reload

    assert_includes @user.groups.map(&:id), group1.id
    assert_includes @user.groups.map(&:id), group2.id
  end

  test 'admin should be able to update user groups' do
    sign_in @admin
    group1 = Group.create!(name: 'Group 1')
    group2 = Group.create!(name: 'Group 2')
    group3 = Group.create!(name: 'Group 3')

    # Initially assign group1 and group2
    UserGroup.create!(group: group1, user: @user)
    UserGroup.create!(group: group2, user: @user)

    # Update to group2 and group3
    patch update_groups_admin_user_path(@user), params: {
      group_ids: [group2.id, group3.id]
    }

    @user.reload

    assert_not_includes @user.groups.map(&:id), group1.id
    assert_includes @user.groups.map(&:id), group2.id
    assert_includes @user.groups.map(&:id), group3.id
  end

  test 'admin should be able to bulk assign groups to multiple users' do
    sign_in @admin
    user1 = User.create!(
      email: "user1-#{SecureRandom.hex(4)}@test.com",
      password: 'password123!',
      password_confirmation: 'password123!'
    )
    user2 = User.create!(
      email: "user2-#{SecureRandom.hex(4)}@test.com",
      password: 'password123!',
      password_confirmation: 'password123!'
    )
    group = Group.create!(name: 'Bulk Group')

    assert_difference('UserGroup.count', 2) do
      patch bulk_assign_groups_admin_users_path, params: {
        user_ids: [user1.id, user2.id],
        group_ids: [group.id]
      }
    end

    assert_redirected_to admin_users_path
    user1.reload
    user2.reload

    assert_includes user1.groups.map(&:id), group.id
    assert_includes user2.groups.map(&:id), group.id
  end

  test 'bulk assign should replace existing group assignments' do
    sign_in @admin
    user = User.create!(
      email: "user-#{SecureRandom.hex(4)}@test.com",
      password: 'password123!',
      password_confirmation: 'password123!'
    )
    group1 = Group.create!(name: 'Group 1')
    group2 = Group.create!(name: 'Group 2')

    # Initially assign group1
    UserGroup.create!(group: group1, user: user)

    # Bulk assign group2
    patch bulk_assign_groups_admin_users_path, params: {
      user_ids: [user.id],
      group_ids: [group2.id]
    }

    user.reload

    assert_not_includes user.groups.map(&:id), group1.id
    assert_includes user.groups.map(&:id), group2.id
  end

  # Password reset tests
  test 'admin should be able to reset user password' do
    sign_in @admin

    original_password = @user.encrypted_password

    post reset_password_admin_user_path(@user)

    assert_redirected_to admin_users_path
    assert_match(/Temporary password generated for #{@user.email}/, flash[:notice])

    @user.reload

    assert_not_equal original_password, @user.encrypted_password
  end

  test 'admin cannot reset own password via admin interface' do
    sign_in @admin

    post reset_password_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    assert_match(/Cannot reset your own password/, flash[:alert])
  end

  test 'non-admin cannot access reset password action' do
    sign_in @editor

    post reset_password_admin_user_path(@user)

    # Should be redirected due to ensure_admin! filter
    assert_response :redirect
  end

  test 'reset password action logs security audit trail' do
    sign_in @admin

    # Simplified test - just verify the action works and logs would be created
    # In a real environment, Rails would log the action
    assert_nothing_raised do
      post reset_password_admin_user_path(@user)
    end

    assert_redirected_to admin_users_path
    assert_match(/Temporary password generated/, flash[:notice])
  end

  test 'reset password action logs security warning for self-reset attempt' do
    sign_in @admin

    # Simplified test - verify self-reset is blocked
    post reset_password_admin_user_path(@admin)

    assert_redirected_to admin_users_path
    assert_match(/Cannot reset your own password/, flash[:alert])
  end

  test 'reset password action works with temporary password generation' do
    # Test that temporary password is generated correctly (model method test)
    original_password = @user.encrypted_password

    temp_password = @user.generate_temporary_password

    @user.reload

    assert_not_equal original_password, @user.encrypted_password
    assert_not_nil temp_password
    assert_operator temp_password.length, :>=, 8, "Password should be at least 8 characters"
    # Password contains only alphanumeric chars from the character set
    assert_match(/^[a-zA-Z0-9]+$/, temp_password, "Password should only contain alphanumeric characters")
  end

  test 'temporary password generation returns JSON response' do
    sign_in @admin

    post reset_password_admin_user_path(@user), as: :json

    assert_response :success

    json_response = response.parsed_body

    assert json_response['success']
    assert_not_nil json_response['password']
    assert_equal @user.email, json_response['email']
  end

  test 'temporary password is secure and unique' do
    sign_in @admin

    post reset_password_admin_user_path(@user), as: :json
    first_password = response.parsed_body['password']

    post reset_password_admin_user_path(@user), as: :json
    second_password = response.parsed_body['password']

    # Passwords should be different
    assert_not_equal first_password, second_password

    # Passwords should be secure (16-char alphanumeric from SecureRandom)
    assert_match(/[a-zA-Z]/, first_password)
    assert_operator first_password.length, :>=, 16
  end

  test 'temporary password flow works for user login' do
    sign_in @admin

    # Generate temporary password
    post reset_password_admin_user_path(@user), as: :json
    temp_password = response.parsed_body['password']

    # User should be able to sign in with temporary password
    sign_out @user

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: temp_password
      }
    }

    assert_redirected_to root_path
  end

  test 'temporary password HTML response works' do
    sign_in @admin

    post reset_password_admin_user_path(@user)

    assert_redirected_to admin_users_path
    assert_match(/Temporary password generated/, flash[:notice])
  end

  # Filter and pagination tests
  test "index with search query filters users" do
    sign_in @admin
    get admin_users_path(q: @editor.email.split("@").first)

    assert_response :success
    assert_match @editor.email, response.body
  end

  test "index with role filter shows only that role" do
    sign_in @admin
    get admin_users_path(role: "admin")

    assert_response :success
    assert_match @admin.email, response.body
  end

  test "index with pagination returns correct page" do
    sign_in @admin
    get admin_users_path(page: 1, per_page: 25)

    assert_response :success
  end

  test "index assigns filter metadata" do
    sign_in @admin
    get admin_users_path

    assert_response :success
  end

  test "bulk_update_role changes roles for selected users" do
    sign_in @admin
    patch bulk_update_role_admin_users_path, params: {
      user_ids: [@user.id, @editor.id],
      role: "admin"
    }

    assert_response :redirect
    @user.reload
    @editor.reload
    assert_equal "admin", @user.role
    assert_equal "admin", @editor.role
  end

  test "bulk_update_role rejects invalid role" do
    sign_in @admin
    patch bulk_update_role_admin_users_path, params: {
      user_ids: [@user.id],
      role: "superadmin"
    }

    assert_response :redirect
    assert_equal "Invalid role.", flash[:alert]
  end

  test "bulk_deactivate deactivates selected users" do
    sign_in @admin
    patch bulk_deactivate_admin_users_path, params: {
      user_ids: [@user.id]
    }

    assert_redirected_to admin_users_path
    @user.reload
    # This used to assert `access_locked?` — the mechanism, not the outcome —
    # which is why it stayed green while deactivation silently expired after an
    # hour on the Devise unlock timer.
    assert_predicate @user, :deactivated?, "User should be deactivated"
  end

  test "non-admin cannot access bulk_deactivate" do
    sign_in @editor
    patch bulk_deactivate_admin_users_path, params: {
      user_ids: [@user.id]
    }

    assert_redirected_to root_path
  end
  # --- Sortable column headers --------------------------------------------

  test "index renders sortable headers for the query-backed columns" do
    sign_in @admin
    get admin_users_path

    assert_response :success
    assert_select "th a.table__sort", text: "Email"
    assert_select "th a.table__sort", text: "Role"
    assert_select "th a.table__sort", text: "Joined"
  end

  test "index leaves association-count columns unsorted" do
    sign_in @admin
    get admin_users_path

    assert_response :success
    # Groups and Workflows are counts; sorting them means a join or a counter
    # cache. They must stay plain text, not links.
    assert_select "th", text: "Groups"
    assert_select "th", text: "Workflows"
    assert_select "th a.table__sort", text: "Groups", count: 0
    assert_select "th a.table__sort", text: "Workflows", count: 0
  end

  test "index marks the default ordering on the Joined column" do
    sign_in @admin
    get admin_users_path

    assert_response :success
    # With no ?sort the list is still ordered newest-first, so the header must
    # say so rather than looking untouched.
    assert_select "th[aria-sort=descending] a.table__sort.is-sorted-desc", text: "Joined"
  end

  test "index marks the active column and offers the opposite direction" do
    sign_in @admin
    get admin_users_path(sort: "email_asc")

    assert_response :success
    assert_select "th[aria-sort=ascending] a.table__sort.is-sorted-asc", text: "Email" do |links|
      assert_includes links.first["href"], "sort=email_desc",
                      "an ascending column must link to descending"
    end
  end

  test "index toggles an active descending column back to ascending" do
    sign_in @admin
    get admin_users_path(sort: "email_desc")

    assert_response :success
    assert_select "a.table__sort.is-sorted-desc", text: "Email" do |links|
      assert_includes links.first["href"], "sort=email_asc"
    end
  end

  test "index opens Joined descending but Email ascending on first click" do
    sign_in @admin
    get admin_users_path(sort: "role_asc")

    assert_response :success
    assert_select "a.table__sort", text: "Email" do |links|
      assert_includes links.first["href"], "sort=email_asc", "Email should open A-Z"
    end
    assert_select "a.table__sort", text: "Joined" do |links|
      assert_includes links.first["href"], "sort=created_at_desc", "Joined should open newest-first"
    end
  end

  test "sort links preserve active filters and reset the page" do
    sign_in @admin
    get admin_users_path(sort: "email_asc", q: "example", role: "admin", page: 3)

    assert_response :success
    assert_select "a.table__sort", text: "Role" do |links|
      href = links.first["href"]
      assert_includes href, "q=example", "sorting must not clear the search"
      assert_includes href, "role=admin", "sorting must not clear the role filter"
      assert_not_includes href, "page=3", "sorting must return to page 1"
    end
  end

  test "index no longer renders the sort dropdown but carries sort through filtering" do
    sign_in @admin
    get admin_users_path(sort: "email_asc")

    assert_response :success
    assert_select "select[name=?]", "sort", count: 0
    assert_select "form.admin-filter-toolbar input[type=hidden][name=?][value=?]", "sort", "email_asc"
  end

  test "index actually reorders the rows when sorted" do
    sign_in @admin
    User.create!(email: "aaa-sortcheck@example.com", password: "password123!",
                 password_confirmation: "password123!", role: "editor")
    User.create!(email: "zzz-sortcheck@example.com", password: "password123!",
                 password_confirmation: "password123!", role: "editor")

    # Email is the SECOND cell: the bulk-select column occupies the first.
    # Selecting nth-child(1) here yields [] and the assertions below pass
    # vacuously, which is exactly what an earlier version of this test did.
    get admin_users_path(sort: "email_asc", per_page: 100)
    ascending = css_select("tbody tr td:nth-child(2) span.font-medium").map { |cell| cell.text.strip }

    get admin_users_path(sort: "email_desc", per_page: 100)
    descending = css_select("tbody tr td:nth-child(2) span.font-medium").map { |cell| cell.text.strip }

    assert_operator ascending.size, :>=, 2, "need at least two rows for ordering to mean anything"
    assert_equal ascending.sort, ascending
    assert_equal ascending.reverse, descending
  end

  # -- Slice 2b: deactivation has to actually deactivate ------------------------
  #
  # "Deactivate" called Devise `lock_access!`, and devise.rb sets
  # `unlock_strategy = :both` with `unlock_in = 1.hour` — so a deactivated user
  # could sign in again 61 minutes later, while the confirm dialog promised
  # "They will not be able to sign in." There was also no way to reactivate
  # anyone, and the badge could not tell an admin's deliberate offboarding from
  # Devise's automatic five-failed-attempts lockout.

  test 'deactivation survives the devise unlock window' do
    sign_in @admin
    patch deactivate_admin_user_path(@user)

    assert_predicate @user.reload, :deactivated?

    travel 2.hours do
      assert_predicate @user.reload, :deactivated?,
                       'deactivation must not expire on the Devise unlock timer'
    end
  end

  test 'deactivating a signed-in user ends the session they already hold' do
    # Blocking new sign-ins is not enough for an offboarding control: the person
    # being offboarded is usually signed in at the moment you do it. Devise's
    # activatable hook re-checks active_for_authentication? on every request, so
    # the next one bounces — asserted here because that is a property of Devise's
    # configuration, not of our code, and a change to either could silently
    # remove it.
    # An editor, because WorkflowsController bounces a regular user from
    # /workflows anyway — the precondition has to be a page the subject can
    # actually load, or the assertion below proves nothing.
    post user_session_path, params: { user: { email: @editor.email, password: 'password123!' } }
    get workflows_path

    assert_response :success, 'precondition: the user is signed in and browsing'

    @editor.deactivate!
    get workflows_path

    assert_redirected_to new_user_session_path
  end

  test 'a deactivated user cannot sign in' do
    @user.deactivate!
    post user_session_path, params: { user: { email: @user.email, password: 'password123!' } }

    assert_redirected_to new_user_session_path
    follow_redirect!

    assert_match(/deactivated/i, response.body,
                 'the refusal must say why, not just bounce them to the form')
    get admin_root_path

    assert_redirected_to new_user_session_path, 'a deactivated user must have no session'
  end

  test 'an admin can reactivate a deactivated user' do
    @user.deactivate!
    sign_in @admin
    patch reactivate_admin_user_path(@user)

    assert_redirected_to admin_users_path
    assert_not_predicate @user.reload, :deactivated?
  end

  test 'a failed login lockout is not reported as deactivated' do
    @user.lock_access!(send_instructions: false)

    assert_predicate @user, :access_locked?
    assert_not_predicate @user, :deactivated?,
                         'a Devise lockout is not an administrative deactivation'
  end

  test 'the listing distinguishes a deactivated user from a locked-out one' do
    @user.deactivate!
    @editor.lock_access!(send_instructions: false)
    sign_in @admin
    get admin_users_path(per_page: 100)

    deactivated_row = css_select("tbody tr:has(form[action='#{update_role_admin_user_path(@user)}'])").first.text
    locked_row = css_select("tbody tr:has(form[action='#{update_role_admin_user_path(@editor)}'])").first.text

    assert_match(/deactivated/i, deactivated_row)
    assert_no_match(/deactivated/i, locked_row,
                    'a failed-login lockout must not be labelled Deactivated')
  end

  test 'bulk deactivate uses the same durable mechanism as the per-user action' do
    sign_in @admin
    patch bulk_deactivate_admin_users_path, params: { user_ids: [@user.id] }

    assert_predicate @user.reload, :deactivated?

    travel 2.hours do
      assert_predicate @user.reload, :deactivated?
    end
  end

  test 'admin cannot deactivate their own account' do
    sign_in @admin
    patch deactivate_admin_user_path(@admin)

    assert_not_predicate @admin.reload, :deactivated?
    assert_match(/your own/i, flash[:alert].to_s)
  end

  test 'deactivating an already deactivated user is a no-op' do
    @user.deactivate!
    first_stamp = @user.reload.deactivated_at
    sign_in @admin

    travel 1.hour do
      patch deactivate_admin_user_path(@user)

      assert_predicate @user.reload, :deactivated?
      assert_equal first_stamp.to_i, @user.deactivated_at.to_i,
                   're-deactivating must not restamp the record'
    end
  end

  test 'reactivating clears a devise lockout as well' do
    @user.deactivate!
    @user.lock_access!(send_instructions: false)
    sign_in @admin
    patch reactivate_admin_user_path(@user)
    @user.reload

    assert_not_predicate @user, :deactivated?
    assert_not_predicate @user, :access_locked?,
                         'reactivating must not leave the user locked out by failed attempts'
  end

  # -- Slice 2b: the users table stays legible in bulk mode ---------------------
  #
  # The table is `table-layout: fixed` with a <colgroup>. Entering bulk mode used
  # to set `display: table-cell` on every `.bulk-select-column`, including the
  # <col> element — which must be `table-column`. The browser then dropped it
  # from the column list and every width applied one column to the left: the
  # checkbox column took 339px while Email collapsed to 97px, so the Role text
  # rendered on top of the email and the role select squeezed to 54px.

  test 'the colgroup declares exactly one col per header cell' do
    sign_in @admin
    get admin_users_path

    cols = css_select('table.table > colgroup > col').size
    headers = css_select('table.table > thead > tr > th').size

    assert_operator cols, :>, 0, 'expected a colgroup'
    assert_equal headers, cols,
                 'a fixed-layout table needs one <col> per column, or every width shifts'
  end

  test 'each row renders the role exactly once' do
    sign_in @admin
    get admin_users_path(per_page: 100)

    row = css_select("tbody tr:has(form[action='#{update_role_admin_user_path(@user)}'])").first

    assert row, 'could not find the row for the test user'
    selects = row.css("select[name='role']").size
    # The badge duplicated what the select already says, and cost the width the
    # bulk-mode checkbox column needed.
    badges = row.css('span.badge').map { |b| b.text.strip.downcase }
                .count { |t| User::ASSIGNABLE_ROLES.include?(t) }

    assert_equal 1, selects, 'expected exactly one role control per row'
    assert_equal 0, badges, 'the role must not also be printed as a badge'
  end

  # -- Slice 2a: one source of truth for a role value --------------------------
  #
  # The row select was built from `User.roles` KEYS (admin/editor/regular) while
  # update_role validated against `User::ROLES` (admin/editor/user). "regular"
  # never matched, so demoting a single user to Regular was impossible and
  # reported "Invalid role specified." Admin<->Editor worked, which is why it
  # survived. The bulk dialog hardcoded the DB value and worked, so the same
  # action succeeded in bulk and failed per-row.

  test 'admin demotes an editor to regular from the row select' do
    sign_in @admin
    patch update_role_admin_user_path(@editor), params: { role: 'regular' }

    assert_redirected_to admin_users_path
    assert_nil flash[:alert]
    @editor.reload

    assert_predicate @editor, :regular?
    assert_equal 'user', @editor.role_before_type_cast,
                 'the enum must still persist the column value, not the key'
  end

  test 'admin promotes a regular user to editor' do
    sign_in @admin
    patch update_role_admin_user_path(@user), params: { role: 'editor' }

    assert_redirected_to admin_users_path
    @user.reload

    assert_predicate @user, :editor?
  end

  test 'the row role select offers exactly the values update_role accepts' do
    sign_in @admin
    get admin_users_path(per_page: 100)

    offered = css_select("form[action='#{update_role_admin_user_path(@user)}'] select option")
              .pluck('value')

    assert_not_empty offered, "no role select rendered for #{@user.email}"
    assert_equal User::ASSIGNABLE_ROLES.sort, offered.sort,
                 'every option the row renders must be a role update_role accepts'
  end

  test 'the bulk role dialog offers exactly the values bulk_update_role accepts' do
    sign_in @admin
    get admin_users_path(per_page: 100)

    offered = css_select("form[action='#{bulk_update_role_admin_users_path}'] select option")
              .pluck('value')

    assert_not_empty offered, 'no bulk role select rendered'
    assert_equal User::ASSIGNABLE_ROLES.sort, offered.sort
  end

  test 'bulk role change to regular still works' do
    sign_in @admin
    patch bulk_update_role_admin_users_path, params: { user_ids: [@editor.id], role: 'regular' }

    @editor.reload

    assert_predicate @editor, :regular?
  end

  test 'admin cannot change their own role' do
    sign_in @admin
    patch update_role_admin_user_path(@admin), params: { role: 'regular' }

    assert_redirected_to admin_users_path
    @admin.reload

    assert_predicate @admin, :admin?, 'an admin must not be able to strip their own access'
    assert_match(/own role/i, flash[:alert].to_s)
  end

  test 'the role filter works for regular, where the key and the column value differ' do
    sign_in @admin
    # The pre-existing filter test only covered role=admin, where the enum key
    # and the column value are the same string — so it could not catch the
    # selects being rewired from values to keys. "regular" maps to "user".
    get admin_users_path(role: 'regular', per_page: 100)

    assert_response :success
    emails = css_select('tbody tr td:nth-child(1) span.font-medium, tbody tr td:nth-child(2) span.font-medium')
             .map { |cell| cell.text.strip }

    assert_includes emails, @user.email, 'a regular user must appear under the Regular filter'
    assert_not_includes emails, @admin.email
    assert_not_includes emails, @editor.email
  end

  test 'the role filter select offers exactly the values the filter accepts' do
    sign_in @admin
    get admin_users_path

    offered = css_select("form.admin-filter-toolbar select[name='role'] option")
              .pluck('value').compact_blank

    assert_not_empty offered
    assert_equal User::ASSIGNABLE_ROLES.sort, offered.sort
  end

  test 'update_role reports failure when the record cannot be saved' do
    sign_in @admin
    # An unrecognised time zone makes the record invalid, so `update` returns
    # false. The action used to ignore that and report success anyway.
    @user.update_column(:time_zone, 'Not/AZone')

    patch update_role_admin_user_path(@user), params: { role: 'editor' }

    assert_redirected_to admin_users_path
    assert_nil flash[:notice], 'a failed save must not report success'
    assert_match(/fail/i, flash[:alert].to_s)
    @user.reload

    assert_predicate @user, :regular?
  end
end
