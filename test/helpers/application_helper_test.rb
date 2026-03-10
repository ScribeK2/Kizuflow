require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "display_workflow_description returns description text" do
    workflow = Workflow.new(description: "Test description")
    assert_includes display_workflow_description(workflow).to_s, "Test description"
  end

  test "display_workflow_description returns fallback for blank" do
    workflow = Workflow.new
    assert_equal "No description", display_workflow_description(workflow)
  end
end
