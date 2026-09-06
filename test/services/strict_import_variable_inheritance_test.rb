require "test_helper"

# What a sub-flow inherits from whoever calls it.
#
# ScenarioStepProcessor seeds a child scenario with `(@scenario.results ||
# {}).dup` — the caller's ENTIRE bag — and only then applies variable_mapping,
# which therefore *renames* rather than selects. Verified against a real run,
# not read: a sub-flow spawned with no variable_mapping at all still received
# the caller's variables.
#
# StrictImportValidator checked each workflow in isolation, so it reported
# `undefined_variable` on every correct bundle that passed data down. The
# published schema and the agent prompt both claimed the same wrong thing
# ("only mapped variables are seeded") until this was spiked.
#
# Separate from strict_import_validator_test.rb only because that class is at
# its RuboCop length limit.
class StrictImportVariableInheritanceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "strict-inherit-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
  end

  teardown do
    User.where("email LIKE ?", "strict-inherit-%").destroy_all
  end

  test "a sub-flow may use a variable its caller set, with no mapping at all" do
    report = validate(caller_and_target(
                        mapping: nil,
                        target_content: "<p>Down: {{fully_down}}</p>"
                      ))

    assert_predicate report, :valid?, report.errors.inspect
    assert_empty report.warnings.select { |w| w[:code] == "undefined_variable" },
                 report.warnings.inspect
  end

  test "a variable_mapping renames, and the new name counts as defined" do
    report = validate(caller_and_target(
                        mapping: { fully_down: "was_fully_down" },
                        target_content: "<p>Down: {{was_fully_down}}</p>"
                      ))

    assert_predicate report, :valid?, report.errors.inspect
    assert_empty report.warnings.select { |w| w[:code] == "undefined_variable" },
                 report.warnings.inspect
  end

  test "inheritance is transitive: a grandchild sees what the top workflow set" do
    report = validate(chain_of_three(content: "<p>{{fully_down}}</p>"))

    assert_predicate report, :valid?, report.errors.inspect
    assert_empty report.warnings.select { |w| w[:code] == "undefined_variable" },
                 report.warnings.inspect
  end

  test "a typo in a sub-flow is still reported — inheritance is not a blanket amnesty" do
    report = validate(caller_and_target(
                        mapping: nil,
                        target_content: "<p>Down: {{fuly_down}}</p>"
                      ))

    warning = report.warnings.find { |w| w[:code] == "undefined_variable" }
    assert_not_nil warning, report.warnings.inspect
    assert_equal "fuly_down", warning[:value]
  end

  # SubflowValidator refuses a cyclic bundle, but it runs at import — after this.
  # So the closure has to terminate on its own rather than rely on that.
  test "a cyclic bundle does not hang the variable closure" do
    document = {
      schema_version: "1",
      workflows: [
        { title: "Cycle A", steps: [
          { id: "sf", type: "sub_flow", title: "To B", target_workflow_title: "Cycle B",
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] },
        { title: "Cycle B", steps: [
          { id: "sf", type: "sub_flow", title: "To A", target_workflow_title: "Cycle A",
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] }
      ]
    }

    report = nil
    assert_nothing_raised do
      Timeout.timeout(10) { report = validate(document) }
    end
    assert_not_nil report
  end

  # A two-workflow bundle: the first asks a question and calls the second.
  def caller_and_target(mapping:, target_content:)
    sub_flow = { id: "sf", type: "sub_flow", title: "Go deeper",
                 target_workflow_title: "Var Target",
                 transitions: [{ target_id: "done" }] }
    sub_flow[:variable_mapping] = mapping if mapping

    {
      schema_version: "1",
      workflows: [
        { title: "Var Caller", steps: [
          { id: "q", type: "question", title: "Down?", question: "Fully down?",
            answer_type: "yes_no", variable_name: "fully_down",
            transitions: [{ target_id: "sf" }] },
          sub_flow,
          resolve_step
        ] },
        { title: "Var Target", steps: [
          { id: "m", type: "message", title: "Note", content: target_content,
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] }
      ]
    }
  end

  # A -> B -> C, where only A sets the variable and only C reads it.
  def chain_of_three(content:)
    {
      schema_version: "1",
      workflows: [
        { title: "Chain A", steps: [
          { id: "q", type: "question", title: "Down?", question: "Fully down?",
            answer_type: "yes_no", variable_name: "fully_down",
            transitions: [{ target_id: "sf" }] },
          { id: "sf", type: "sub_flow", title: "To B", target_workflow_title: "Chain B",
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] },
        { title: "Chain B", steps: [
          { id: "sf", type: "sub_flow", title: "To C", target_workflow_title: "Chain C",
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] },
        { title: "Chain C", steps: [
          { id: "m", type: "message", title: "Note", content: content,
            transitions: [{ target_id: "done" }] },
          resolve_step
        ] }
      ]
    }
  end

  private

  def validate(hash)
    StrictImportValidator.new(user: @user, content: hash.to_json).validate
  end

  def resolve_step
    { id: "done", type: "resolve", title: "Done", resolution_type: "success" }
  end
end
