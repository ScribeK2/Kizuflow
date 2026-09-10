require "application_system_test_case"

# The Details panel's picker saves each tick through inline-autosave, which only
# a browser can prove: the controller test posts what the form WOULD send.
class WorkflowDetailsTest < ApplicationSystemTestCase
  setup do
    @editor = User.create!(email: "wf-system-test-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
    @created_global = Group.global.none?
    @global = Group.global.first || Group.create!(name: Group::GLOBAL_NAME)
    @workflow = Workflow.create!(title: "Details System #{SecureRandom.hex(3)}", user: @editor, status: "draft")
    resolve = Steps::Resolve.create!(workflow: @workflow, title: "Done", position: 0, resolution_type: "success")
    @workflow.update!(start_step: resolve)
  end

  teardown do
    GroupWorkflow.where(workflow_id: @workflow.id).delete_all
    Workflow.where(id: @workflow.id).destroy_all
    @global.delete if @created_global
  end

  test "ticking Global in Details saves it without a submit" do
    sign_in_as @editor
    visit workflow_path(@workflow, edit: true)
    assert_selector "[data-builder-mode-value='edit']", wait: 5

    click_on "Details"
    within "turbo-frame#builder-panel" do
      find(".group-picker__global input[type=checkbox]").check
    end

    assert_eventually(timeout: 10) { @workflow.reload.groups.include?(@global) }
  end
end
