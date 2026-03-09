require "test_helper"

class TransitionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "transition-test@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
    @workflow = Workflow.create!(title: "Test Workflow", user: @user)
    @step1 = Steps::Question.create!(workflow: @workflow, uuid: SecureRandom.uuid, position: 0, title: "Q1", question: "What?")
    @step2 = Steps::Action.create!(workflow: @workflow, uuid: SecureRandom.uuid, position: 1, title: "A1")
  end

  test "transition belongs to step and target_step" do
    transition = Transition.create!(step: @step1, target_step: @step2)
    assert_equal @step1, transition.step
    assert_equal @step2, transition.target_step
  end

  test "transition requires step" do
    transition = Transition.new(target_step: @step2)
    assert_not transition.valid?
  end

  test "transition requires target_step" do
    transition = Transition.new(step: @step1)
    assert_not transition.valid?
  end

  test "no duplicate transitions between same steps" do
    Transition.create!(step: @step1, target_step: @step2)
    duplicate = Transition.new(step: @step1, target_step: @step2)
    assert_not duplicate.valid?
  end

  test "transition can have condition and label" do
    transition = Transition.create!(step: @step1, target_step: @step2, condition: "yes", label: "If yes")
    assert_equal "yes", transition.condition
    assert_equal "If yes", transition.label
  end

  test "deleting step cascades to transitions" do
    Transition.create!(step: @step1, target_step: @step2)
    assert_difference "Transition.count", -1 do
      @step1.destroy
    end
  end

  test "deleting target step cascades to incoming transitions" do
    Transition.create!(step: @step1, target_step: @step2)
    assert_difference "Transition.count", -1 do
      @step2.destroy
    end
  end
end
