class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  
  # Devise redirect methods
  def after_sign_in_path_for(resource)
    root_path
  end
  
  def after_sign_up_path_for(resource)
    root_path
  end
  
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  # Authorization methods
  
  # Ensure user is an admin
  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You don't have permission to access this page."
    end
  end

  # Ensure user is an editor or admin
  def ensure_editor_or_admin!
    unless current_user&.can_edit_workflows?
      redirect_to root_path, alert: "You don't have permission to perform this action."
    end
  end

  # Check if user can view a workflow
  def ensure_can_view_workflow!(workflow)
    unless workflow.can_be_viewed_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to view this workflow."
    end
  end

  # Check if user can edit a workflow
  def ensure_can_edit_workflow!(workflow)
    unless workflow.can_be_edited_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to edit this workflow."
    end
  end

  # Check if user can delete a workflow
  def ensure_can_delete_workflow!(workflow)
    unless workflow.can_be_deleted_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to delete this workflow."
    end
  end
end

