# frozen_string_literal: true

require 'test_helper'

module Workflows
  class PublishingsControllerTest < ActionDispatch::IntegrationTest
    def setup
      Bullet.enable = false
      @editor = User.create!(
        email: "editor-#{SecureRandom.hex(4)}@example.com",
        password: 'password123!',
        password_confirmation: 'password123!',
        role: 'editor'
      )
      @workflow = file_in_global(Workflow.create!(title: 'Publishable Flow', user: @editor))
      sign_in @editor
    end

    def teardown
      Bullet.enable = true
    end

    test 'create publishes workflow with resolve step' do
      q = Steps::Question.create!(
        workflow: @workflow, uuid: SecureRandom.uuid, position: 0,
        title: 'Ask', question: 'What?', answer_type: 'text'
      )
      r = Steps::Resolve.create!(
        workflow: @workflow, uuid: SecureRandom.uuid, position: 1,
        title: 'Done', resolution_type: 'success'
      )
      Transition.create!(step: q, target_step: r, position: 0)
      @workflow.update!(start_step: q)

      assert_difference 'WorkflowVersion.count', 1 do
        post workflow_publishing_path(@workflow)
      end

      assert_redirected_to workflow_path(@workflow)
      assert_match(/published/i, flash[:notice])
      assert_equal 'published', @workflow.reload.status
    end

    test 'create without steps returns error' do
      post workflow_publishing_path(@workflow)

      # edit=true: a failed publish must leave the builder in edit mode. Dropping
      # it swapped the header for Edit/Run Scenario/Export and removed "Add a
      # step", so the user was told to fix something and lost the tools to do it.
      assert_redirected_to workflow_path(@workflow, edit: true)
      assert_match(/failed to publish/i, flash[:alert])
    end

    test 'create requires authentication' do
      sign_out @editor
      post workflow_publishing_path(@workflow)

      assert_redirected_to new_user_session_path
    end
    # --- set publishing ---------------------------------------------------

    def resolving_draft(title)
      wf = Workflow.create!(title: title, user: @editor, status: 'draft', graph_mode: true)
      q = Steps::Question.create!(workflow: wf, uuid: SecureRandom.uuid, position: 0,
                                  title: 'Q', question: 'What?', answer_type: 'text')
      r = Steps::Resolve.create!(workflow: wf, uuid: SecureRandom.uuid, position: 1,
                                 title: 'Done', resolution_type: 'success')
      Transition.create!(step: q, target_step: r, position: 0)
      wf.update!(start_step: q)
      file_in_global(wf)
    end

    # Question branches to the handoff first, falling back to Resolve, so the
    # sub_flow step is reachable and the Resolve is not orphaned.
    def hand_off(source, target)
      question = source.steps.find_by(type: 'Steps::Question')
      resolve  = source.steps.find_by(type: 'Steps::Resolve')
      step = Steps::SubFlow.create!(workflow: source, uuid: SecureRandom.uuid,
                                    position: source.steps.count,
                                    title: "To #{target.title}",
                                    sub_flow_workflow_id: target.id, sub_flow_returns: false)
      Transition.find_by(step: question, target_step: resolve).update!(position: 1)
      Transition.create!(step: question, target_step: step, position: 0)
      step
    end

    test 'a workflow with no draft dependencies publishes directly' do
      wf = resolving_draft('Standalone')

      post workflow_publishing_path(wf)

      assert_redirected_to workflow_path(wf)
      assert_equal 'published', wf.reload.status
    end

    test 'a workflow with draft dependencies redirects to the confirmation' do
      a = resolving_draft('Set Root')
      b = resolving_draft('Needed Draft')
      hand_off(a, b)

      post workflow_publishing_path(a)

      assert_redirected_to confirm_workflow_publishing_path(a)
      assert_equal 'draft', a.reload.status, 'nothing publishes before confirmation'
      assert_equal 'draft', b.reload.status
    end

    test 'the confirmation page names every member of the set' do
      a = resolving_draft('Set Root')
      b = resolving_draft('Needed Draft')
      hand_off(a, b)

      get confirm_workflow_publishing_path(a)

      assert_response :success
      assert_includes response.body, 'Needed Draft'
      assert_includes response.body, 'Set Root'
    end

    test 'publish_set publishes the whole set' do
      a = resolving_draft('Set Root')
      b = resolving_draft('Needed Draft')
      hand_off(a, b)
      hand_off(b, a)

      post workflow_publishing_path(a), params: { publish_set: '1' }

      assert_redirected_to workflow_path(a)
      assert_equal 'published', a.reload.status
      assert_equal 'published', b.reload.status
    end

    test 'the confirmation page redirects away when the set is only one workflow' do
      wf = resolving_draft('Lonely')

      get confirm_workflow_publishing_path(wf)

      assert_redirected_to workflow_path(wf)
    end
  end
end
