require "test_helper"

# A select field's choices, end to end.
#
# `scenarios/_form_step` has rendered `field["select_options"]` since the Form
# step shipped, and nothing could ever write it: the permit list dropped the key,
# the published schema rejected it as an additional property, and the builder
# offered no control. Every select rendered an empty dropdown.
#
# These tests are about the writers, because the reader was never the problem.
class Steps::FormSelectOptionsTest < ActiveSupport::TestCase
  IVR  = { "label" => "IVR", "value" => "ivr" }.freeze
  LINK = { "label" => "Link", "value" => "link" }.freeze

  setup do
    @user = User.create!(email: "sel-#{SecureRandom.hex(4)}@example.com",
                         password: "password123456")
    @workflow = Workflow.create!(title: "Select Options WF", user: @user)
  end

  # --- the storage shape (what import supplies) --------------------------------

  test "structured select_options survive a save untouched" do
    field = { "name" => "paid", "label" => "How paid", "field_type" => "select",
              "select_options" => [IVR, LINK] }

    assert_equal [IVR, LINK], stored_field(field)["select_options"]
  end

  test "select_options_for reads the choices and is empty for other types" do
    step = build_form(
      { "name" => "paid", "field_type" => "select", "select_options" => [IVR] },
      { "name" => "note", "field_type" => "text" }
    )

    assert_equal 1, step.select_options_for(step.fields[0]).size
    assert_empty step.select_options_for(step.fields[1])
  end

  # --- the builder transport ---------------------------------------------------

  test "the builder's comma separated raw string becomes stored pairs" do
    field = { "name" => "paid", "field_type" => "select",
              "select_options_raw" => "IVR, Secure link , On file" }

    assert_equal ["IVR", "Secure link", "On file"],
                 stored_field(field)["select_options"].pluck("label")
  end

  test "a choice's value defaults to its label when the builder authored it" do
    field = { "name" => "paid", "field_type" => "select", "select_options_raw" => "IVR" }

    assert_equal [{ "label" => "IVR", "value" => "IVR" }], stored_field(field)["select_options"]
  end

  test "newlines separate choices too, and blanks are dropped" do
    field = { "name" => "paid", "field_type" => "select",
              "select_options_raw" => "Yes\n\nNo,,\n" }

    assert_equal %w[Yes No], stored_field(field)["select_options"].pluck("label")
  end

  test "the raw transport key is never persisted" do
    field = { "name" => "paid", "field_type" => "select", "select_options_raw" => "Yes, No" }

    assert_not stored_field(field).key?("select_options_raw"),
               "select_options_raw is a UI transport and must not reach the database"
  end

  test "a blank raw string clears the choices" do
    field = { "name" => "a", "field_type" => "select",
              "select_options" => [IVR], "select_options_raw" => "" }

    assert_nil stored_field(field)["select_options"],
               "an empty raw string is a deliberate removal"
  end

  test "a missing raw key leaves imported choices alone" do
    field = { "name" => "a", "field_type" => "select", "select_options" => [IVR] }

    assert_equal [IVR], stored_field(field)["select_options"],
                 "import sends no raw key at all, and must not have its choices cleared"
  end

  test "select_options_text round trips the stored choices back to the builder" do
    step = build_form({ "name" => "paid", "field_type" => "select",
                        "select_options" => [IVR, LINK] })

    assert_equal "IVR, Link", step.select_options_text(step.fields.first)
  end

  # --- the gap this closes -----------------------------------------------------

  test "select_fields_without_choices names the fields that render empty" do
    step = build_form(
      { "name" => "ok", "field_type" => "select", "select_options" => [IVR] },
      { "name" => "broken", "field_type" => "select" },
      { "name" => "text_field", "field_type" => "text" }
    )

    assert_equal ["broken"], step.select_fields_without_choices.pluck("name")
  end

  # --- the builder must not rewrite choices it was not asked to change ---------
  #
  # `_form.html.erb` renders the raw choices box on every field row of every
  # autosave, and its value is labels only. So an edit to an unrelated part of
  # the step re-posted a raw string that, parsed, flattened every value to its
  # label. Only import can author a value that differs from its label, which is
  # why nothing noticed until a bundle carried one.

  test "an unchanged choices box leaves imported label/value pairs alone" do
    step = build_form("name" => "contact", "field_type" => "select",
                      "select_options" => [{ "label" => "Phone", "value" => "phone" },
                                           { "label" => "Email", "value" => "email" }])
    raw = step.select_options_text(step.fields.first)

    step.update!(title: "Edited elsewhere",
                 options: [{ "name" => "contact", "field_type" => "select", "select_options_raw" => raw }])

    assert_equal [{ "label" => "Phone", "value" => "phone" }, { "label" => "Email", "value" => "email" }],
                 step.reload.fields.first["select_options"],
                 "re-posting the rendered box is 'I did not touch this', not 'rewrite values from labels'"
  end

  test "a label containing the separator survives an unrelated save" do
    step = build_form("name" => "urgency", "field_type" => "select",
                      "select_options" => [{ "label" => "Yes, immediately", "value" => "yes" },
                                           { "label" => "No", "value" => "no" }])
    raw = step.select_options_text(step.fields.first)

    assert_equal "Yes, immediately, No", raw, "the rendered text is genuinely ambiguous — that is the trap"

    step.update!(options: [{ "name" => "urgency", "field_type" => "select", "select_options_raw" => raw }])

    assert_equal ["Yes, immediately", "No"], step.reload.fields.first["select_options"].pluck("label"),
                 "splitting the rendered text turned two choices into three"
  end

  test "editing the choices box still rewrites them" do
    step = build_form("name" => "contact", "field_type" => "select",
                      "select_options" => [{ "label" => "Phone", "value" => "phone" }])

    step.update!(options: [{ "name" => "contact", "field_type" => "select",
                             "select_options_raw" => "Phone, Email" }])

    assert_equal [{ "label" => "Phone", "value" => "Phone" }, { "label" => "Email", "value" => "Email" }],
                 step.reload.fields.first["select_options"],
                 "a real edit is label=value, which is the builder's contract"
  end

  test "clearing the choices box still removes them" do
    step = build_form("name" => "contact", "field_type" => "select",
                      "select_options" => [{ "label" => "Phone", "value" => "phone" }])

    step.update!(options: [{ "name" => "contact", "field_type" => "select", "select_options_raw" => "" }])

    assert_nil step.reload.fields.first["select_options"]
  end

  private

  def build_form(*fields)
    Steps::Form.create!(workflow: @workflow, title: "Collect #{SecureRandom.hex(3)}",
                        position: @workflow.steps.count, options: fields)
  end

  def stored_field(field)
    build_form(field).reload.fields.first
  end
end
