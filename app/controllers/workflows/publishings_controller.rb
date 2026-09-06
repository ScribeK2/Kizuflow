module Workflows
  class PublishingsController < BaseController
    before_action :ensure_can_edit_workflow!

    # POST /workflows/:workflow_id/publishing
    def create
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
  end
end
