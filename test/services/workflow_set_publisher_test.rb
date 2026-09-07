require "test_helper"

class WorkflowSetPublisherTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "setpub-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
  end

  # A workflow that can publish on its own: one Question into a Resolve.
  def resolving_workflow(title, status: "draft")
    wf = Workflow.create!(title: title, user: @user, status: status, graph_mode: true)
    q = Steps::Question.create!(workflow: wf, position: 0, title: "Q", question: "What?",
                                variable_name: "q", answer_type: "text")
    r = Steps::Resolve.create!(workflow: wf, position: 1, title: "Done", resolution_type: "success")
    Transition.create!(step: q, target_step: r, position: 0)
    wf.update!(start_step: q)
    wf
  end

  # Adds a sub_flow step that is REACHABLE FROM THE START and does not orphan the
  # Resolve. Both matter: GraphValidator refuses an unreachable step, and it
  # refuses a step with no path to a Resolve. A helper that just appended the
  # sub_flow step would fail these tests for reasons that have nothing to do
  # with set publishing.
  #
  # Result: Question branches to the sub_flow first, and falls back to Resolve.
  # A returning sub_flow then continues to Resolve; a handoff takes none, because
  # it ends the workflow.
  def link(source, target, returns: true)
    question = source.steps.find_by(type: "Steps::Question")
    resolve  = source.steps.find_by(type: "Steps::Resolve")

    step = Steps::SubFlow.create!(workflow: source, position: source.steps.count,
                                  title: "To #{target.title}", sub_flow_workflow_id: target.id,
                                  sub_flow_returns: returns)

    Transition.find_by(step: question, target_step: resolve).update!(position: 1)
    Transition.create!(step: question, target_step: step, position: 0)
    Transition.create!(step: step, target_step: resolve, position: 0) if returns
    step
  end

  test "a workflow with no sub-flows is a closure of one" do
    wf = resolving_workflow("Alone")
    assert_equal [wf.id], WorkflowSetPublisher.closure_for(wf).map(&:id)
  end

  test "the closure follows a chain of drafts" do
    a = resolving_workflow("Chain A")
    b = resolving_workflow("Chain B")
    c = resolving_workflow("Chain C")
    link(a, b)
    link(b, c)

    assert_equal [a.id, b.id, c.id].sort, WorkflowSetPublisher.closure_for(a).map(&:id).sort
  end

  test "the closure terminates on a cycle" do
    a = resolving_workflow("Cycle A")
    b = resolving_workflow("Cycle B")
    link(a, b, returns: false)
    link(b, a, returns: false)

    assert_equal [a.id, b.id].sort, WorkflowSetPublisher.closure_for(a).map(&:id).sort
  end

  test "a published target stops the walk and is not a member" do
    a = resolving_workflow("Root A")
    published = resolving_workflow("Already Live", status: "published")
    behind = resolving_workflow("Behind The Published One")
    link(published, behind)
    link(a, published)

    ids = WorkflowSetPublisher.closure_for(a).map(&:id)
    assert_includes ids, a.id
    assert_not_includes ids, published.id, "a published target already satisfies the rule"
    assert_not_includes ids, behind.id, "and its own targets were checked when it published"
  end
end
