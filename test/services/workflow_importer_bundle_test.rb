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

  # A chain longer than SubflowValidator::MAX_DEPTH (10) is legal to import.
  # MAX_WORKFLOWS_PER_FILE is 25, so refusing on depth made a file the envelope
  # explicitly allows unimportable — and reported it as a circular reference,
  # which it is not. WorkflowHealthCheck files max_depth_exceeded as a :warning
  # and publish is where depth is enforced; an import lands as a draft.
  test "a sub-flow chain deeper than MAX_DEPTH still imports" do
    depth = SubflowValidator::MAX_DEPTH + 5
    chain = (0...depth).map do |i|
      steps = []
      steps << sub_flow_step("go", "Chain #{i + 1}", "done") if i < depth - 1
      steps << resolve_step
      workflow("Chain #{i}", steps: steps)
    end

    report, result = import(schema_version: "1", workflows: chain)

    assert_predicate report, :valid?, report.errors.inspect
    assert_predicate result, :success?,
                     "depth is a publish-time warning, not an import refusal: #{result.errors.inspect}"
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
end
