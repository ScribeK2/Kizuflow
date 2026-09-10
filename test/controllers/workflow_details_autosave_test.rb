require "test_helper"

# The builder's Details panel: who can see this workflow, chosen on the shared
# path-aware picker and saved by inline-autosave with every other field.
class WorkflowDetailsAutosaveTest < ActionDispatch::IntegrationTest
  TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  setup do
    @editor = User.create!(email: "details-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
    @support = Group.create!(name: "Support #{SecureRandom.hex(3)}")
    UserGroup.create!(user: @editor, group: @support)
    @folder = Folder.create!(name: "Escalations", group: @support)
    @workflow = Workflow.create!(title: "Autosaved", user: @editor, status: "draft")
    GroupWorkflow.create!(group: @support, workflow: @workflow, folder: @folder, is_primary: true)
    sign_in @editor
  end

  test "an autosave of the Details panel keeps the workflow in its folder" do
    patch workflow_path(@workflow), params: { workflow: { description: "Edited", group_ids: ["", @support.id] } },
                                    headers: TURBO_STREAM

    assert_response :success
    assert_equal @folder.id, @workflow.group_workflows.find_by(group: @support).folder_id
  end

  test "an editor cannot file a workflow into a group they don't reach" do
    hidden = Group.create!(name: "Hidden #{SecureRandom.hex(3)}")

    # A permitted field too: params.expect refuses a workflow hash holding none,
    # and a refused request would pass this test without reaching the groups.
    patch workflow_path(@workflow), params: { workflow: { description: "Edited", group_ids: ["", @support.id, hidden.id] } },
                                    headers: TURBO_STREAM

    assert_response :success

    assert_equal [@support.id], @workflow.reload.group_ids
  end

  test "the picker offers Global on its own row, then only the groups this editor reaches, with paths" do
    global = global_group
    child = Group.create!(name: "Tier 2", parent: @support)
    hidden = Group.create!(name: "Hidden #{SecureRandom.hex(3)}")

    get workflow_settings_path(@workflow)

    assert_select ".group-picker__global input[name='workflow[group_ids][]'][value=?]", global.id.to_s
    assert_select ".group-picker__list input[value=?]", child.id.to_s
    assert_select ".group-picker__path", text: "#{@support.name} / Tier 2"
    assert_select "input[name='workflow[group_ids][]'][value=?]", hidden.id.to_s, 0
    assert_select "input[name='workflow[is_public]']", 0
  end

  test "every tick autosaves" do
    global_group

    get workflow_settings_path(@workflow)

    assert_select ".group-picker input[type=checkbox]:not([data-action~='change->inline-autosave#schedule'])", 0
    assert_select ".group-picker input[type=checkbox]", minimum: 2
  end
end
