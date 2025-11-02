require "test_helper"

class SimulationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Don't use fixtures - create data directly
  self.use_transactional_tests = true

  def setup
    # Create user directly instead of using fixtures
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @workflow = Workflow.create!(
      title: "Test Workflow",
      description: "A test workflow",
      user: @user,
      steps: [
        { type: "question", title: "Question 1", question: "What is your name?" }
      ]
    )
    sign_in @user
  end

  test "should get new simulation" do
    get new_workflow_simulation_path(@workflow)
    assert_response :success
  end

  test "should create simulation" do
    assert_difference("Simulation.count") do
      post workflow_simulations_path(@workflow), params: {
        simulation: {
          inputs: { "0" => "John Doe" }
        }
      }
    end

    simulation = Simulation.last
    assert_redirected_to simulation_path(simulation)
    assert_equal @workflow, simulation.workflow
    assert_equal @user, simulation.user
  end

  test "should not allow simulating other user's workflow" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    other_workflow = Workflow.create!(
      title: "Other Workflow",
      user: other_user
    )

    get new_workflow_simulation_path(other_workflow)
    assert_redirected_to workflows_path
    assert_equal "You don't have permission to simulate this workflow.", flash[:alert]
  end

  test "should show simulation results" do
    simulation = Simulation.create!(
      workflow: @workflow,
      user: @user,
      inputs: { "0" => "John Doe" }
    )
    simulation.execute

    get simulation_path(simulation)
    assert_response :success
  end

  test "should require authentication" do
    sign_out @user
    get new_workflow_simulation_path(@workflow)
    assert_redirected_to new_user_session_path
  end
end

