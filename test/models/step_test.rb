require "test_helper"

class StepTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "step-test@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
    @workflow = Workflow.create!(title: "Test Workflow", user: @user)
  end

  test "step requires workflow" do
    step = Step.new(type: "Steps::Question", uuid: SecureRandom.uuid, position: 0, title: "Q1")
    assert_not step.valid?
    assert_includes step.errors[:workflow], "must exist"
  end

  test "step validates uuid presence but auto-generates if blank" do
    step = Step.new(workflow: @workflow, type: "Steps::Question", position: 0, title: "Q1")
    # uuid is auto-generated before validation, so it should be valid
    step.valid?
    assert step.uuid.present?, "UUID should be auto-generated"
  end

  test "step requires position" do
    step = Step.new(workflow: @workflow, type: "Steps::Question", uuid: SecureRandom.uuid, title: "Q1")
    assert_not step.valid?
    assert_includes step.errors[:position], "can't be blank"
  end

  test "step uuid must be unique" do
    uuid = SecureRandom.uuid
    Step.create!(workflow: @workflow, type: "Steps::Question", uuid: uuid, position: 0, title: "Q1", question: "What?")
    duplicate = Step.new(workflow: @workflow, type: "Steps::Question", uuid: uuid, position: 1, title: "Q2")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uuid], "has already been taken"
  end

  test "step auto-generates uuid before validation if blank" do
    step = Step.new(workflow: @workflow, type: "Steps::Question", position: 0, title: "Q1", question: "What?")
    step.valid?
    assert step.uuid.present?
    assert_match(/^[0-9a-f-]{36}$/, step.uuid)
  end

  test "step belongs to workflow" do
    step = Step.create!(workflow: @workflow, type: "Steps::Question", uuid: SecureRandom.uuid, position: 0, title: "Q1", question: "What?")
    assert_equal @workflow, step.workflow
  end

  # Transition association tested in TransitionTest after Transition model is created
  test "step has transitions association" do
    step = Step.create!(workflow: @workflow, type: "Steps::Question", uuid: SecureRandom.uuid, position: 0, title: "Q1", question: "What?")
    assert_respond_to step, :transitions
    assert_respond_to step, :incoming_transitions
  end

  test "workflow has_many steps ordered by position" do
    s2 = Step.create!(workflow: @workflow, type: "Steps::Action", uuid: SecureRandom.uuid, position: 1, title: "Second")
    s1 = Step.create!(workflow: @workflow, type: "Steps::Question", uuid: SecureRandom.uuid, position: 0, title: "First", question: "Q?")
    assert_equal ["First", "Second"], @workflow.steps.reload.map(&:title)
  end
end
