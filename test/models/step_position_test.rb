require "test_helper"

class StepPositionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "step-position-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
    @workflow = Workflow.create!(title: "Position Test Workflow", user: @user)
  end

  test "position_x and position_y default to nil" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "A1")
    assert_nil step.position_x
    assert_nil step.position_y
  end

  test "position_x and position_y persist correctly" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "A1", position_x: 100, position_y: 200)
    step.reload
    assert_equal 100, step.position_x
    assert_equal 200, step.position_y
  end

  test "position_x and position_y can be updated" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "A1")
    step.update!(position_x: 300, position_y: 400)
    step.reload
    assert_equal 300, step.position_x
    assert_equal 400, step.position_y
  end

  test "position_x and position_y can be cleared back to nil" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "A1", position_x: 100, position_y: 200)
    step.update!(position_x: nil, position_y: nil)
    step.reload
    assert_nil step.position_x
    assert_nil step.position_y
  end
end
