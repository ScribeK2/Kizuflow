require "test_helper"

class SimulationMultiBranchTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "multi-branch-test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # ==========================================================================
  # Scenario 3: Multi-Branch Decision with Numeric Comparisons
  # ==========================================================================

  def create_priority_workflow
    Workflow.create!(
      title: "Priority Routing Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Users Affected",
          "question" => "How many users are affected?",
          "variable_name" => "count",
          "answer_type" => "number"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Priority Router",
          "branches" => [
            { "condition" => "count >= 100", "path" => "Critical" },
            { "condition" => "count >= 50", "path" => "High" },
            { "condition" => "count >= 10", "path" => "Medium" }
          ],
          "else_path" => "Low"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Critical",
          "instructions" => "CRITICAL: Escalate to all-hands immediately"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "High",
          "instructions" => "HIGH: Page on-call engineer"
        },
        {
          "id" => "step-5",
          "type" => "action",
          "title" => "Medium",
          "instructions" => "MEDIUM: Create ticket for next sprint"
        },
        {
          "id" => "step-6",
          "type" => "action",
          "title" => "Low",
          "instructions" => "LOW: Add to backlog"
        }
      ]
    )
  end

  # ==========================================================================
  # Multi-Branch First Match Tests
  # ==========================================================================

  test "multi-branch routes to first matching condition (count = 150)" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("150")
    simulation.process_step # Process decision

    # Should match first branch (count >= 100)
    assert_equal 2, simulation.current_step_index
    assert_equal "Critical", simulation.current_step["title"]
  end

  test "multi-branch routes to second branch when first doesn't match (count = 75)" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("75")
    simulation.process_step # Process decision

    # Should match second branch (count >= 50)
    assert_equal 3, simulation.current_step_index
    assert_equal "High", simulation.current_step["title"]
  end

  test "multi-branch routes to third branch (count = 25)" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("25")
    simulation.process_step # Process decision

    # Should match third branch (count >= 10)
    assert_equal 4, simulation.current_step_index
    assert_equal "Medium", simulation.current_step["title"]
  end

  test "multi-branch routes to else_path when no conditions match (count = 5)" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("5")
    simulation.process_step # Process decision

    # Should use else_path (Low)
    assert_equal 5, simulation.current_step_index
    assert_equal "Low", simulation.current_step["title"]
  end

  # ==========================================================================
  # Boundary Value Tests
  # ==========================================================================

  test "boundary value exactly 100 routes to Critical" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("100")
    simulation.process_step

    # count >= 100 should match
    assert_equal "Critical", simulation.current_step["title"]
  end

  test "boundary value exactly 50 routes to High" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("50")
    simulation.process_step

    # 50 >= 100 is false, 50 >= 50 is true
    assert_equal "High", simulation.current_step["title"]
  end

  test "boundary value exactly 10 routes to Medium" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("10")
    simulation.process_step

    # 10 >= 100 is false, 10 >= 50 is false, 10 >= 10 is true
    assert_equal "Medium", simulation.current_step["title"]
  end

  test "boundary value 9 routes to Low (else_path)" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("9")
    simulation.process_step

    # 9 < 10, no branches match
    assert_equal "Low", simulation.current_step["title"]
  end

  # ==========================================================================
  # Other Numeric Comparison Operators
  # ==========================================================================

  test "greater than comparison works correctly" do
    workflow = Workflow.create!(
      title: "Greater Than Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Enter Score",
          "question" => "Score?",
          "variable_name" => "score"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Score Check",
          "branches" => [
            { "condition" => "score > 90", "path" => "Excellent" }
          ],
          "else_path" => "Not Excellent"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Excellent",
          "instructions" => "Score is excellent"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Not Excellent",
          "instructions" => "Score is not excellent"
        }
      ]
    )

    # Test 91 > 90 = true
    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("91")
    simulation.process_step

    assert_equal "Excellent", simulation.current_step["title"]

    # Test 90 > 90 = false (boundary)
    simulation2 = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation2.process_step("90")
    simulation2.process_step

    assert_equal "Not Excellent", simulation2.current_step["title"]
  end

  test "less than comparison works correctly" do
    workflow = Workflow.create!(
      title: "Less Than Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Enter Value",
          "question" => "Value?",
          "variable_name" => "value"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Value Check",
          "branches" => [
            { "condition" => "value < 10", "path" => "Small" }
          ],
          "else_path" => "Not Small"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Small",
          "instructions" => "Value is small"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Not Small",
          "instructions" => "Value is not small"
        }
      ]
    )

    # Test 5 < 10 = true
    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("5")
    simulation.process_step

    assert_equal "Small", simulation.current_step["title"]

    # Test 10 < 10 = false
    simulation2 = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation2.process_step("10")
    simulation2.process_step

    assert_equal "Not Small", simulation2.current_step["title"]
  end

  test "less than or equal comparison works correctly" do
    workflow = Workflow.create!(
      title: "Less Than Equal Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "question",
          "title" => "Enter Value",
          "question" => "Value?",
          "variable_name" => "value"
        },
        {
          "id" => "step-2",
          "type" => "decision",
          "title" => "Value Check",
          "branches" => [
            { "condition" => "value <= 10", "path" => "Small or Equal" }
          ],
          "else_path" => "Greater"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "Small or Equal",
          "instructions" => "Value is 10 or less"
        },
        {
          "id" => "step-4",
          "type" => "action",
          "title" => "Greater",
          "instructions" => "Value is greater than 10"
        }
      ]
    )

    # Test 10 <= 10 = true (boundary)
    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("10")
    simulation.process_step

    assert_equal "Small or Equal", simulation.current_step["title"]

    # Test 11 <= 10 = false
    simulation2 = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation2.process_step("11")
    simulation2.process_step

    assert_equal "Greater", simulation2.current_step["title"]
  end

  # ==========================================================================
  # Zero and Negative Number Tests
  # ==========================================================================

  test "zero value handled correctly" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      current_step_index: 0,
      results: {},
      inputs: {}
    )

    simulation.process_step("0")
    simulation.process_step

    # 0 doesn't match any conditions, should use else_path
    assert_equal "Low", simulation.current_step["title"]
  end

  test "missing numeric variable defaults to 0" do
    workflow = Workflow.create!(
      title: "Missing Numeric Workflow",
      user: @user,
      steps: [
        {
          "id" => "step-1",
          "type" => "decision",
          "title" => "Check Missing",
          "branches" => [
            { "condition" => "missing_var >= 10", "path" => "Has Value" }
          ],
          "else_path" => "No Value"
        },
        {
          "id" => "step-2",
          "type" => "action",
          "title" => "Has Value",
          "instructions" => "Has value"
        },
        {
          "id" => "step-3",
          "type" => "action",
          "title" => "No Value",
          "instructions" => "No value"
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

    simulation.process_step

    # Missing variable should default to 0, 0 >= 10 is false
    assert_equal "No Value", simulation.current_step["title"]
  end

  # ==========================================================================
  # Execute Method Tests (Batch Processing)
  # ==========================================================================

  test "execute method processes multi-branch workflow correctly" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      inputs: { "count" => "75" }
    )

    result = simulation.execute

    # Execute method should return truthy value on success
    assert result

    # Should mark simulation as completed
    assert_equal "completed", simulation.status

    # Should have processed through decision step
    assert(simulation.execution_path.any? { |e| e["step_title"] == "Priority Router" })

    # Should have routed to High priority based on count = 75 (matches >= 50)
    assert(simulation.execution_path.any? { |e| e["step_title"] == "High" })

    # Verify results contain the expected answer
    assert_equal "75", simulation.results["count"]
  end

  test "execute records matched branch in execution path" do
    workflow = create_priority_workflow

    simulation = Simulation.create!(
      workflow: workflow,
      user: @user,
      status: 'active',
      inputs: { "count" => "150" }
    )

    simulation.execute

    # Find the decision step in execution path
    decision_entry = simulation.execution_path.find { |e| e["step_title"] == "Priority Router" }

    assert_not_nil decision_entry
    assert_match(/count >= 100/, decision_entry["matched_branch"] || decision_entry["condition_result"])
  end
end
