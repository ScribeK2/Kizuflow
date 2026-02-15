class FoldersController < ApplicationController
  before_action :ensure_editor_or_admin!

  def move_workflow
    folder_id = params[:folder_id]
    @folder = folder_id.present? && folder_id != "uncategorized" ? Folder.find(folder_id) : nil
    @workflow = Workflow.find(params[:workflow_id])
    @group = @folder&.group || Group.find(params[:group_id])

    group_workflow = GroupWorkflow.find_by!(group: @group, workflow: @workflow)
    group_workflow.update!(folder: @folder)

    redirect_to workflows_path(group_id: @group.id), notice: "Workflow moved#{@folder ? " to #{@folder.name}" : " to Uncategorized"}."
  end

  private

  def ensure_editor_or_admin!
    unless current_user&.can_edit_workflows?
      redirect_to workflows_path, alert: "You don't have permission to move workflows."
    end
  end
end
