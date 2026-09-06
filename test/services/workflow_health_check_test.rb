# frozen_string_literal: true

require "test_helper"

class WorkflowHealthCheckTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "health-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    # Draft status avoids graph validation on save, letting us create intentionally broken workflows
    @workflow = Workflow.create!(title: "Health Test", user: @user, status: "draft")
  end

  # A choiceless select is not only a broken dropdown at run time. An export
  # carries schema_version, so it re-imports down the strict path where
  # StrictImportValidator refuses it — and nothing could write select_options
  # before 2026-09-04, so every select authored until then is in this state.
  # The health panel is where an operator finds which workflows to fix.
  test "a select field with no choices is flagged on its step" do
    form = Steps::Form.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0, title: "Collect",
      options: [{ "name" => "method", "label" => "How paid", "field_type" => "select" }]
    )
    resolve = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: form, target_step: resolve, position: 0)
    @workflow.update!(start_step: form)

    issues = WorkflowHealthCheck.new(@workflow.reload).call.issues[form.uuid]
    choiceless = issues.find { |i| i[:code] == :select_options_required }

    assert choiceless, "expected a select_options_required warning, got #{issues.inspect}"
    assert_equal :warning, choiceless[:severity]
    assert_match(/How paid/, choiceless[:message], "name the field so it can be found")
  end

  test "a select field whose choices are not label/value pairs is flagged too" do
    form = Steps::Form.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0, title: "Collect",
      options: [{ "name" => "method", "label" => "How paid", "field_type" => "select",
                  "select_options" => %w[IVR Link] }]
    )
    resolve = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: form, target_step: resolve, position: 0)
    @workflow.update!(start_step: form)

    issues = WorkflowHealthCheck.new(@workflow.reload).call.issues[form.uuid]

    assert(issues.any? { |i| i[:code] == :select_options_required },
           "a string array renders blank options, same as none at all")
  end

  test "a select field with real choices is not flagged" do
    form = Steps::Form.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0, title: "Collect",
      options: [{ "name" => "method", "label" => "How paid", "field_type" => "select",
                  "select_options" => [{ "label" => "IVR", "value" => "ivr" }] }]
    )
    resolve = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: form, target_step: resolve, position: 0)
    @workflow.update!(start_step: form)

    issues = WorkflowHealthCheck.new(@workflow.reload).call.issues[form.uuid]

    assert_not(issues.any? { |i| i[:code] == :select_options_required })
  end

  test "clean workflow returns no issues" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    r = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: q, target_step: r, position: 0)
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)

    assert_predicate result, :clean?
    assert_equal 0, result.summary[:total]
    assert_equal 0, result.summary[:errors]
    assert_equal 0, result.summary[:warnings]
  end

  test "step with no outgoing connections gets an error" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)

    assert_not result.clean?
    step_issues = result.issues[q.uuid]
    assert(step_issues.any? { |i| i[:message].include?("No outgoing connections") })
    # An error, not a warning: publish refuses a terminal that is not a Resolve,
    # and this issue now stands in for that finding.
    assert(step_issues.any? { |i| i[:severity] == :error })
  end

  test "dead-end step offers a fix that works whether or not a resolve exists" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)
    dead_end_issue = result.issues[q.uuid].find { |i| i[:message].include?("No outgoing connections") }

    assert dead_end_issue[:fixable]
    # Was connect_next. This issue now also stands in for terminal-not-Resolve,
    # so its Fix has to work when there is no next step to connect to —
    # connect_next answers that case with "No next step to connect to", while
    # add_resolve_after reuses an existing Resolve or creates one.
    assert_equal "add_resolve_after", dead_end_issue[:fix_type]
  end

  test "terminal non-resolve step gets error with add_resolve_after fix" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    a = Steps::Action.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Do thing"
    )
    Transition.create!(step: q, target_step: a, position: 0)
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)
    action_issues = result.issues[a.uuid]

    assert_predicate action_issues, :present?
    # The wording moved: a step with no outgoing transitions now reports that
    # single fact rather than also restating it as "terminal step is not a
    # Resolve step" and "has no path to a Resolve step". The contract this test
    # exists for — the terminal step carries an error with a working Fix — is
    # unchanged, so it is asserted on the fix rather than on the old sentence.
    resolve_issue = action_issues.find { |i| i[:fix_type] == "add_resolve_after" }
    assert resolve_issue, "Expected a fixable terminal error on the action step"
    assert_equal :error, resolve_issue[:severity]
    assert resolve_issue[:fixable]
    assert_equal "add_resolve_after", resolve_issue[:fix_type]
  end

  # Regression: step titles are not unique, and the health check used to find a
  # step by matching the validator's English error message back to a title. Two
  # steps sharing a title meant the issue — and its Fix button — could attach to
  # the wrong one.
  test "duplicate step titles attach the terminal error to the correct step" do
    first = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Check account status", question: "What?", answer_type: "text"
    )
    second = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Check account status", question: "What?", answer_type: "text"
    )
    Transition.create!(step: first, target_step: second, position: 0)
    @workflow.update!(start_step: first)

    result = WorkflowHealthCheck.call(@workflow.reload)

    terminal_issue = lambda do |uuid|
      Array(result.issues[uuid]).find { |i| i[:fix_type] == "add_resolve_after" }
    end

    assert terminal_issue.call(second.uuid),
           "Expected the terminal-not-Resolve error on the dead-end step, got issues: #{result.issues.inspect}"
    assert_nil terminal_issue.call(first.uuid),
               "The first step has an outgoing transition and is not terminal — it must not carry the fix"
  end

  test "empty workflow returns clean result" do
    result = WorkflowHealthCheck.call(@workflow)

    assert_predicate result, :clean?
  end

  test "question without title gets warning" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "", question: "What?", answer_type: "text"
    )
    r = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: q, target_step: r, position: 0)
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)
    step_issues = result.issues[q.uuid]

    assert(step_issues.any? { |i| i[:message].include?("Question text is required") })
  end

  test "summary counts errors and warnings separately" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "", question: "What?", answer_type: "text"
    )
    a = Steps::Action.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Do thing"
    )
    Transition.create!(step: q, target_step: a, position: 0)
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)

    assert_operator result.summary[:total], :>, 0
    assert_equal result.summary[:errors] + result.summary[:warnings], result.summary[:total]
  end

  test "resolve step with no transitions does not get dead-end warning" do
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    r = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: q, target_step: r, position: 0)
    @workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(@workflow.reload)

    # Resolve steps are excluded from the dead-end check
    resolve_issues = result.issues[r.uuid]
    if resolve_issues
      assert_not(resolve_issues.any? { |i| i[:message].include?("No outgoing connections") })
    end
  end

  test "subflow step without target workflow gets warning" do
    # Create a valid graph first so the workflow can save
    q = Steps::Question.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
      title: "Ask", question: "What?", answer_type: "text"
    )
    r = Steps::Resolve.create!(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
      title: "Done", resolution_type: "success"
    )
    Transition.create!(step: q, target_step: r, position: 0)
    @workflow.update!(start_step: q)

    # Now add a sub-flow step with no target, bypassing workflow validation
    sf = Steps::SubFlow.new(
      workflow: @workflow, uuid: SecureRandom.uuid, position: 2,
      title: "Sub", sub_flow_workflow_id: nil
    )
    sf.save!(validate: false)

    result = WorkflowHealthCheck.call(@workflow.reload)
    step_issues = result.issues[sf.uuid]

    assert(step_issues.any? { |i| i[:message].include?("Sub-flow target is required") })
  end

  test "Result data object supports clean? method" do
    result = WorkflowHealthCheck::Result.new(
      issues: {},
      summary: { errors: 0, warnings: 0, total: 0 }
    )

    assert_predicate result, :clean?
  end

  test "Result data object clean? returns false when issues exist" do
    result = WorkflowHealthCheck::Result.new(
      issues: { "uuid-1" => [{ severity: :error, message: "test" }] },
      summary: { errors: 1, warnings: 0, total: 1 }
    )

    assert_not result.clean?
  end

  # -- Slice 3b: one answer to "can this publish?" -----------------------------

  # WorkflowPublisher blocks on `GraphValidator#valid?`, which is simply
  # "@findings.any?" — the validator has no severity concept, so every finding it
  # produces stops a publish. The health check nonetheless singled out
  # :unreachable_step and called it a warning, so the builder showed a clear
  # Publish button and "Passing: every step can reach a Resolve step", and then
  # publish refused with "Step 'X' is not reachable from the start node".
  test "an unreachable step is an error, because publish refuses on it" do
    user = User.create!(email: "sev-#{SecureRandom.hex(4)}@example.com",
                        password: "password123!", password_confirmation: "password123!", role: "editor")
    workflow = Workflow.create!(title: "Severity Flow", user: user, status: "draft")
    q = Steps::Question.create!(workflow: workflow, position: 0, title: "Ask",
                                question: "What?", answer_type: "text")
    resolve = Steps::Resolve.create!(workflow: workflow, position: 1, title: "Done",
                                     resolution_type: "success")
    orphan = Steps::Resolve.create!(workflow: workflow, position: 2, title: "Stranded",
                                    resolution_type: "success")
    Transition.create!(step: q, target_step: resolve, position: 0)
    workflow.update!(start_step: q)

    result = WorkflowHealthCheck.call(workflow)
    severities = result.issues[orphan.uuid].to_a.pluck(:severity)

    assert_includes severities, :error,
                    "publish refuses on an unreachable step, so the panel must call it an error"

    # And the two really do agree now.
    publish = WorkflowPublisher.publish(workflow, user)

    assert_not publish.success?, "precondition: publish refuses this workflow"
    assert_operator result.summary[:errors], :>, 0,
                    "the health panel must not report a publishable workflow when publish refuses"
  end

  # The structural guard. Not a list of codes to keep in sync — the point is that
  # classify_graph_finding has no per-code severity decision left to drift.
  test "no graph finding is ever classified as a warning" do
    source = Rails.root.join("app/services/workflow_health_check.rb").read
    body = source[/def classify_graph_finding.*?\n  end\n/m]

    assert body, "classify_graph_finding not found"
    assert_no_match(/:warning/, body, <<~MESSAGE)
      classify_graph_finding names :warning.

      Every GraphValidator finding blocks a publish (WorkflowPublisher calls
      valid?, which is "@findings.any?"), so anything softer than :error means
      the builder is telling people a workflow is publishable when it is not.
      Severity belongs to the publisher's behaviour, not to a per-code opinion.
    MESSAGE
  end
end
