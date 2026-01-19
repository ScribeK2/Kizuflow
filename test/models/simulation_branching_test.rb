require "test_helper"

class SimulationBranchingTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "branching-test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # ==========================================================================
  # Scenario 2: Branching with Variables (Yes/No Decisions)
  # ==========================================================================

  test "question variable leads to correct decision branch for yes answer" do
    workflow = Workflow.create!(
      title: "Urgency Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Urgency Check",
          "question" => "Is this urgent?",
          "variable_name" => "urgency",
          "answer_type" => "yes_no"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Route Decision",
          "branches" => [
            { "condition" => "urgency == 'yes'", "path" => "Escalate" }
          ],
          "else_path" => "Standard Process"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Escalate",
          "instructions" => "Escalate to supervisor immediately"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Standard Process",
          "instructions" => "Follow standard handling procedure"
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

    # Answer "yes" to urgency question
    simulation.process_step("yes")

    # Decision step should auto-advance
    simulation.process_step

    # Should be at Escalate step (index 2)
    assert_equal 2, simulation.current_step_index
    assert_equal "Escalate", simulation.current_step["title"]
  end

  test "question variable leads to else_path for no answer" do
    workflow = Workflow.create!(
      title: "Urgency Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Urgency Check",
          "question" => "Is this urgent?",
          "variable_name" => "urgency",
          "answer_type" => "yes_no"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Route Decision",
          "branches" => [
            { "condition" => "urgency == 'yes'", "path" => "Escalate" }
          ],
          "else_path" => "Standard Process"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Escalate",
          "instructions" => "Escalate to supervisor immediately"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Standard Process",
          "instructions" => "Follow standard handling procedure"
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

    # Answer "no" to urgency question
    simulation.process_step("no")

    # Decision step should auto-advance
    simulation.process_step

    # Should be at Standard Process step (index 3)
    assert_equal 3, simulation.current_step_index
    assert_equal "Standard Process", simulation.current_step["title"]
  end

  test "case-insensitive comparison for yes answer" do
    workflow = Workflow.create!(
      title: "Case Test Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Urgency Check",
          "question" => "Is this urgent?",
          "variable_name" => "urgency",
          "answer_type" => "yes_no"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Route Decision",
          "branches" => [
            { "condition" => "urgency == 'yes'", "path" => "Escalate" }
          ],
          "else_path" => "Standard"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Escalate",
          "instructions" => "Escalate"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Standard",
          "instructions" => "Standard"
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

    # Answer "YES" (uppercase) - should match case-insensitively
    simulation.process_step("YES")
    simulation.process_step  # Process decision

    # Should match 'yes' condition and go to Escalate
    assert_equal 2, simulation.current_step_index
    assert_equal "Escalate", simulation.current_step["title"]
  end

  # ==========================================================================
  # Legacy Format Tests (true_path/false_path)
  # ==========================================================================

  test "legacy format with true_path routes correctly" do
    workflow = Workflow.create!(
      title: "Legacy Format Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Question",
          "question" => "Is it true?",
          "variable_name" => "answer"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Decision",
          "condition" => "answer == 'yes'",
          "true_path" => "True Action",
          "false_path" => "False Action"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "True Action",
          "instructions" => "True path taken"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "False Action",
          "instructions" => "False path taken"
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

    simulation.process_step("yes")
    simulation.process_step  # Process decision

    assert_equal 2, simulation.current_step_index
    assert_equal "True Action", simulation.current_step["title"]
  end

  test "legacy format with false_path routes correctly" do
    workflow = Workflow.create!(
      title: "Legacy Format Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Question",
          "question" => "Is it true?",
          "variable_name" => "answer"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Decision",
          "condition" => "answer == 'yes'",
          "true_path" => "True Action",
          "false_path" => "False Action"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "True Action",
          "instructions" => "True path taken"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "False Action",
          "instructions" => "False path taken"
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

    simulation.process_step("no")
    simulation.process_step  # Process decision

    assert_equal 3, simulation.current_step_index
    assert_equal "False Action", simulation.current_step["title"]
  end

  # ==========================================================================
  # Decision Auto-Advance Tests
  # ==========================================================================

  test "decision steps auto-advance without user input" do
    workflow = Workflow.create!(
      title: "Auto-Advance Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Get Value",
          "question" => "Enter value",
          "variable_name" => "value"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Check Value",
          "branches" => [
            { "condition" => "value == 'test'", "path" => "Test Action" }
          ],
          "else_path" => "Other Action"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Test Action",
          "instructions" => "Test value received"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Other Action",
          "instructions" => "Other value received"
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

    # Answer question
    simulation.process_step("test")
    assert_equal 1, simulation.current_step_index
    assert_equal "decision", simulation.current_step["type"]

    # Process decision - no user input needed
    simulation.process_step

    # Should have auto-advanced past decision to action
    assert_equal 2, simulation.current_step_index
    assert_equal "Test Action", simulation.current_step["title"]
  end

  # ==========================================================================
  # Missing Variable Tests
  # ==========================================================================

  test "missing variable in condition returns false and uses else_path" do
    workflow = Workflow.create!(
      title: "Missing Variable Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "decision",
          "title" => "Check Missing",
          "branches" => [
            { "condition" => "nonexistent == 'yes'", "path" => "Should Not Reach" }
          ],
          "else_path" => "Default Action"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Should Not Reach",
          "instructions" => "This should not be reached"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Default Action",
          "instructions" => "Default path taken"
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

    # Process decision with no variables set
    simulation.process_step

    # Should use else_path since variable doesn't exist
    assert_equal 2, simulation.current_step_index
    assert_equal "Default Action", simulation.current_step["title"]
  end

  # ==========================================================================
  # Variable Lookup Priority Tests
  # ==========================================================================

  test "variable lookup finds value by variable_name" do
    workflow = Workflow.create!(
      title: "Variable Lookup Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Question Title",
          "question" => "Enter status",
          "variable_name" => "status_var"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Check Status",
          "branches" => [
            { "condition" => "status_var == 'active'", "path" => "Active Action" }
          ],
          "else_path" => "Inactive Action"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Active Action",
          "instructions" => "Handle active"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Inactive Action",
          "instructions" => "Handle inactive"
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

    simulation.process_step("active")
    simulation.process_step  # Process decision

    # Variable should be stored by variable_name and found in condition
    assert_equal "active", simulation.results["status_var"]
    assert_equal 2, simulation.current_step_index
    assert_equal "Active Action", simulation.current_step["title"]
  end

  # ==========================================================================
  # Inequality Condition Tests
  # ==========================================================================

  test "inequality condition evaluates correctly" do
    workflow = Workflow.create!(
      title: "Inequality Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Get Status",
          "question" => "Status?",
          "variable_name" => "status"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Check Not Closed",
          "branches" => [
            { "condition" => "status != 'closed'", "path" => "Still Open" }
          ],
          "else_path" => "Is Closed"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Still Open",
          "instructions" => "Process open item"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Is Closed",
          "instructions" => "Item is closed"
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

    simulation.process_step("open")
    simulation.process_step  # Process decision

    # "open" != "closed" should be true
    assert_equal 2, simulation.current_step_index
    assert_equal "Still Open", simulation.current_step["title"]
  end

  test "inequality with matching value goes to else_path" do
    workflow = Workflow.create!(
      title: "Inequality Match Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Get Status",
          "question" => "Status?",
          "variable_name" => "status"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Check Not Closed",
          "branches" => [
            { "condition" => "status != 'closed'", "path" => "Still Open" }
          ],
          "else_path" => "Is Closed"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Still Open",
          "instructions" => "Process open item"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Is Closed",
          "instructions" => "Item is closed"
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

    simulation.process_step("closed")
    simulation.process_step  # Process decision

    # "closed" != "closed" should be false, use else_path
    assert_equal 3, simulation.current_step_index
    assert_equal "Is Closed", simulation.current_step["title"]
  end
end
