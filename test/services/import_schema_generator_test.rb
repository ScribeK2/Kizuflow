require "test_helper"

class ImportSchemaGeneratorTest < ActiveSupport::TestCase
  setup { @schema = ImportSchemaGenerator.call }

  test "the envelope requires schema_version and a bounded workflows array" do
    assert_equal %w[schema_version workflows], @schema["required"]
    # The app's own export sets exported_at; additionalProperties is false, so an
    # agent validating against this schema would otherwise reject a TurboFlows export.
    assert @schema["properties"].key?("exported_at")
    assert_equal [ImportSchemaGenerator::SCHEMA_VERSION],
                 @schema["properties"]["schema_version"]["enum"]
    # A file carries a SET of workflows, so a sub_flow can name one defined
    # alongside it. Bounded rather than unbounded: the whole bundle is validated
    # and written in one transaction.
    assert_equal ImportSchemaGenerator::MAX_WORKFLOWS_PER_FILE,
                 @schema["properties"]["workflows"]["maxItems"]
    assert_equal 1, @schema["properties"]["workflows"]["minItems"]
    assert_operator ImportSchemaGenerator::MAX_WORKFLOWS_PER_FILE, :>, 1
  end

  test "a select form field must declare its choices, matching the validator" do
    options = step_branch("form")["properties"]["options"]["items"]

    assert options["properties"].key?("select_options"),
           "external agents lose the property entirely if the generator stops emitting it"
    assert_equal %w[label value], options["properties"]["select_options"]["items"]["required"]

    conditional = options["allOf"].first
    assert_equal "select", conditional["if"]["properties"]["field_type"]["const"]
    assert_equal %w[select_options], conditional["then"]["required"],
                 "StrictImportValidator refuses a choiceless select, so the schema must too — " \
                 "a looser schema sends the agent away with a file that fails on upload"
  end

  test "variable_mapping publishes the shape the runtime actually seeds" do
    mapping = step_branch("sub_flow")["properties"]["variable_mapping"]

    assert_equal "string", mapping["additionalProperties"]["type"]
    assert_predicate mapping["description"], :present?,
                     "a bare object taught an agent nothing, so it omitted the key rather than guess"
  end

  test "every step type in the app has a schema branch" do
    branch_types = @schema["$defs"]["step"]["oneOf"].map do |branch|
      branch["properties"]["type"]["const"]
    end

    assert_equal Workflow::VALID_STEP_TYPES.sort, branch_types.sort
  end

  test "step branches publish the model's own value lists" do
    question = step_branch("question")

    assert_equal Steps::Question::VALID_ANSWER_TYPES,
                 question["properties"]["answer_type"]["enum"]

    escalate = step_branch("escalate")

    assert_equal Steps::Escalate::VALID_PRIORITIES,
                 escalate["properties"]["priority"]["enum"]
    assert_equal Steps::Escalate::VALID_TARGET_TYPES,
                 escalate["properties"]["target_type"]["enum"]

    resolve = step_branch("resolve")

    assert_equal Steps::Resolve::VALID_RESOLUTION_TYPES,
                 resolve["properties"]["resolution_type"]["enum"]
  end

  test "fields with no builder UI are absent from every branch" do
    excluded = ImportSchemaGenerator::EXCLUDED_FIELDS.map(&:to_s) +
               ImportSchemaGenerator::EXCLUDED_WIRE_KEYS

    excluded.each do |field|
      @schema["$defs"]["step"]["oneOf"].each do |branch|
        assert_not branch["properties"].key?(field),
                   "#{field} leaked into the #{branch['properties']['type']['const']} branch"
      end
    end
  end

  test "sub_flow takes a workflow title, never a database id" do
    sub_flow = step_branch("sub_flow")

    assert sub_flow["properties"].key?("target_workflow_title")
    assert_includes sub_flow["required"], "target_workflow_title"
  end

  test "variable_mapping is published, because the sub_flow editor renders it" do
    assert step_branch("sub_flow")["properties"].key?("variable_mapping")
  end

  test "every step branch forbids additional properties" do
    @schema["$defs"]["step"]["oneOf"].each do |branch|
      assert_not branch.fetch("additionalProperties")
    end
  end

  test "resolve steps are forbidden transitions and others require them" do
    assert_not step_branch("resolve")["properties"].key?("transitions")
    assert_includes step_branch("action")["required"], "transitions"
  end

  test "the committed schema file matches the generator" do
    committed = JSON.parse(File.read(ImportSchemaGenerator::SCHEMA_PATH))

    assert_equal @schema, committed,
                 "public/schemas is stale — run `bin/rails import_schema:generate`"
  end

  # `options` means two different things depending on step type: answer
  # choices on a question, field definitions on a form. Before this fix, both
  # branches published the same shared `oneOf`, so an agent could write
  # Form-shaped options on a Question step and validate cleanly. These three
  # tests pin the two shapes apart, using a minimal structural check (below)
  # rather than a real JSON Schema validator, since none is a project dependency.
  test "question options reject a form-shaped hash and accept its own shape" do
    item_schema = step_branch("question")["properties"]["options"]["items"]

    assert_not schema_permits?(item_schema, { "name" => "phone", "label" => "Phone" }),
               "question options accepted a form-shaped {name, label} hash"
    assert schema_permits?(item_schema, { "label" => "Yes", "value" => "yes" })
  end

  test "form options reject a bare label/value hash and accept its own shape" do
    item_schema = step_branch("form")["properties"]["options"]["items"]

    assert_not schema_permits?(item_schema, { "label" => "Yes", "value" => "yes" }),
               "form options accepted a bare question-shaped {label, value} hash"
    assert schema_permits?(item_schema, { "name" => "phone", "label" => "Phone" })
  end

  test "question and form options schemas are not the same shape" do
    assert_not_equal step_branch("question")["properties"]["options"],
                     step_branch("form")["properties"]["options"]
  end

  # A handoff step takes no transitions — that is what makes it a tail call. The
  # published schema put `minItems: 1` on transitions and listed them as required
  # for every non-resolve type, so it forbade the exact shape the feature exists
  # to let an agent emit (design doc §R item 9).
  test "the schema does not require transitions on a handoff step" do
    schema = ImportSchemaGenerator.new.call
    sub_flow = step_def(schema, "sub_flow")

    assert_not_includes sub_flow["required"], "transitions",
                        "requiring them unconditionally is what forbade a terminal handoff"

    conditional = Array(sub_flow["allOf"]).find { |c| c.dig("if", "properties", "sub_flow_returns") }

    assert conditional, "the requirement is conditional on the flag, not simply dropped"
    assert_equal({ "const" => false }, conditional.dig("if", "properties", "sub_flow_returns"))
    assert_includes conditional.dig("else", "required"), "transitions",
                    "a RETURNING sub_flow must still need a transition, or the exemption " \
                    "would let every dangling sub-flow through"
  end

  private

  def step_def(schema, type)
    defs = schema["$defs"] || schema["definitions"]
    candidates = defs.values.flat_map { |d| d["oneOf"] || d["anyOf"] || [d] }
    candidates.compact.find { |d| d.dig("properties", "type", "const") == type }
  end

  def step_branch(type)
    @schema["$defs"]["step"]["oneOf"].find { |b| b["properties"]["type"]["const"] == type }
  end

  # Minimal object-schema check: required keys present, and — when
  # additionalProperties is false — no keys outside the declared properties.
  # Not a general JSON Schema validator, just enough to prove the two options
  # branches genuinely reject each other's hash shape rather than merely
  # differing in some property that neither shape's `required`/`additionalProperties`
  # actually enforces.
  def schema_permits?(item_schema, hash)
    return false unless (item_schema.fetch("required", []) - hash.keys).empty?
    return true unless item_schema["additionalProperties"] == false

    (hash.keys - item_schema["properties"].keys).empty?
  end
end
