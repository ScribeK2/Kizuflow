require "test_helper"

# A set of linked workflows imported as one file.
#
# The chicken-and-egg this removes: a sub_flow target had to name a workflow that
# already existed AND was published, and every import lands as a draft. So a
# five-workflow domain took nine operations in an order the operator had to work
# out — and the file an agent generates for it was invalid until four publish
# clicks had happened.
class WorkflowImporterBundleTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "bundle-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
  end

  # --- helpers -----------------------------------------------------------------

  def workflow(title, steps:, **extra)
    { title: title, steps: steps }.merge(extra)
  end

  def resolve_step(id = "done")
    { id: id, type: "resolve", title: "Done", resolution_type: "success" }
  end

  def sub_flow_step(id, target_title, next_id)
    { id: id, type: "sub_flow", title: "Run #{target_title}",
      target_workflow_title: target_title,
      transitions: [{ target_id: next_id }] }
  end

  def handoff_step(id, target_title)
    { id: id, type: "sub_flow", title: "Hand to #{target_title}",
      target_workflow_title: target_title, sub_flow_returns: false }
  end

  # One workflow in a mutually-routing mesh: a question that either hands off
  # to another workflow in the mesh or resolves right here.
  def mesh_workflow(title, handoff_target:, prefix:)
    workflow(title, steps: [
               { id: "#{prefix}1", type: "question", title: "Route it?",
                 question: "Should this go to #{handoff_target}?", answer_type: "yes_no",
                 variable_name: "#{prefix}_route",
                 transitions: [{ target_id: "#{prefix}2", condition: "#{prefix}_route == 'yes'" },
                               { target_id: "#{prefix}3" }] },
               handoff_step("#{prefix}2", handoff_target),
               resolve_step("#{prefix}3")
             ])
  end

  def import(document)
    content = document.to_json
    report = StrictImportValidator.new(user: @user, content:).validate
    [report, report.valid? ? WorkflowImporter.new(@user, format: :json, content:, strict_report: report).call : nil]
  end

  def linked_pair
    {
      schema_version: "1",
      workflows: [
        workflow("Bundle Router", steps: [
                   sub_flow_step("run-child", "Bundle Child", "done"),
                   resolve_step
                 ]),
        workflow("Bundle Child", steps: [resolve_step("child-done")])
      ]
    }
  end

  # --- the accepting path ------------------------------------------------------

  test "a two-workflow file imports both workflows in one call" do
    report, result = import(linked_pair)

    assert_predicate report, :valid?, report.errors.inspect
    assert_predicate result, :success?
    assert_equal 2, result.workflows.size
    assert_predicate result, :multiple?
    assert_equal ["Bundle Router", "Bundle Child"], result.workflows.map(&:title)
    assert(result.workflows.all? { |w| w.status == "draft" }, "an import lands as a draft")
  end

  test "a sub_flow naming a workflow in the same file binds to it" do
    _report, result = import(linked_pair)

    router, child = result.workflows
    sub_flow = router.steps.find { |s| s.step_type == "sub_flow" }

    assert_equal child.id, sub_flow.sub_flow_workflow_id,
                 "the target is the workflow that arrived alongside it, not a published one"
  end

  test "an in-bundle target needs nothing to exist beforehand" do
    assert_equal 0, Workflow.where(title: "Bundle Child").count

    report, result = import(linked_pair)

    assert_predicate report, :valid?,
                     "this is the file that used to fail with unknown_sub_flow_target"
    assert_predicate result, :success?
  end

  test "imported bundle workflows carry no draft expiry" do
    _report, result = import(linked_pair)

    assert(result.workflows.all? { |w| w.draft_expires_at.nil? },
           "an imported workflow is not an abandoned draft and must not be swept")
  end

  # --- resolution precedence ---------------------------------------------------

  test "a workflow in the file wins over a published one with the same title" do
    published = @user.workflows.create!(title: "Bundle Child", status: "published")

    _report, result = import(linked_pair)
    router, child = result.workflows
    sub_flow = router.steps.find { |s| s.step_type == "sub_flow" }

    assert_equal child.id, sub_flow.sub_flow_workflow_id
    assert_not_equal published.id, sub_flow.sub_flow_workflow_id,
                     "the file in front of you is the more specific intent"
  end

  test "a target outside the bundle still resolves to a published workflow" do
    outside = @user.workflows.create!(title: "Already Published", status: "published")

    router = workflow("Bundle Router",
                      steps: [sub_flow_step("run-outside", "Already Published", "done"), resolve_step])
    child = workflow("Bundle Child", steps: [resolve_step("child-done")])
    _report, result = import(schema_version: "1", workflows: [router, child])

    sub_flow = result.workflows.first.steps.find { |s| s.step_type == "sub_flow" }
    assert_equal outside.id, sub_flow.sub_flow_workflow_id
  end

  # --- refusals ----------------------------------------------------------------

  test "a circular bundle is refused and writes nothing" do
    before = Workflow.count

    a = workflow("Cycle A", steps: [sub_flow_step("to-b", "Cycle B", "done"), resolve_step])
    b = workflow("Cycle B", steps: [sub_flow_step("to-a", "Cycle A", "done"), resolve_step])
    report, result = import(schema_version: "1", workflows: [a, b])

    assert_predicate report, :valid?, "the cycle is a runtime shape, not a file-shape error"
    assert_not result.success?, "but it must not be written"
    assert_equal before, Workflow.count, "the whole bundle rolls back, not just the second half"
    assert_predicate result.errors.grep(/circular/i), :any?,
                     "the refusal must name the cycle: #{result.errors.inspect}"
  end

  test "an over-long title in the second workflow is refused before anything is written" do
    before = Workflow.count

    good = workflow("Good One", steps: [resolve_step])
    too_long = workflow("x" * 300, steps: [resolve_step("d2")])
    report, result = import(schema_version: "1", workflows: [good, too_long])

    assert_not report.valid?
    assert_equal "invalid_workflow_title", report.errors.first[:code]
    assert_equal "workflows[1].title", report.errors.first[:path],
                 "the index has to name the offending workflow, not always the first"
    assert_nil result, "the importer is never reached"
    assert_equal before, Workflow.count
  end

  # The save-failure branch is unreachable through validation — Workflow only
  # validates title presence and length, and the validator checks both first. It
  # still has to work: without it a failed save would return a success Result
  # carrying unsaved records. Stubbed rather than left untested.
  test "a workflow that fails to save rolls back the whole set" do
    before = Workflow.count
    original = Workflow.instance_method(:save)

    begin
      Workflow.define_method(:save) do |*args, **kwargs|
        next false if title == "Poison Pill"

        original.bind_call(self, *args, **kwargs)
      end

      good = workflow("Good One", steps: [resolve_step])
      poison = workflow("Poison Pill", steps: [resolve_step("d2")])
      _report, result = import(schema_version: "1", workflows: [good, poison])

      assert_not result.success?, "a failed save must not report success"
      assert_equal before, Workflow.count, "half an imported set is worse than none"
      assert_empty Workflow.where(title: "Good One"),
                   "the workflow that saved fine is rolled back with the one that did not"
    ensure
      Workflow.define_method(:save, original)
    end
  end

  # A chain longer than SubflowValidator::MAX_DEPTH (10) is refused, and this
  # test once asserted the opposite.
  #
  # The reasoning for letting it through: MAX_WORKFLOWS_PER_FILE is 25, so
  # refusing on depth looked like refusing a file the envelope explicitly
  # allows, and WorkflowHealthCheck files max_depth_exceeded as a :warning. What
  # that missed is `Workflow#validate_subflow_circular_references`, which copies
  # every SubflowValidator error onto the record on *every save*. So the
  # imported chain was not a draft carrying a warning — it was fifteen
  # workflows that could never be saved or published again, with no fix
  # available from the builder and nothing saying why. The health check's
  # severity is the inconsistency; the model validation is the policy.
  #
  # What was genuinely wrong before was the message, which called a chain a
  # circular reference. That is what this now pins.
  test "a sub-flow chain deeper than MAX_DEPTH is refused, and not as a cycle" do
    depth = SubflowValidator::MAX_DEPTH + 5
    chain = (0...depth).map do |i|
      steps = []
      steps << sub_flow_step("go", "Chain #{i + 1}", "done") if i < depth - 1
      steps << resolve_step
      workflow("Chain #{i}", steps: steps)
    end

    report, result = import(schema_version: "1", workflows: chain)

    assert_predicate report, :valid?, "the file is structurally fine; depth is a graph question"
    assert_not result.success?
    assert_equal 0, @user.workflows.where(title: "Chain 0").count, "the whole bundle rolls back"

    message = result.errors.join(" ")
    assert_match(/#{depth} levels deep/, message)
    assert_match(/chain, not a cycle/, message)
    assert_no_match(/Circular/i, message, "a chain is not a cycle, and saying so sent the last fix the wrong way")
  end

  # A chain exactly at the limit is the other side of that boundary.
  test "a sub-flow chain exactly at MAX_DEPTH imports" do
    depth = SubflowValidator::MAX_DEPTH
    chain = (0...depth).map do |i|
      steps = []
      steps << sub_flow_step("go", "Edge #{i + 1}", "done") if i < depth - 1
      steps << resolve_step
      workflow("Edge #{i}", steps: steps)
    end

    _report, result = import(schema_version: "1", workflows: chain)

    assert_predicate result, :success?, result&.errors.inspect
    assert_equal depth, result.workflows.size
  end

  test "a file at the maximum workflow count imports" do
    at_limit = Array.new(ImportSchemaGenerator::MAX_WORKFLOWS_PER_FILE) do |i|
      workflow("Limit #{i}", steps: [resolve_step])
    end

    _report, result = import(schema_version: "1", workflows: at_limit)

    assert_predicate result, :success?
    assert_equal ImportSchemaGenerator::MAX_WORKFLOWS_PER_FILE, result.workflows.size
  end

  # --- placement stays index-aligned -------------------------------------------

  test "each workflow gets its own groups and tags, not the first one's" do
    group = Group.create!(name: "Bundle Group #{SecureRandom.hex(3)}")
    UserGroup.create!(user: @user, group: group)

    router = workflow("Tagged Router", steps: [resolve_step], tags: ["router-tag"])
    child = workflow("Tagged Child", steps: [resolve_step("d2")], tags: ["child-tag"],
                                     groups: [group.name])
    _report, result = import(schema_version: "1", workflows: [router, child])

    router, child = result.workflows

    assert_equal ["router-tag"], router.tags.map(&:name)
    assert_equal ["child-tag"], child.tags.map(&:name)
    assert_empty router.groups, "the router declared no group and must not inherit one"
    assert_equal [group.id], child.groups.map(&:id)
  end

  # --- what happens to a bundle AFTER it lands ---------------------------------
  #
  # Every assertion above this point stops at `result.success?`. That is how a
  # bundle shipped whose workflows imported cleanly and then refused every
  # subsequent save: a file's workflows reference each other and all land as
  # drafts, and `Workflow#validate_subflow_steps` demanded a published target on
  # every save. The import was never the whole story.

  test "an imported bundle workflow can still be saved" do
    _report, result = import(linked_pair)
    router = result.workflows.find { |w| w.title == "Bundle Router" }

    router.title = "Bundle Router Renamed"

    assert router.save,
           "a draft may reference a draft; requiring publish on save made every imported bundle read-only: " \
           "#{router.errors.full_messages.inspect}"
  end

  test "the health panel says the target is still a draft, rather than reading clean" do
    _report, result = import(linked_pair)
    router = result.workflows.find { |w| w.title == "Bundle Router" }
    sub_flow = router.steps.find { |s| s.is_a?(Steps::SubFlow) }

    issues = WorkflowHealthCheck.new(router).call.issues[sub_flow.uuid] || []
    codes = issues.pluck(:code)

    assert_includes codes, :subflow_target_unpublished,
                    "publishing a bundle is leaf-first, and this is the only thing that says so"
    assert_equal [:warning], issues.select { |i| i[:code] == :subflow_target_unpublished }.pluck(:severity).uniq,
                 "an unpublished target blocks publish, not saving or running"
  end

  test "publishing a bundle is leaf-first, and the parent says why when it is not" do
    _report, result = import(linked_pair)
    router = result.workflows.find { |w| w.title == "Bundle Router" }
    child = result.workflows.find { |w| w.title == "Bundle Child" }
    [router, child].each { file_in_global(it) }

    parent_first = WorkflowPublisher.new(router, @user).publish

    assert_nil parent_first.version, "the child is still a draft"
    assert_match(/not published/, parent_first.error.to_s)

    assert WorkflowPublisher.new(child.reload, @user).publish.version, "the leaf has no sub-flow of its own"
    assert WorkflowPublisher.new(router.reload, @user).publish.version,
           "and now the parent goes: #{WorkflowPublisher.new(router.reload, @user).publish.error.inspect}"
  end

  # --- the single-workflow case is unchanged -----------------------------------

  test "a one-workflow file still behaves exactly as before" do
    _report, result = import({
                               schema_version: "1",
                               workflows: [workflow("Solo", steps: [resolve_step])]
                             })

    assert_predicate result, :success?
    assert_not result.multiple?
    assert_equal 1, result.workflows.size
    assert_equal "Solo", result.workflow.title, "the singular reader still points at it"
  end

  # --- refusing an unescapable bundle -------------------------------------------

  test "refuses a bundle whose workflows can never reach a Resolve" do
    document = {
      schema_version: "1",
      workflows: [
        workflow("Loop A", steps: [handoff_step("a1", "Loop B")]),
        workflow("Loop B", steps: [handoff_step("b1", "Loop A")])
      ]
    }

    assert_no_difference "Workflow.count" do
      report, result = import(document)
      assert_predicate report, :valid?, "structurally legal; only the graph is not"
      assert_not result.success?
      assert(result.errors.any? { |e| e.include?("never reaches a Resolve step") })
    end
  end

  # --- the shape that started this: a mutually-routing handoff mesh ------------
  #
  # A and B hand off to each other, C and D hand off to each other, and every
  # one of the four has its own reachable Resolve. This is the four-workflow
  # analog of the real 24-workflow call-centre bundle that was refused before
  # SubflowValidator learned to tell an unescapable cycle from an escapable
  # one.

  test "imports a mutually-routing handoff mesh where every workflow can resolve" do
    document = {
      schema_version: "1",
      workflows: [
        mesh_workflow("Mesh A", handoff_target: "Mesh B", prefix: "a"),
        mesh_workflow("Mesh B", handoff_target: "Mesh A", prefix: "b"),
        mesh_workflow("Mesh C", handoff_target: "Mesh D", prefix: "c"),
        mesh_workflow("Mesh D", handoff_target: "Mesh C", prefix: "d")
      ]
    }

    assert_difference "Workflow.count", 4 do
      report, result = import(document)
      assert_predicate report, :valid?, report.errors.inspect
      assert_predicate result, :success?, result&.errors.inspect
    end
  end

  # There is deliberately no "each workflow in the mesh publishes" test here.
  # A mutual handoff mesh imports and saves fine, but cannot currently be
  # published at all: `Workflow#validate_subflow_steps` requires a sub_flow
  # step's target to already be published, with no exemption for a handoff
  # (`sub_flow_returns: false`), so A needs B published first and B needs A
  # published first — no order satisfies that for a cycle. Whether a handoff
  # should be exempt from that rule (an agent could then be handed into a
  # still-draft workflow mid-call) or the mesh should publish as one atomic
  # set is an open product question, not settled here. Do not add a test
  # asserting the current deadlock as intended behaviour.
end
