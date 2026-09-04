require "test_helper"

# The reader half: a select field renders the choices it was given.
#
# `scenarios/_form_step` has always looped over `field["select_options"]`, and
# until 2026-09-04 nothing could write that key — so this loop ran zero times on
# every run that ever happened. The writers are covered by the model and
# controller tests; this asserts the agent actually sees a dropdown they can
# answer, which is the only reason any of it matters.
class RunnerFormSelectTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "form-select-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    sign_in @user

    @workflow = Workflow.create!(title: "Form Select WF", user: @user, status: "published")
    @form = Steps::Form.create!(
      workflow: @workflow, position: 0, title: "Take payment",
      options: [{ "name" => "method", "label" => "How was payment taken",
                  "field_type" => "select", "required" => true, "position" => 0,
                  "select_options" => [{ "label" => "IVR", "value" => "ivr" },
                                       { "label" => "Secure link", "value" => "link" }] }]
    )
    @done = Steps::Resolve.create!(workflow: @workflow, position: 1, title: "Done",
                                   resolution_type: "success")
    Transition.create!(step: @form, target_step: @done, position: 0)
    @workflow.update!(start_step: @form)
  end

  def open_run
    post play_workflow_path(@workflow)
    follow_redirect!
  end

  test "a select field renders its choices as real options" do
    open_run

    assert_response :success
    assert_select "select[name='answer[method]']" do
      assert_select "option[value='ivr']", text: "IVR"
      assert_select "option[value='link']", text: "Secure link"
    end
  end

  test "the agent can submit a choice and the run advances" do
    open_run
    scenario = Scenario.where(workflow: @workflow).order(:id).last

    post player_scenario_next_path(scenario), params: { answer: { method: "ivr" } }
    scenario.reload

    assert_equal "ivr", scenario.results["method"],
                 "the chosen value is what gets recorded, not the label"
    assert_not_equal @form.uuid, scenario.current_node_uuid, "the run moved on"
  end

  test "a select with no choices renders a dropdown with nothing to pick" do
    @form.update!(options: [{ "name" => "empty", "label" => "Nothing here",
                              "field_type" => "select", "position" => 0 }])
    open_run

    assert_select "select[name='answer[empty]']" do |selects|
      real = selects.first.css("option").reject { |o| o["value"].to_s.empty? }
      assert_empty real,
                   "this is the broken state the fix exists to prevent; " \
                   "StrictImportValidator refuses it on the import path"
    end
  end
end
