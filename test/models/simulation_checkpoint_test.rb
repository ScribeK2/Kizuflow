require "test_helper"

class SimulationCheckpointTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "checkpoint-test@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
  end

  # ==========================================================================
  # Checkpoint Basic Behavior Tests
  # ==========================================================================

  test "checkpoint step does not auto-advance" do
    workflow = Workflow.create!(
      title: "Checkpoint Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Manager Review",
          "checkpoint_message" => "Verify the information before proceeding"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Continue Processing",
          "instructions" => "Process the request"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Try to process checkpoint - should return false (no advancement)
    result = simulation.process_step

    assert_equal false, result
    assert_equal 0, simulation.current_step_index
    assert_equal "checkpoint", simulation.current_step["type"]
  end

  test "checkpoint requires explicit resolve to advance" do
    workflow = Workflow.create!(
      title: "Checkpoint Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Manager Review",
          "checkpoint_message" => "Verify the information"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Continue",
          "instructions" => "Continue processing"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Resolve checkpoint with continue (not resolved)
    result = simulation.resolve_checkpoint!(resolved: false)

    assert result
    assert_equal 1, simulation.current_step_index
    assert_equal "Continue", simulation.current_step["title"]
    assert_equal "active", simulation.status
  end

  # ==========================================================================
  # Checkpoint Resolution Tests
  # ==========================================================================

  test "resolving checkpoint as resolved completes workflow" do
    workflow = Workflow.create!(
      title: "Checkpoint Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Initial Question",
          "question" => "What is the issue?",
          "variable_name" => "issue"
        },
        {
          "id" => "step-2",
          "type" => "checkpoint",
          "title" => "Issue Check",
          "checkpoint_message" => "Was the issue resolved?"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Continue Investigation",
          "instructions" => "Continue investigating"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 1, # Start at checkpoint
      results: { "issue" => "Connection timeout" },
      inputs: {}
    )

    # Resolve checkpoint as resolved
    result = simulation.resolve_checkpoint!(resolved: true)

    assert result
    assert_equal "completed", simulation.status
    assert_equal workflow.steps.length, simulation.current_step_index
    assert_equal "Issue resolved - workflow completed", simulation.results["Issue Check"]
  end

  test "resolving checkpoint as not resolved continues workflow" do
    workflow = Workflow.create!(
      title: "Checkpoint Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Issue Check",
          "checkpoint_message" => "Was the issue resolved?"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Continue Investigation",
          "instructions" => "Continue investigating the issue"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Resolve checkpoint as NOT resolved (continue workflow)
    result = simulation.resolve_checkpoint!(resolved: false)

    assert result
    assert_equal 1, simulation.current_step_index
    assert_equal "active", simulation.status
    assert_equal "Issue not resolved - continuing workflow", simulation.results["Issue Check"]
  end

  # ==========================================================================
  # Checkpoint with Notes Tests
  # ==========================================================================

  test "checkpoint resolution can include notes" do
    workflow = Workflow.create!(
      title: "Checkpoint with Notes Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Review Point",
          "checkpoint_message" => "Review and add notes"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Next Step",
          "instructions" => "Continue"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Resolve with notes
    result = simulation.resolve_checkpoint!(resolved: false, notes: "Customer was on hold for 5 minutes")

    assert result

    # Check that notes are recorded in execution path
    checkpoint_entry = simulation.execution_path.find { |e| e["step_type"] == "checkpoint" }

    assert_not_nil checkpoint_entry
    assert_equal "Customer was on hold for 5 minutes", checkpoint_entry["notes"]
  end

  # ==========================================================================
  # Checkpoint Edge Cases
  # ==========================================================================

  test "cannot resolve non-checkpoint step" do
    workflow = Workflow.create!(
      title: "Non-Checkpoint Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "action",
          "title" => "Action Step",
          "instructions" => "Do something"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Try to resolve an action step as checkpoint
    result = simulation.resolve_checkpoint!(resolved: true)

    assert_equal false, result
    # Should not have changed status
    assert_equal "active", simulation.status
    assert_equal 0, simulation.current_step_index
  end

  test "cannot resolve checkpoint on stopped simulation" do
    workflow = Workflow.create!(
      title: "Stopped Simulation Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Checkpoint",
          "checkpoint_message" => "Check"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'stopped',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    result = simulation.resolve_checkpoint!(resolved: true)

    assert_equal false, result
    assert_equal "stopped", simulation.status
  end

  test "cannot resolve checkpoint on completed simulation" do
    workflow = Workflow.create!(
      title: "Completed Simulation Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Checkpoint",
          "checkpoint_message" => "Check"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'completed',
      current_step_index: 1, # Past the last step
      results: {},
      inputs: {}
    )

    result = simulation.resolve_checkpoint!(resolved: true)

    assert_equal false, result
    assert_equal "completed", simulation.status
  end

  # ==========================================================================
  # Checkpoint Execution Path Tests
  # ==========================================================================

  test "checkpoint resolution is recorded in execution path" do
    workflow = Workflow.create!(
      title: "Execution Path Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Review Checkpoint",
          "checkpoint_message" => "Review the data"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Continue",
          "instructions" => "Continue"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {},
      execution_path: []
    )

    simulation.resolve_checkpoint!(resolved: false)

    # Check execution path entry
    assert_equal 1, simulation.execution_path.length
    entry = simulation.execution_path.first

    assert_equal 0, entry["step_index"]
    assert_equal "Review Checkpoint", entry["step_title"]
    assert_equal "checkpoint", entry["step_type"]
    assert_equal false, entry["resolved"]
    assert_predicate entry["resolved_at"], :present?
  end

  test "checkpoint resolved entry shows resolved true" do
    workflow = Workflow.create!(
      title: "Resolved Path Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "checkpoint",
          "title" => "Final Check",
          "checkpoint_message" => "Is everything done?"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {},
      execution_path: []
    )

    simulation.resolve_checkpoint!(resolved: true)

    entry = simulation.execution_path.first

    assert_equal true, entry["resolved"]
    assert_equal "completed", simulation.status
  end

  # ==========================================================================
  # Checkpoint in Complex Workflow Tests
  # ==========================================================================

  test "checkpoint in middle of workflow pauses correctly" do
    workflow = Workflow.create!(
      title: "Complex Workflow with Checkpoint",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Get Name",
          "question" => "What is your name?",
          "variable_name" => "name"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Greet",
          "instructions" => "Greet the customer"
        },
        {
          "id" => "step-3",
          "type" => "checkpoint",
          "title" => "Verification",
          "checkpoint_message" => "Verify customer identity"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Process Request",
          "instructions" => "Process the customer request"
        }
      ]
    )

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    # Process question
    simulation.process_step("John")

    assert_equal 1, simulation.current_step_index

    # Process action
    simulation.process_step

    assert_equal 2, simulation.current_step_index

    # At checkpoint - process_step should return false
    result = simulation.process_step

    assert_equal false, result
    assert_equal 2, simulation.current_step_index
    assert_equal "checkpoint", simulation.current_step["type"]

    # Resolve checkpoint to continue
    simulation.resolve_checkpoint!(resolved: false)

    assert_equal 3, simulation.current_step_index
    assert_equal "Process Request", simulation.current_step["title"]
  end
end
