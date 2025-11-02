class DashboardController < ApplicationController
  def index
    @workflows = current_user.workflows.recent.limit(10)
    @workflow_count = current_user.workflows.count
  end
end

