require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should create workflow with valid attributes" do
    workflow = Workflow.new(
      title: "Test Workflow",
      description: "A test workflow",
      user: @user,
      steps: [{ type: "question", title: "Question 1" }]
    )
    assert workflow.valid?
    assert workflow.save
  end

  test "should not create workflow without title" do
    workflow = Workflow.new(
      description: "A test workflow",
      user: @user
    )
    assert_not workflow.valid?
    assert_includes workflow.errors[:title], "can't be blank"
  end

  test "should not create workflow without user" do
    workflow = Workflow.new(
      title: "Test Workflow",
      description: "A test workflow"
    )
    assert_not workflow.valid?
    assert_includes workflow.errors[:user_id], "can't be blank"
  end

  test "should belong to user" do
    workflow = Workflow.create!(
      title: "Test Workflow",
      user: @user
    )
    assert_equal @user, workflow.user
  end

  test "should store steps as JSON" do
    steps = [
      { type: "question", title: "Question 1", description: "First question" },
      { type: "decision", title: "Decision 1", condition: "answer == 'yes'" }
    ]
    workflow = Workflow.create!(
      title: "Test Workflow",
      user: @user,
      steps: steps
    )
    
    # JSON stores keys as strings, not symbols
    assert_equal 2, workflow.steps.length
    assert_equal "question", workflow.steps.first["type"]
    assert_equal "Decision 1", workflow.steps.last["title"]
  end

  test "recent scope should order by created_at desc" do
    # Clear existing workflows for this test to avoid fixture interference
    Workflow.where(user: @user).destroy_all
    
    first = Workflow.create!(title: "First", user: @user, created_at: 2.days.ago)
    second = Workflow.create!(title: "Second", user: @user, created_at: 1.day.ago)
    third = Workflow.create!(title: "Third", user: @user, created_at: Time.current)
    
    recent = Workflow.where(user: @user).recent.limit(3)
    assert_equal third.id, recent.first.id
    assert_equal first.id, recent.last.id
  end
end

