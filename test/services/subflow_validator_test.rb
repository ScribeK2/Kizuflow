require "test_helper"

class SubflowValidatorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "subflow-val-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
  end

  test "valid for workflow with no sub-flows" do
    wf = Workflow.create!(title: "No Subflows", user: @user)
    action = Steps::Action.create!(workflow: wf, position: 0, title: "Action 1")
    resolve = Steps::Resolve.create!(workflow: wf, position: 1, title: "Done")
    Transition.create!(step: action, target_step: resolve, position: 0)
    validator = SubflowValidator.new(wf.id)
    assert_predicate validator, :valid?
    assert_empty validator.errors
  end

  test "valid for workflow with non-circular sub-flow" do
    child_wf = Workflow.create!(title: "Child", user: @user, status: "published", is_public: true)
    Steps::Action.create!(workflow: child_wf, position: 0, title: "Child Action")
    parent_wf = Workflow.create!(title: "Parent", user: @user)
    call_child = Steps::SubFlow.create!(workflow: parent_wf, position: 0, title: "Call Child",
                                        sub_flow_workflow_id: child_wf.id)
    resolve = Steps::Resolve.create!(workflow: parent_wf, position: 1, title: "Done")
    Transition.create!(step: call_child, target_step: resolve, position: 0)
    assert SubflowValidator.valid?(parent_wf.id)
  end

  test "detects simple circular reference A to B to A" do
    wf_a = Workflow.create!(title: "Workflow A", user: @user)
    wf_b = Workflow.create!(title: "Workflow B", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Call B", sub_flow_workflow_id: wf_b.id)
    Steps::SubFlow.create!(workflow: wf_b, position: 0, title: "Call A", sub_flow_workflow_id: wf_a.id)
    validator = SubflowValidator.new(wf_a.id)
    assert_not validator.valid?
    assert(validator.errors.any? { |e| e.include?("Circular sub-flow reference") })
  end

  test "detects chain circular reference A to B to C to A" do
    wf_a = Workflow.create!(title: "WF A", user: @user)
    wf_b = Workflow.create!(title: "WF B", user: @user)
    wf_c = Workflow.create!(title: "WF C", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Call B", sub_flow_workflow_id: wf_b.id)
    Steps::SubFlow.create!(workflow: wf_b, position: 0, title: "Call C", sub_flow_workflow_id: wf_c.id)
    Steps::SubFlow.create!(workflow: wf_c, position: 0, title: "Call A", sub_flow_workflow_id: wf_a.id)
    validator = SubflowValidator.new(wf_a.id)
    assert_not validator.valid?
    assert(validator.errors.any? { |e| e.include?("Circular sub-flow reference") })
  end

  test "reports non-existent target workflow" do
    wf = Workflow.create!(title: "Missing Target", user: @user)
    # Bypass model validations to insert a sub-flow step pointing to a non-existent workflow.
    # Must supply a UUID manually because before_validation is skipped with validate: false.
    step = Steps::SubFlow.new(workflow: wf, position: 0, title: "Call Ghost",
                              sub_flow_workflow_id: 999_999, uuid: SecureRandom.uuid)
    step.save(validate: false)
    validator = SubflowValidator.new(wf.id)
    assert_not validator.valid?
    assert(validator.errors.any? { |e| e.include?("non-existent workflow") })
  end

  test "detects exceeding MAX_DEPTH" do
    workflows = Array.new(12) { |i| Workflow.create!(title: "Depth #{i}", user: @user) }
    workflows.each_cons(2) do |parent, child|
      Steps::SubFlow.create!(workflow: parent, position: 0, title: "Call Next", sub_flow_workflow_id: child.id)
    end
    Steps::Action.create!(workflow: workflows.last, position: 0, title: "End")
    validator = SubflowValidator.new(workflows.first.id)
    assert_not validator.valid?
    assert(validator.errors.any? { |e| e.include?("maximum depth") })
  end

  test "detects self-reference" do
    wf = Workflow.create!(title: "Self Ref", user: @user, status: "published")
    step = Steps::SubFlow.new(workflow: wf, position: 0, title: "Run self",
                              sub_flow_workflow_id: wf.id, uuid: SecureRandom.uuid)
    step.save(validate: false)
    validator = SubflowValidator.new(wf.id)
    assert_not validator.valid?
    assert(validator.errors.any? { |e| e.include?("Circular") })
  end

  test "class methods valid? and errors_for work" do
    wf = Workflow.create!(title: "Class Method Test", user: @user)
    action = Steps::Action.create!(workflow: wf, position: 0, title: "A1")
    resolve = Steps::Resolve.create!(workflow: wf, position: 1, title: "Done")
    Transition.create!(step: action, target_step: resolve, position: 0)
    assert SubflowValidator.valid?(wf.id)
    assert_empty SubflowValidator.errors_for(wf.id)
  end

  # ---------------------------------------------------------------------------
  # Findings — the structured half. The #errors assertions above prove the
  # message text is unchanged; these prove the code and details a consumer
  # switches on, so WorkflowHealthCheck never has to regex the sentence.
  # ---------------------------------------------------------------------------

  test "errors is exactly the messages of findings, in order" do
    wf_a = Workflow.create!(title: "Workflow A", user: @user)
    wf_b = Workflow.create!(title: "Workflow B", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Call B", sub_flow_workflow_id: wf_b.id)
    step = Steps::SubFlow.new(workflow: wf_b, position: 0, title: "Call A",
                              sub_flow_workflow_id: wf_a.id, uuid: SecureRandom.uuid)
    step.save(validate: false)

    validator = SubflowValidator.new(wf_a.id)

    assert_not validator.valid?
    assert_equal validator.findings.map(&:message), validator.errors
  end

  test "circular_subflow finding carries the workflow ids in the cycle" do
    wf_a = Workflow.create!(title: "Workflow A", user: @user)
    wf_b = Workflow.create!(title: "Workflow B", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Call B", sub_flow_workflow_id: wf_b.id)
    step = Steps::SubFlow.new(workflow: wf_b, position: 0, title: "Call A",
                              sub_flow_workflow_id: wf_a.id, uuid: SecureRandom.uuid)
    step.save(validate: false)

    validator = SubflowValidator.new(wf_a.id)
    validator.valid?
    finding = validator.findings.find { |f| f.code == :circular_subflow }

    assert finding, "Expected circular_subflow, got: #{validator.findings.map(&:code).inspect}"
    assert_includes finding.details[:cycle_workflow_ids], wf_a.id
    assert_includes finding.details[:cycle_workflow_ids], wf_b.id
  end

  test "subflow_target_missing finding carries the missing workflow id" do
    wf = Workflow.create!(title: "Missing Target", user: @user)
    step = Steps::SubFlow.new(workflow: wf, position: 0, title: "Call Ghost",
                              sub_flow_workflow_id: 999_999, uuid: SecureRandom.uuid)
    step.save(validate: false)

    validator = SubflowValidator.new(wf.id)
    validator.valid?
    finding = validator.findings.find { |f| f.code == :subflow_target_missing }

    assert finding
    assert_equal 999_999, finding.details[:target_workflow_id]
    assert_equal wf.id, finding.details[:workflow_id]
  end

  test "max_depth_exceeded finding carries the depth it reached" do
    workflows = Array.new(12) { |i| Workflow.create!(title: "Depth #{i}", user: @user) }
    workflows.each_cons(2) do |parent, child|
      Steps::SubFlow.create!(workflow: parent, position: 0, title: "Call Next", sub_flow_workflow_id: child.id)
    end
    Steps::Action.create!(workflow: workflows.last, position: 0, title: "End")

    validator = SubflowValidator.new(workflows.first.id)
    validator.valid?
    finding = validator.findings.find { |f| f.code == :max_depth_exceeded }

    assert finding
    assert_equal SubflowValidator::MAX_DEPTH, finding.details[:max_depth]
    assert_operator finding.details[:depth], :>, SubflowValidator::MAX_DEPTH
  end
  # A fan-out DAG with NO cycle: workflow i references every j > i.
  #
  # Before the three-colour fix this enumerated every simple path, so a graph a
  # single import can now build took minutes and then hours: measured 0.7s at 8
  # workflows, 4.3s at 12, 16s at 14, 61s at 16 - roughly doubling per workflow,
  # inside the import's open write transaction and again on every later save.
  # A wall-clock bound is a blunt assertion, but it is the only kind that fails
  # on a complexity regression; correctness alone cannot see this.
  test "a fan-out graph validates in linear time, not by enumerating every path" do
    user = User.create!(email: "fanout-#{SecureRandom.hex(4)}@example.com",
                        password: "password123456", role: "editor")
    n = 16
    flows = (0...n).map do |i|
      wf = user.workflows.create!(title: "Fan #{i}", status: "draft")
      Steps::Resolve.create!(workflow: wf, position: 0, title: "Done", resolution_type: "success")
      wf
    end
    flows.each_with_index do |wf, i|
      ((i + 1)...n).each_with_index do |j, k|
        Steps::SubFlow.create!(workflow: wf, position: k + 1, title: "To #{j}",
                               sub_flow_workflow_id: flows[j].id)
      end
    end

    validator = SubflowValidator.new(flows.first.id)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    validator.valid?
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    # Depth 16 legitimately exceeds MAX_DEPTH; what must NOT appear is a cycle,
    # because there isn't one. The point of the test is the clock.
    assert_empty validator.findings.select { |f| f.code == :circular_subflow },
                 "a fan-out DAG has no cycle"

    assert_operator elapsed, :<, 5.0,
                    "#{n} workflows took #{elapsed.round(1)}s - the traversal is exponential again"
  ensure
    Workflow.where(user: user).destroy_all if user
    user&.destroy
  end
  # The shape three-colour DFS could plausibly break.
  #
  # D is reachable from the root by two routes (via B and via C), and the cycle
  # exists only through the second one. If a node were marked black too eagerly,
  # the walk would skip the subtree on its second visit and never find the back
  # edge. Black must mean "this subtree is proven acyclic", not "seen once".
  test "a cycle reachable by only one of several routes is still found" do
    user = User.create!(email: "twoway-#{SecureRandom.hex(4)}@example.com",
                        password: "password123456", role: "editor")
    a, b, c, d = %w[A B C D].map do |name|
      wf = user.workflows.create!(title: "TwoWay #{name}", status: "draft")
      Steps::Resolve.create!(workflow: wf, position: 0, title: "Done", resolution_type: "success")
      wf
    end
    link = lambda do |from, to, pos|
      Steps::SubFlow.create!(workflow: from, position: pos, title: "To #{to.title}",
                             sub_flow_workflow_id: to.id)
    end

    link.call(a, b, 1)   # A -> B -> D   (clean route, explored first)
    link.call(b, d, 1)
    link.call(a, c, 2)   # A -> C -> D   (second route into D)
    link.call(c, d, 1)
    link.call(d, c, 2)   # D -> C        (back edge: the cycle is C -> D -> C)

    validator = SubflowValidator.new(a.id)

    assert_not validator.valid?
    assert(validator.findings.any? { |f| f.code == :circular_subflow },
           "the cycle through the second route must still be found: " \
           "#{validator.findings.map(&:code).inspect}")
  ensure
    Workflow.where(user: user).destroy_all if user
    user&.destroy
  end

  test "a diamond with no cycle is still reported clean" do
    user = User.create!(email: "diamond-#{SecureRandom.hex(4)}@example.com",
                        password: "password123456", role: "editor")
    a, b, c, d = %w[A B C D].map do |name|
      wf = user.workflows.create!(title: "Diamond #{name}", status: "draft")
      Steps::Resolve.create!(workflow: wf, position: 0, title: "Done", resolution_type: "success")
      wf
    end
    [[a, b], [a, c], [b, d], [c, d]].each_with_index do |(from, to), i|
      Steps::SubFlow.create!(workflow: from, position: i + 1, title: "To #{to.title}",
                             sub_flow_workflow_id: to.id)
    end

    validator = SubflowValidator.new(a.id)

    assert_predicate validator, :valid?, validator.findings.map(&:message).inspect
  ensure
    Workflow.where(user: user).destroy_all if user
    user&.destroy
  end

  test "a handoff cycle A to B to A is not circular" do
    wf_a = Workflow.create!(title: "HO A", user: @user)
    wf_b = Workflow.create!(title: "HO B", user: @user)
    Steps::Resolve.create!(workflow: wf_a, position: 0, title: "A done")
    Steps::Resolve.create!(workflow: wf_b, position: 0, title: "B done")
    Steps::SubFlow.create!(workflow: wf_a, position: 1, title: "Hand to B",
                           sub_flow_workflow_id: wf_b.id, sub_flow_returns: false)
    Steps::SubFlow.create!(workflow: wf_b, position: 1, title: "Hand to A",
                           sub_flow_workflow_id: wf_a.id, sub_flow_returns: false)
    validator = SubflowValidator.new(wf_a.id)
    assert_predicate validator, :valid?, validator.errors.join(" | ")
  end

  test "a mixed cycle (returning then handoff) is not circular" do
    wf_a = Workflow.create!(title: "MX A", user: @user)
    wf_b = Workflow.create!(title: "MX B", user: @user)
    Steps::Resolve.create!(workflow: wf_a, position: 0, title: "A done")
    Steps::Resolve.create!(workflow: wf_b, position: 0, title: "B done")
    Steps::SubFlow.create!(workflow: wf_a, position: 1, title: "Call B",
                           sub_flow_workflow_id: wf_b.id, sub_flow_returns: true)
    Steps::SubFlow.create!(workflow: wf_b, position: 1, title: "Hand to A",
                           sub_flow_workflow_id: wf_a.id, sub_flow_returns: false)
    validator = SubflowValidator.new(wf_a.id)
    assert_predicate validator, :valid?, validator.errors.join(" | ")
  end

  test "refuses a handoff pair with no reachable Resolve" do
    wf_a = Workflow.create!(title: "Trap A", user: @user)
    wf_b = Workflow.create!(title: "Trap B", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Hand to B",
                           sub_flow_workflow_id: wf_b.id, sub_flow_returns: false)
    Steps::SubFlow.create!(workflow: wf_b, position: 0, title: "Hand to A",
                           sub_flow_workflow_id: wf_a.id, sub_flow_returns: false)
    validator = SubflowValidator.new(wf_a.id)
    assert_not validator.valid?
    assert(validator.findings.any? { |f| f.code == :no_resolve_across_workflows })
  end

  test "accepts a handoff cycle when one workflow reaches a Resolve" do
    wf_a = Workflow.create!(title: "Esc A", user: @user)
    wf_b = Workflow.create!(title: "Esc B", user: @user)
    Steps::Resolve.create!(workflow: wf_b, position: 0, title: "B done")
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Hand to B",
                           sub_flow_workflow_id: wf_b.id, sub_flow_returns: false)
    Steps::SubFlow.create!(workflow: wf_b, position: 1, title: "Hand to A",
                           sub_flow_workflow_id: wf_a.id, sub_flow_returns: false)
    validator = SubflowValidator.new(wf_a.id)
    assert_predicate validator, :valid?, validator.errors.join(" | ")
  end

  test "the new finding does not block a save" do
    wf_a = Workflow.create!(title: "NoBlock A", user: @user)
    wf_b = Workflow.create!(title: "NoBlock B", user: @user)
    Steps::SubFlow.create!(workflow: wf_a, position: 0, title: "Hand to B",
                           sub_flow_workflow_id: wf_b.id, sub_flow_returns: false)
    Steps::SubFlow.create!(workflow: wf_b, position: 0, title: "Hand to A",
                           sub_flow_workflow_id: wf_a.id, sub_flow_returns: false)
    wf_a.reload.title = "Renamed while half-built"
    assert wf_a.save, "Errors: #{wf_a.errors.full_messages.join(' | ')}"
  end
end
