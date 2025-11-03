class DashboardController < ApplicationController
  def index
    # Show workflows visible to current user based on their role
    @workflows = Workflow.visible_to(current_user).recent.limit(10)
    @workflow_count = Workflow.visible_to(current_user).count
  end
end

