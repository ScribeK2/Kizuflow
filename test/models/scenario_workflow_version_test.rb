require "test_helper"

# Which script the agent was actually following.
#
# `scenarios.workflow_version_id`, its index and its foreign key existed and
# nothing ever wrote them — 0 of 120 rows in a dev database. A schema that claims
# to record provenance and does not is the same class of thing as a TERMINAL_STATUSES
# that `terminal?` disagreed with: a claim the database makes and the code ignores.
class ScenarioWorkflowVersionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "prov-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    @workflow = build_publishable("Provenance #{SecureRandom.hex(3)}")
  end

  def build_publishable(title)
    wf = Workflow.create!(title: title, user: @user, graph_mode: true)
    q = Steps::Question.create!(workflow: wf, position: 0, title: "Q1",
                                question: "What?", variable_name: "q_#{SecureRandom.hex(2)}")
    r = Steps::Resolve.create!(workflow: wf, position: 1, title: "Done", resolution_type: "success")
    Transition.create!(step: q, target_step: r, position: 0)
    wf.update!(start_step: q)
    file_in_global(wf)
  end

  def run_on(workflow, **attrs)
    Scenario.create!({ workflow: workflow, user: @user, purpose: "live", status: "active",
                       started_at: Time.current, execution_path: [], results: {},
                       inputs: {} }.merge(attrs))
  end

  test "a run records the version it started against" do
    version = WorkflowPublisher.publish(@workflow, @user).version

    assert_equal version, run_on(@workflow.reload).workflow_version
  end

  test "a run on an unpublished draft records no version" do
    assert_nil run_on(@workflow).workflow_version_id,
               "there is no published version to name, and nil says exactly that"
  end

  test "editing and republishing does not rewrite an earlier run's provenance" do
    first = WorkflowPublisher.publish(@workflow, @user).version
    early_run = run_on(@workflow.reload)

    @workflow.steps.first.update!(question: "What, precisely?")
    second = WorkflowPublisher.publish(@workflow.reload, @user).version
    later_run = run_on(@workflow.reload)

    assert_equal first, early_run.reload.workflow_version
    assert_equal second, later_run.workflow_version
    assert_not_equal early_run.workflow_version, later_run.workflow_version,
                     "this is the point: an outcome that changed mid-quarter is explainable"
  end

  # A child runs a DIFFERENT workflow, which is why this is a model callback
  # rather than an assignment at each Scenario.create! site.
  test "a sub-flow child records its own workflow's version, not its parent's" do
    child_workflow = build_publishable("Child #{SecureRandom.hex(3)}")
    parent_version = WorkflowPublisher.publish(@workflow, @user).version
    child_version  = WorkflowPublisher.publish(child_workflow, @user).version
    parent = run_on(@workflow.reload)

    child = run_on(child_workflow.reload, parent_scenario: parent)

    assert_equal parent_version, parent.workflow_version
    assert_equal child_version, child.workflow_version
  end

  test "an explicitly supplied version is not overwritten" do
    version = WorkflowPublisher.publish(@workflow, @user).version
    other = build_publishable("Other #{SecureRandom.hex(3)}")
    other_version = WorkflowPublisher.publish(other, @user).version

    scenario = run_on(@workflow.reload, workflow_version: other_version)

    assert_equal other_version, scenario.workflow_version, "||= leaves a caller's choice alone"
    assert_not_equal version, scenario.workflow_version
  end

  test "releasing a snapshot leaves the provenance link intact" do
    version = WorkflowPublisher.publish(@workflow, @user).version
    scenario = run_on(@workflow.reload)
    version.strip_snapshot!

    assert_equal version, scenario.reload.workflow_version,
                 "the link answers WHICH version; the steps are not needed for that"
    assert_equal 1, scenario.workflow_version.version_number
  end
end
