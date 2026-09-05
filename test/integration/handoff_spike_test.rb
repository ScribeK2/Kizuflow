require "test_helper"

# SPIKE — not shippable. The regression tests for Wave 2's tail call, written
# BEFORE the tail call exists.
#
# Why they are written first: docs/designs/workflow-handoff.md § "The finding
# that should change how you build this". Three review rounds produced three
# criticals, all of one shape — a reader that infers run structure from
# `parent_scenario_id`/`root_scenario` instead of being told it — and every one
# was found by reading code, never by reasoning about the design. Twice at
# `scenario.rb:314`. So an enumeration of change sites in this subsystem cannot
# be trusted, and the doc's instruction is: write these, then spike, and let the
# failures name the sites.
#
# These will fail on a missing column until the spike migration lands. That is
# intended. The point is that they exist before the change, so a failure cannot
# be re-read afterwards as "not what I meant".
#
# Numbering follows § Success Criteria in the design doc.
class HandoffSpikeTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "handoff-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    sign_in @user
  end

  # --- fixtures ---------------------------------------------------------------

  # A workflow that asks one question and then ends.
  def terminal_workflow(title, question_title:)
    wf = Workflow.create!(title: title, user: @user)
    q = Steps::Question.create!(workflow: wf, position: 0, title: question_title,
                                question: "#{question_title}?", variable_name: "v_#{SecureRandom.hex(2)}")
    r = Steps::Resolve.create!(workflow: wf, position: 1, title: "#{title} Done",
                               resolution_type: "success")
    Transition.create!(step: q, target_step: r, position: 0)
    wf.update!(start_step: q)
    [wf, q, r]
  end

  # A workflow whose last step hands off to `target` instead of returning.
  #
  # `sub_flow_returns: false` is the spike's flag. A handoff step has no
  # transitions — that is what makes it a tail call rather than an edge, and it
  # is also why WorkflowHealthCheck will call it a dead end (SC 8).
  def handing_off_workflow(title, target:, question_title: "First")
    wf = Workflow.create!(title: title, user: @user)
    q = Steps::Question.create!(workflow: wf, position: 0, title: question_title,
                                question: "#{question_title}?", variable_name: "carried")
    ho = Steps::SubFlow.create!(workflow: wf, position: 1, title: "Continue in #{target.title}",
                                sub_flow_workflow_id: target.id, sub_flow_returns: false)
    Transition.create!(step: q, target_step: ho, position: 0)
    wf.update!(start_step: q)
    [wf, q, ho]
  end

  def start_run(workflow, step)
    Scenario.create!(workflow: workflow, user: @user, purpose: "simulation", status: "active",
                     started_at: Time.current, current_node_uuid: step.uuid,
                     execution_path: [], results: {}, inputs: {})
  end

  def answer(scenario, value = "yes")
    post next_step_scenario_path(scenario), params: { answer: value },
                                            headers: { "Accept" => "text/vnd.turbo-stream.html" }
  end

  # --- SC 4a — the run actually moves ----------------------------------------
  #
  # The sharpest of the four. BOTH earlier drafts of this design produced a
  # feature that validated and did nothing: the handoff was recorded and the
  # agent was shown "This run is complete". So this assertion is the one that
  # proves the tail call is a tail call and not an ending with extra bookkeeping.

  test "SC4a: answering the handoff lands on the next workflow's first step in the same POST" do
    target, target_q, = terminal_workflow("Target", question_title: "Second")
    source, source_q, = handing_off_workflow("Source", target: target)
    run = start_run(source, source_q)

    answer(run)

    assert_response :success
    assert_match(/Second/, response.body,
                 "the handed-to workflow's first answerable step has to be on screen, in this response")
    assert_no_match(/run is complete/i, response.body,
                    "a handoff is not an ending — this is the failure both earlier drafts shipped")
    handed_to = Scenario.find_by(workflow: target, user: @user)
    assert_not_nil handed_to, "a run should exist on the target workflow"
    assert_equal target_q.uuid, handed_to.current_node_uuid

    # SPIKE FINDING: everything above this line passes with NO handoff
    # implemented at all, because a non-returning sub_flow still descends like
    # an ordinary one — the run lands on the target's first step as a *child*.
    # So the assertions that actually distinguish a tail call from a call are
    # these, and without them this test would have green-lit a no-op feature.
    # That is the same "validated and did nothing" failure the design doc says
    # both earlier drafts shipped, reproduced here in test form.
    assert_nil handed_to.parent_scenario_id,
               "a handoff is not a call: nobody is waiting to be returned to"
    assert_equal run.id, handed_to.handed_off_from_id,
                 "the target should record where the run came from, not who is waiting for it"
    assert_predicate run.reload, :terminal?,
                     "the source half is finished — it handed the run away and will never resume"
    assert_not_equal "awaiting_subflow", run.status
  end

  # --- SC 4 — the handed-to ending is shown -----------------------------------
  #
  # ScenarioSettler.auto_processable? walks past a resolve when
  # `scenario.parent_scenario_id.present?` — "has a parent means its ending is
  # internal". If the handed-to scenario keeps that FK, its ending is swallowed
  # and the agent never sees the run finish.

  test "SC4: the handed-to workflow's ending is shown, not auto-processed away" do
    target, _tq, target_resolve = terminal_workflow("Target", question_title: "Second")
    source, source_q, = handing_off_workflow("Source", target: target)
    run = start_run(source, source_q)

    answer(run)
    handed_to = Scenario.find_by(workflow: target, user: @user)
    answer(handed_to)

    assert_not ScenarioSettler.auto_processable?(handed_to.reload, target_resolve),
               "the ending of the workflow the agent was handed to is the run's ending, " \
               "not a sub-flow's internal one"
    assert_match(/Target Done/, response.body, "the agent has to see the run finish")
  end

  # --- SC 4b — a GET on the abandoned half goes forward -----------------------
  #
  # Refresh, browser Back, or a bookmark on the handed-off-from scenario. The
  # run no longer lives there. It must not show that half's results as if the
  # run ended in it.

  test "SC4b: a GET on the handed-off-from scenario redirects forward to the live run" do
    target, = terminal_workflow("Target", question_title: "Second")
    source, source_q, = handing_off_workflow("Source", target: target)
    run = start_run(source, source_q)

    answer(run)
    handed_to = Scenario.find_by(workflow: target, user: @user)

    # Same caveat as SC4a: this redirect already happens for an ordinary
    # sub-flow (a parent forwards into its active child), so the assertion only
    # means something once the source is terminal and has no active child.
    assert_predicate run.reload, :terminal?, "precondition: the source half is finished"
    assert_nil run.active_child_scenario, "precondition: there is no child to forward into"

    get step_scenario_path(run)

    assert_redirected_to step_scenario_path(handed_to),
                         "the abandoned half must point forward, not render its own results"
  end

  # --- §N — a handoff inside a sub-flow does not leave the parent resumable ---
  #
  # A → sub-flow B → handoff C. B never returns, so A is not waiting for
  # anything any more. If A stays resumable, the run has two live heads and
  # `process_subflow_completion` can resurrect A from a completed child — the
  # `scenario.rb:314` failure, twice found.

  test "N: A -> sub-flow B -> handoff C must not leave A resumable" do
    c, = terminal_workflow("C", question_title: "Third")
    b, b_q, = handing_off_workflow("B", target: c, question_title: "Second")

    a = Workflow.create!(title: "A", user: @user)
    a_q = Steps::Question.create!(workflow: a, position: 0, title: "First",
                                  question: "First?", variable_name: "av")
    a_sf = Steps::SubFlow.create!(workflow: a, position: 1, title: "Into B",
                                  sub_flow_workflow_id: b.id)
    a_r = Steps::Resolve.create!(workflow: a, position: 2, title: "A Done", resolution_type: "success")
    Transition.create!(step: a_q, target_step: a_sf, position: 0)
    Transition.create!(step: a_sf, target_step: a_r, position: 0)
    a.update!(start_step: a_q)

    run = start_run(a, a_q)
    answer(run)                                    # into B
    b_run = Scenario.find_by(workflow: b, user: @user)
    assert_not_nil b_run, "the sub-flow should have opened"
    assert_equal b_q.uuid, b_run.current_node_uuid

    answer(b_run)                                  # B hands off to C

    assert_not_predicate run.reload, :parked?,
                         "A is not waiting for anything — B handed the run away and will never return"
    assert_not_equal "awaiting_subflow", run.reload.status,
                     "A cannot sit awaiting a sub-flow that has left"
    assert_not_nil Scenario.find_by(workflow: c, user: @user), "the run should now live on C"
  end

  # --- SC 8 — the health panel must not call a handoff a dead end -------------

  test "SC8: the health panel does not offer add_resolve_after on a handoff step" do
    target, = terminal_workflow("Target", question_title: "Second")
    source, _q, handoff = handing_off_workflow("Source", target: target)

    issues = WorkflowHealthCheck.new(source).call.issues[handoff.uuid] || []

    assert_empty issues.select { |i| i[:fix_type] == "add_resolve_after" },
                 "a handoff step ends the workflow on purpose; it is not a dead end to be fixed"
  end

  # --- Wave 1 item 4 — a handoff chain has no stack ---------------------------
  #
  # MAX_DEPTH measures sub-flow *nesting*. A tail call does not nest, so a flat
  # chain of handoffs must not be refused for a depth that does not exist. The
  # import-time refusal was restored in 4ccee4fd, which makes this live.

  # SC 5 — the other half of W1.4, and the one that makes it dangerous to fix
  # carelessly. Depth must stop counting handoff hops; cycle detection must NOT.
  test "SC5: a handoff cycle is still detected" do
    a = Workflow.create!(title: "Cycle A", user: @user)
    b = Workflow.create!(title: "Cycle B", user: @user)
    Steps::SubFlow.create!(workflow: a, position: 0, title: "To B",
                           sub_flow_workflow_id: b.id, sub_flow_returns: false)
    Steps::SubFlow.create!(workflow: b, position: 0, title: "To A",
                           sub_flow_workflow_id: a.id, sub_flow_returns: false)

    validator = SubflowValidator.new(a.id)

    assert_not validator.valid?, "a handoff cycle is still an infinite run"
    assert_predicate validator.findings.select { |f| f.code == :circular_subflow }, :any?,
                     "exempting handoffs from DEPTH must not exempt them from CYCLES"
  end

  test "W1.4: a flat handoff chain longer than MAX_DEPTH is not refused for depth" do
    depth = SubflowValidator::MAX_DEPTH + 3
    workflows = (0...depth).map { |i| Workflow.create!(title: "Hop #{i}", user: @user) }

    workflows.each_with_index do |wf, i|
      if i == depth - 1
        r = Steps::Resolve.create!(workflow: wf, position: 0, title: "End", resolution_type: "success")
        wf.update!(start_step: r)
      else
        ho = Steps::SubFlow.create!(workflow: wf, position: 0, title: "Continue",
                                    sub_flow_workflow_id: workflows[i + 1].id, sub_flow_returns: false)
        wf.update!(start_step: ho)
      end
    end

    validator = SubflowValidator.new(workflows.first.id)
    validator.valid?

    assert_empty validator.findings.select { |f| f.code == :max_depth_exceeded },
                 "a handoff has no stack frame, so a chain of them has no nesting depth to exceed"
  end
end
