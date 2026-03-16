require "test_helper"

class StepsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @editor = User.create!(
      email: "editor-steps-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    @workflow = Workflow.create!(title: "Steps Test WF", user: @editor, graph_mode: true)
    @step = Steps::Action.create!(workflow: @workflow, position: 0, title: "Existing Step")
    sign_in @editor
  end

  # 1. create step via JSON returns created step data
  test "create step via JSON returns created step data" do
    post workflow_steps_path(@workflow),
      params: { step: { type: "action", title: "New Action Step" } },
      as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "New Action Step", json["title"]
    assert_equal "action", json["type"]
    assert json["id"].present?
    assert json["uuid"].present?
  end

  # 2. create step defaults to action type when no type given
  test "create step defaults to action type" do
    post workflow_steps_path(@workflow),
      params: { step: { title: "Typeless Step" } },
      as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "action", json["type"]
  end

  # 3. create step for each valid type
  test "create step for each valid type" do
    @target_workflow = Workflow.create!(title: "Sub Flow Target", user: @editor)

    valid_types_and_params = {
      "question"  => { type: "question", title: "Q Step", question: "What?" },
      "message"   => { type: "message", title: "Msg Step" },
      "escalate"  => { type: "escalate", title: "Esc Step", target_type: "supervisor", priority: "high" },
      "resolve"   => { type: "resolve", title: "Res Step", resolution_type: "success" },
      "sub_flow"  => { type: "sub_flow", title: "SF Step", sub_flow_workflow_id: @target_workflow.id }
    }

    valid_types_and_params.each do |step_type, step_attrs|
      post workflow_steps_path(@workflow),
        params: { step: step_attrs },
        as: :json

      assert_response :created, "Expected 201 for type #{step_type}, got #{response.status}: #{response.body}"
      json = response.parsed_body
      assert_equal step_type, json["type"], "Expected type #{step_type}, got #{json["type"]}"
    end
  end

  # 4. update step via JSON returns updated title
  test "update step via JSON returns updated title" do
    patch workflow_step_path(@workflow, @step),
      params: { step: { title: "Updated Title" } },
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal "Updated Title", json["title"]
  end

  # 5. destroy step via JSON returns 204 no content
  test "destroy step via JSON returns 204 no content" do
    assert_difference("Step.count", -1) do
      delete workflow_step_path(@workflow, @step), as: :json
    end

    assert_response :no_content
  end

  # 6. reorder step updates position
  test "reorder step updates step position" do
    extra = Steps::Action.create!(workflow: @workflow, position: 1, title: "Second Step")

    patch reorder_workflow_step_path(@workflow, extra),
      params: { position: 0 },
      as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal 0, json["position"]
    assert_equal 0, extra.reload.position
  end

  # 7. requires authentication — unauthenticated POST redirects
  test "requires authentication to create step" do
    sign_out @editor

    post workflow_steps_path(@workflow),
      params: { step: { title: "No Auth" } },
      as: :json

    # Devise redirects to sign in for HTML; for JSON it returns 401
    assert_includes [302, 401], response.status
  end

  # 8. editor can view own workflow step (show returns 200)
  test "editor can show step on own workflow" do
    get workflow_step_path(@workflow, @step), as: :json

    assert_response :ok
    json = response.parsed_body
    assert_equal @step.id, json["id"]
  end

  # 9. editor cannot CRUD steps on another editor's private workflow
  test "editor cannot update step on other editors private workflow" do
    other_editor = User.create!(
      email: "other-editor-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    other_workflow = Workflow.create!(title: "Other WF", user: other_editor, is_public: false)
    other_step = Steps::Action.create!(workflow: other_workflow, position: 0, title: "Other Step")

    patch workflow_step_path(other_workflow, other_step),
      params: { step: { title: "Hacked" } }

    assert_redirected_to workflows_path
    assert_match(/permission/, flash[:alert])
  end

  # 10. regular user cannot create steps
  test "regular user cannot create steps" do
    regular = User.create!(
      email: "regular-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "user"
    )
    sign_in regular

    post workflow_steps_path(@workflow),
      params: { step: { title: "User Step" } }

    assert_redirected_to workflows_path
    assert_match(/permission/, flash[:alert])
  end
end
