require "test_helper"

class PlayerAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner@example.com", password: "password123456")
    @other_user = User.create!(email: "other@example.com", password: "password123456")
    @workflow = Workflow.create!(title: "Shared WF", user: @owner, status: "published")
    @workflow.update!(share_token: SecureRandom.hex(16))
  end

  test "owner can access their own scenario" do
    sign_in @owner
    scenario = Scenario.create!(
      workflow: @workflow, user: @owner, purpose: "live",
      current_node_uuid: @workflow.start_node&.uuid,
      execution_path: [], results: {}, inputs: {}
    )
    get player_scenario_step_path(scenario)
    assert_response :success
  end

  test "anonymous user can access scenario on shared workflow created via share flow" do
    scenario = Scenario.create!(
      workflow: @workflow, user: @workflow.user, purpose: "live",
      shared_access: true,
      current_node_uuid: @workflow.start_node&.uuid,
      execution_path: [], results: {}, inputs: {}
    )
    get player_scenario_step_path(scenario)
    assert_response :success
  end

  test "anonymous user cannot access non-shared scenario" do
    scenario = Scenario.create!(
      workflow: @workflow, user: @owner, purpose: "live",
      shared_access: false,
      current_node_uuid: @workflow.start_node&.uuid,
      execution_path: [], results: {}, inputs: {}
    )
    get player_scenario_step_path(scenario)
    assert_response :forbidden
  end

  # Note the scenario here is NOT shared_access (the column defaults to false) —
  # the *workflow* is shared, the run is not. Someone else's private run stays
  # private no matter who is asking.
  test "authenticated user cannot access another users scenario on shared workflow" do
    sign_in @other_user
    scenario = Scenario.create!(
      workflow: @workflow, user: @owner, purpose: "live",
      current_node_uuid: @workflow.start_node&.uuid,
      execution_path: [], results: {}, inputs: {}
    )
    get player_scenario_step_path(scenario)
    assert_response :forbidden
  end

  # --- signing in must not revoke a share link ---
  #
  # set_scenario used to branch on current_user first, so the shared_access grant
  # was only reachable when nobody was signed in. Anonymous got 200, the owner got
  # 200 (their own scenario), and every other signed-in user got 403 on the same
  # URL. On an install where everyone has an account that is most recipients, so
  # the link looked broken precisely for the people it was sent to.

  test "authenticated non-owner can access a shared run" do
    sign_in @other_user
    scenario = Scenario.create!(
      workflow: @workflow, user: @owner, purpose: "live",
      shared_access: true,
      current_node_uuid: @workflow.start_node&.uuid,
      execution_path: [], results: {}, inputs: {}
    )
    get player_scenario_step_path(scenario)
    assert_response :success
  end

  # The end-to-end journey, not just the guard: open /s/:token and land on a step.
  test "the share link works the same signed in, signed in as owner, and anonymous" do
    workflow = Workflow.create!(title: "E2E Share #{SecureRandom.hex(3)}",
                                user: @owner, status: "published")
    question = Steps::Question.create!(workflow: workflow, position: 0, title: "Q",
                                       question: "Q?", variable_name: "v")
    resolve = Steps::Resolve.create!(workflow: workflow, position: 1, title: "Done",
                                     resolution_type: "success")
    Transition.create!(step: question, target_step: resolve, position: 0)
    workflow.update!(start_step: question, share_token: SecureRandom.hex(16))

    # Anonymous
    get shared_player_path(workflow.share_token)
    follow_redirect!
    assert_response :success, "anonymous visitor must be able to open a share link"

    # Signed in, not the owner — the case that used to 403
    sign_in @other_user
    get shared_player_path(workflow.share_token)
    follow_redirect!
    assert_response :success, "signing in must not revoke a share link"

    # Signed in as the owner
    sign_in @owner
    get shared_player_path(workflow.share_token)
    follow_redirect!
    assert_response :success, "the owner must be able to open their own share link"
  end

  # Advancing is the part that matters: reaching the first step and then being
  # locked out on the answer would be the same bug one request later.
  test "an authenticated non-owner can advance a shared run, not just view it" do
    workflow = Workflow.create!(title: "Advance Share #{SecureRandom.hex(3)}",
                                user: @owner, status: "published")
    question = Steps::Question.create!(workflow: workflow, position: 0, title: "Q",
                                       question: "Q?", variable_name: "v")
    resolve = Steps::Resolve.create!(workflow: workflow, position: 1, title: "Done",
                                     resolution_type: "success")
    Transition.create!(step: question, target_step: resolve, position: 0)
    workflow.update!(start_step: question, share_token: SecureRandom.hex(16))

    sign_in @other_user
    get shared_player_path(workflow.share_token)
    follow_redirect!
    assert_response :success

    scenario = Scenario.order(:id).last
    post player_scenario_next_path(scenario), params: { answer: "yes" }
    assert_includes [200, 302], response.status,
                    "a signed-in visitor must be able to answer a shared run"
  end
end
