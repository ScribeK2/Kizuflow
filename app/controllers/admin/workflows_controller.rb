class Admin::WorkflowsController < Admin::BaseController

  def index
    @workflows = Workflow.includes(:user).order(created_at: :desc)
  end

  def show
    @workflow = Workflow.find(params[:id])
  end
end
