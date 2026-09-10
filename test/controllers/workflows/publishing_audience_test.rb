require "test_helper"

# Spec Q44: nothing publishes until someone has chosen who sees it. New
# workflows start with no groups (Q45), so this is the guard against an editor
# forgetting — the worry the user raised with Q41.
module Workflows
  class PublishingAudienceTest < ActionDispatch::IntegrationTest
    setup do
      @editor = User.create!(email: "audience-pub-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                             password_confirmation: "password123!", role: "editor")
      @workflow = Workflow.create!(title: "Nobody Yet", user: @editor, status: "draft", graph_mode: true)
      question = Steps::Question.create!(workflow: @workflow, position: 0, title: "Q", question: "What?",
                                         variable_name: "q", answer_type: "text")
      resolve = Steps::Resolve.create!(workflow: @workflow, position: 1, title: "Done", resolution_type: "success")
      Transition.create!(step: question, target_step: resolve, position: 0)
      @workflow.update!(start_step: question)
      sign_in @editor
    end

    test "publishing with no audience stays a draft and says how to choose one" do
      post workflow_publishing_path(@workflow)

      assert_redirected_to workflow_path(@workflow, edit: true)
      assert_equal "Failed to publish: #{WorkflowPublisher::NO_AUDIENCE}", flash[:alert]
      assert_predicate @workflow.reload, :draft?
    end

    test "the health panel names the missing audience" do
      get workflow_health_path(@workflow)

      assert_select ".health-panel__issues .list-row__title", text: /No audience yet/
      assert_not_includes response.body, "Audience chosen"
    end

    test "once an audience is chosen the panel lists it as passing" do
      file_in_global(@workflow)

      get workflow_health_path(@workflow)

      assert_includes response.body, "Audience chosen"
      assert_not_includes response.body, "No audience yet"
    end

    test "publishing with an audience succeeds" do
      file_in_global(@workflow)

      post workflow_publishing_path(@workflow)

      assert_predicate @workflow.reload, :published?
    end
  end
end
