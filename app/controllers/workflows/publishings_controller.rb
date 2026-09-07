module Workflows
  class PublishingsController < BaseController
    before_action :ensure_can_edit_workflow!

    # POST /workflows/:workflow_id/publishing
    def create
      members = WorkflowSetPublisher.closure_for(@workflow)

      # Publishing several workflows from one unqualified button press would be a
      # surprise. Show the set first; the second POST carries publish_set. Same
      # preview-then-commit shape the strict import uses.
      if members.size > 1 && params[:publish_set].blank?
        return redirect_to confirm_workflow_publishing_path(@workflow)
      end

      members.size > 1 ? publish_set : publish_one
    end

    # GET /workflows/:workflow_id/publishing/confirm
    def confirm
      @members = WorkflowSetPublisher.closure_for(@workflow)
      redirect_to workflow_path(@workflow) if @members.size <= 1
    end

    private

    def publish_one
      result = WorkflowPublisher.publish(@workflow, current_user, changelog: params[:changelog])

      if result.success?
        redirect_to @workflow, notice: "Workflow published as version #{result.version.version_number}."
      else
        # Back to the builder in edit mode. Redirecting to @workflow dropped
        # `edit=true`, so a failed publish silently swapped the header for
        # Edit/Run Scenario/Export and took "Add a step" away — the user is told
        # to fix something and simultaneously loses the tools to fix it.
        redirect_to workflow_path(@workflow, edit: true), alert: "Failed to publish: #{result.error}"
      end
    end

    def publish_set
      result = WorkflowSetPublisher.publish(@workflow, current_user, changelog: params[:changelog])

      if result.success?
        redirect_to @workflow, notice: "Published #{result.workflows.size} workflows together."
      else
        redirect_to workflow_path(@workflow, edit: true), alert: "Failed to publish: #{result.error}"
      end
    end
  end
end
