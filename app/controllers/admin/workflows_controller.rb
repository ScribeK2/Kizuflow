class Admin::WorkflowsController < ApplicationController
  before_action :ensure_admin!

  def index
    @workflows = Workflow.includes(:user).order(created_at: :desc)
  end

  def show
    @workflow = Workflow.find(params[:id])
  end
end

