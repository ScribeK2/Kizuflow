require "test_helper"

# Spec Q46. The migration takes Uncategorized's workflows out, and an editor can
# still leave a published workflow in no group. Neither is visible to the person
# responsible, so the Overview names them.
class Admin::NoAudienceTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "no-aud-admin-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "admin")
    @editor = User.create!(email: "no-aud-editor-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
    @forgotten = Workflow.create!(title: "Forgotten #{SecureRandom.hex(3)}", user: @editor)
    @chosen = file_in_global(Workflow.create!(title: "Chosen #{SecureRandom.hex(3)}", user: @editor))
  end

  test "the Overview names published workflows with no audience and links to all of them" do
    sign_in @admin

    get admin_root_path

    assert_select "#attention-no-audience a[href=?]", workflow_path(@forgotten, edit: true), text: @forgotten.title
    assert_select "#attention-no-audience a[href=?]", workflows_path(audience: "none")
  end

  test "the no-audience list shows only those workflows, and keeps the filter across pages" do
    sign_in @admin

    get workflows_path(audience: "none")

    assert_match @forgotten.title, response.body
    assert_no_match @chosen.title, response.body
    assert_select "input[type=hidden][name=audience][value=none]"
  end

  test "the filter means nothing to an editor" do
    sign_in @editor

    get workflows_path(audience: "none")

    assert_match @chosen.title, response.body
  end
end
