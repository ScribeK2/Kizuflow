require "test_helper"

class WorkflowValidationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "wf-validation-#{SecureRandom.hex(4)}@example.com", password: "password123456")
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_workflow(title, status: "published", **attrs)
    Workflow.create!(title: title, user: @user, status: status, **attrs)
  end

  def add_question(workflow, title, position:, variable_name: nil)
    Steps::Question.create!(
      workflow: workflow,
      title: title,
      position: position,
      question: "#{title}?",
      variable_name: variable_name || title.parameterize(separator: "_")
    )
  end

  def add_resolve(workflow, title, position:)
    Steps::Resolve.create!(workflow: workflow, title: title, position: position, resolution_type: "success")
  end

  def add_subflow(workflow, title, position:, target_workflow:)
    Steps::SubFlow.create!(
      workflow: workflow,
      title: title,
      position: position,
      sub_flow_workflow_id: target_workflow.id
    )
  end

  def link(from_step, to_step, condition: nil, position: 0)
    Transition.create!(step: from_step, target_step: to_step, condition: condition, position: position)
  end

  # ---------------------------------------------------------------------------
  # Basic validations
  # ---------------------------------------------------------------------------

  test "requires title" do
    wf = Workflow.new(user: @user, status: "published")
    assert_not wf.valid?
    assert_includes wf.errors[:title], "can't be blank"
  end

  test "requires user" do
    wf = Workflow.new(title: "No user", status: "published")
    assert_not wf.valid?
    assert_includes wf.errors[:user], "must exist"
  end

  test "title length max 255" do
    wf = Workflow.new(title: "x" * 256, user: @user, status: "published")
    assert_not wf.valid?
    assert(wf.errors[:title].any? { |e| e.include?("too long") })
  end

  # ---------------------------------------------------------------------------
  # Draft mode allows incomplete workflow
  # ---------------------------------------------------------------------------

  test "draft with no steps is valid" do
    wf = Workflow.new(title: "Empty Draft", user: @user, status: "draft")
    assert_predicate wf, :valid?, "Draft with no steps should be valid: #{wf.errors.full_messages.join(', ')}"
  end

  test "draft skips graph structure validation" do
    wf = create_workflow("Draft WF", status: "draft")
    # Add a question step with no transitions (orphan) — no resolve either
    add_question(wf, "Floating Q", position: 0)

    # Re-save — should not error because draft skips graph validation
    wf.reload
    assert_predicate wf, :valid?, "Draft should skip graph validation: #{wf.errors.full_messages.join(', ')}"
  end

  # ---------------------------------------------------------------------------
  # Optimistic locking
  # ---------------------------------------------------------------------------

  test "stale lock_version raises StaleObjectError" do
    wf = create_workflow("Lockable")

    # Simulate concurrent edit
    stale = Workflow.find(wf.id)
    wf.update!(title: "Updated by first editor")

    assert_raises ActiveRecord::StaleObjectError do
      stale.update!(title: "Updated by second editor")
    end
  end

  # ---------------------------------------------------------------------------
  # Graph validation on publish
  # ---------------------------------------------------------------------------

  test "a disconnected graph is invalid while publishing" do
    wf = create_workflow("Graph Validation", status: "draft")
    q = add_question(wf, "Start", position: 0)
    add_resolve(wf, "End", position: 1)
    # No transition linking q -> r — they are disconnected
    wf.update!(start_step: q)

    wf.while_publishing do
      assert_not wf.valid?, "Disconnected graph should be invalid"
      assert_predicate wf.errors[:steps], :any?, "Should have step errors for disconnected graph"
    end
    assert_predicate wf, :valid?, "outside a publish the same draft saves"
  end

  test "published workflow with connected graph is valid" do
    wf = create_workflow("Valid Graph")
    q = add_question(wf, "Start", position: 0)
    r = add_resolve(wf, "End", position: 1)
    link(q, r)
    wf.update!(start_step: q)

    wf.reload
    assert_predicate wf, :valid?, "Connected graph should be valid: #{wf.errors.full_messages.join(', ')}"
  end

  # A live workflow is edited in place, so between publishes it is as half-built
  # as a draft, and its title and Details must still save. Keying the graph
  # check on published? refused them; the runner reads live steps and a step
  # save never validates the workflow, so the refusal protected no run.
  test "a published workflow with an unconnected step still saves" do
    wf = create_workflow("Live Edit")
    q = add_question(wf, "Start", position: 0)
    r = add_resolve(wf, "End", position: 1)
    link(q, r)
    wf.update!(start_step: q)
    add_question(wf, "Half-added", position: 2)

    wf.reload.title = "Live Edit renamed"
    assert_predicate wf, :valid?, wf.errors.full_messages.join(", ")
  end

  # ---------------------------------------------------------------------------
  # SubFlow validations
  # ---------------------------------------------------------------------------

  # A Sub-Flow added from the step picker has no target yet. Refusing every
  # workflow save until one was picked lost renames and Details edits.
  test "a workflow with an untargeted sub-flow saves" do
    wf = create_workflow("Untargeted", status: "draft")
    Steps::SubFlow.create!(workflow: wf, title: "Hand to billing", position: 0)

    wf.reload.title = "Untargeted renamed"
    assert_predicate wf, :valid?, wf.errors.full_messages.join(", ")
  end

  test "an untargeted sub-flow is refused while publishing" do
    wf = create_workflow("Untargeted Publish", status: "draft")
    Steps::SubFlow.create!(workflow: wf, title: "Hand to billing", position: 0)

    wf.reload.while_publishing do
      assert_not wf.valid?
      assert(wf.errors[:steps].any? { |e| e.include?("requires a target workflow") },
             "expected a blank-target error, got #{wf.errors[:steps].inspect}")
    end
  end

  # The messages said "Step #{position + 1}", and builder steps start at
  # position 1, so a workflow's only step was called "Step 2".
  test "sub-flow errors name the step by its title" do
    wf = create_workflow("Named", status: "draft")
    Steps::SubFlow.create!(workflow: wf, title: "Hand to billing", position: 1)

    wf.reload.while_publishing { wf.valid? }

    # Quoted the way GraphValidator names a step ("Step 'X' has no path ...").
    assert_includes wf.errors[:steps], "Sub-flow step 'Hand to billing' requires a target workflow"
    assert(wf.errors[:steps].none? { |e| e.start_with?("Step 2") }, "got #{wf.errors[:steps].join(' | ')}")
  end

  test "subflow step pointing to nonexistent workflow is invalid" do
    wf = create_workflow("SubFlow Missing Target")
    Steps::SubFlow.create!(
      workflow: wf,
      title: "Bad SubFlow",
      position: 0,
      sub_flow_workflow_id: 999_999
    )

    wf.reload
    assert_not wf.valid?
    assert wf.errors[:steps].any? { |e| e.include?("does not exist") },
           "Should report missing target workflow: #{wf.errors[:steps].inspect}"
  end

  test "subflow step cannot reference itself" do
    wf = create_workflow("Self-referencing")
    Steps::SubFlow.create!(
      workflow: wf,
      title: "Self Ref",
      position: 0,
      sub_flow_workflow_id: wf.id
    )

    wf.reload
    assert_not wf.valid?
    assert wf.errors[:steps].any? { |e| e.include?("cannot reference itself") },
           "Should detect self-referencing subflow: #{wf.errors[:steps].inspect}"
  end

  test "circular subflow references are detected" do
    wf_a = create_workflow("WF A")
    wf_b = create_workflow("WF B")

    # A has subflow -> B
    r_a = add_resolve(wf_a, "Resolve A", position: 1)
    sf_a = add_subflow(wf_a, "Call B", position: 0, target_workflow: wf_b)
    link(sf_a, r_a)

    # B has subflow -> A (creating circular reference)
    r_b = add_resolve(wf_b, "Resolve B", position: 1)
    sf_b = add_subflow(wf_b, "Call A", position: 0, target_workflow: wf_a)
    link(sf_b, r_b)

    wf_a.reload
    assert_not wf_a.valid?, "Circular subflow should be invalid"
    assert wf_a.errors[:steps].any? { |e| e.include?("Circular") },
           "Should detect circular subflow: #{wf_a.errors[:steps].inspect}"
  end

  # ---------------------------------------------------------------------------
  # Status enum
  # ---------------------------------------------------------------------------

  test "status defaults to published" do
    wf = Workflow.new(title: "Default Status", user: @user)
    assert_equal "published", wf.status
  end

  test "draft sets expiration" do
    wf = create_workflow("Expiring Draft", status: "draft")
    assert_not_nil wf.draft_expires_at
    assert_operator wf.draft_expires_at, :>, Time.current
  end
end
