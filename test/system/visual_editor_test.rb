require "application_system_test_case"

class VisualEditorTest < ApplicationSystemTestCase
  setup do
    @editor = User.create!(
      email: "ve-system-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )

    @graph_workflow = Workflow.create!(
      title: "Visual Editor Test Workflow",
      user: @editor,
      status: "draft",
      graph_mode: true
    )
    step1 = Steps::Question.create!(workflow: @graph_workflow, position: 0, uuid: "ve-test-0001", title: "First Question", question: "What?", answer_type: "yes_no")
    step2 = Steps::Action.create!(workflow: @graph_workflow, position: 1, uuid: "ve-test-0002", title: "Do Something", action_type: "Instruction")
    Transition.create!(step: step1, target_step: step2, condition: "yes", label: "Yes", position: 0)
    @graph_workflow.update!(start_step: step1)

    @linear_workflow = Workflow.create!(
      title: "Linear Workflow",
      user: @editor,
      status: "draft",
      graph_mode: false
    )
    Steps::Question.create!(workflow: @linear_workflow, position: 0, uuid: SecureRandom.uuid, title: "Q1", question: "Yes?", answer_type: "yes_no")

    sign_in_as @editor
  end

  test "mode toggle appears for graph mode workflows" do
    visit step2_workflow_path(@graph_workflow)

    assert_selector "[data-controller='view-mode-toggle']", wait: 5
    assert_selector "[data-view-mode-toggle-target='listBtn']"
    assert_selector "[data-view-mode-toggle-target='visualBtn']"
  end

  test "mode toggle does not appear for non-graph workflows" do
    visit step2_workflow_path(@linear_workflow)

    assert_no_selector "[data-controller='view-mode-toggle']", wait: 3
  end

  test "switching to visual mode shows the visual editor canvas" do
    visit step2_workflow_path(@graph_workflow)

    # Initially list editor is visible, visual is hidden
    assert_selector "#list-editor-container", visible: true, wait: 5
    assert_selector "#visual-editor-container", visible: false

    # Click Visual button
    find("[data-view-mode-toggle-target='visualBtn']").click

    # Visual editor should now be visible, list hidden
    assert_selector "#visual-editor-container", visible: true, wait: 5
    assert_selector "#list-editor-container", visible: false
  end

  test "switching back to list mode shows the list editor" do
    visit step2_workflow_path(@graph_workflow)

    # Switch to visual
    find("[data-view-mode-toggle-target='visualBtn']").click
    assert_selector "#visual-editor-container", visible: true, wait: 5

    # Switch back to list
    find("[data-view-mode-toggle-target='listBtn']").click
    assert_selector "#list-editor-container", visible: true, wait: 5
    assert_selector "#visual-editor-container", visible: false
  end

  test "visual editor renders existing steps as nodes" do
    visit step2_workflow_path(@graph_workflow)

    find("[data-view-mode-toggle-target='visualBtn']").click
    assert_selector "#visual-editor-container", visible: true, wait: 5

    # Should render workflow nodes with step data
    assert_selector ".workflow-node", minimum: 2, wait: 5
  end

  test "visual editor shows correct step count" do
    visit step2_workflow_path(@graph_workflow)

    find("[data-view-mode-toggle-target='visualBtn']").click
    assert_selector "#visual-editor-container", visible: true, wait: 5

    assert_selector "[data-visual-editor-target='stepCount']", text: "2 steps", wait: 5
  end
end
