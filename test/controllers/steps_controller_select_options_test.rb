require "test_helper"

# The permit gate for a select field's choices.
#
# This is the gate that failed silently. `scenarios/_form_step` rendered
# `field["select_options"]` from the day the Form step shipped, and
# StepFieldMap::NESTED_SHAPES did not permit the key — so a builder save dropped
# it with no error, because a permit list fails silently by design. Every select
# rendered an empty dropdown.
#
# A model test cannot catch that: the model was always willing to store it.
# Only a request proves the key survives strong params.
class StepsControllerSelectOptionsTest < ActionDispatch::IntegrationTest
  setup do
    @editor = User.create!(
      email: "editor-select-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    @workflow = Workflow.create!(title: "Select Options WF", user: @editor, graph_mode: true)
    @step = Steps::Form.create!(workflow: @workflow, position: 0, title: "Collect")
    sign_in @editor
  end

  test "the builder's raw choices survive strong params and are stored as pairs" do
    patch workflow_step_path(@workflow, @step), params: {
      step: { options: [{ name: "paid", label: "How paid", field_type: "select",
                          position: 0, select_options_raw: "IVR, Secure link" }] }
    }

    field = @step.reload.fields.first
    assert_equal [{ "label" => "IVR", "value" => "IVR" },
                  { "label" => "Secure link", "value" => "Secure link" }],
                 field["select_options"],
                 "the choices must survive the permit list — this is the gate that was closed"
    assert_not field.key?("select_options_raw"), "the transport key must not be persisted"
  end

  test "structured select_options survive strong params too" do
    patch workflow_step_path(@workflow, @step), params: {
      step: { options: [{ name: "paid", label: "How paid", field_type: "select", position: 0,
                          select_options: [{ label: "IVR", value: "ivr" }] }] }
    }

    assert_equal [{ "label" => "IVR", "value" => "ivr" }],
                 @step.reload.fields.first["select_options"]
  end

  test "the other form field keys still survive alongside the new one" do
    patch workflow_step_path(@workflow, @step), params: {
      step: { options: [{ name: "paid", label: "How paid", field_type: "select",
                          required: true, position: 0, select_options_raw: "Yes, No" }] }
    }

    field = @step.reload.fields.first
    assert_equal "paid", field["name"]
    assert_equal "How paid", field["label"]
    assert_equal "select", field["field_type"]
    # A form-encoded PATCH stores the string "true" where an import stores the
    # boolean. Both are truthy, and every reader tests truthiness rather than
    # equality, so the two shapes behave identically — but assert the truth
    # rather than a boolean this path never produces. The builder's checkbox
    # posts nothing when unchecked, so the string is never "false".
    assert field["required"], "a checked Required box must survive the round trip"
    assert_equal 2, field["select_options"].size
  end

  test "a non-select field is unaffected" do
    patch workflow_step_path(@workflow, @step), params: {
      step: { options: [{ name: "note", label: "Note", field_type: "text", position: 0 }] }
    }

    field = @step.reload.fields.first
    assert_equal "text", field["field_type"]
    assert_nil field["select_options"]
  end
end
