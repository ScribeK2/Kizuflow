class DashboardController < ApplicationController
  def index
    # Workflow counts
    @workflow_count = Workflow.visible_to(current_user).count
    @published_count = @workflow_count

    # Draft count (editors/admins only - regular users can't create workflows)
    @draft_count = current_user.can_create_workflows? ? current_user.workflows.drafts.count : 0

    # Recent workflows: for editors/admins, include their own drafts alongside published
    if current_user.can_create_workflows?
      visible_ids = Workflow.visible_to(current_user).select(:id)
      draft_ids = current_user.workflows.drafts.select(:id)
      @workflows = Workflow.where(id: visible_ids).or(Workflow.where(id: draft_ids))
                           .order(created_at: :desc).limit(10)
    else
      @workflows = Workflow.visible_to(current_user).recent.limit(10)
    end

    # Simulation stats (scoped to current user)
    user_simulations = Simulation.where(user: current_user)
    @simulation_total = user_simulations.count
    @simulation_completed = user_simulations.where(status: "completed").count
    @simulation_active = user_simulations.where(status: "active").count
    @simulation_completion_rate = @simulation_total > 0 ? ((@simulation_completed * 100.0) / @simulation_total).round : 0

    # Recent simulations (last 5, eager-load workflow to avoid N+1)
    @recent_simulations = user_simulations.includes(:workflow)
                                          .order(created_at: :desc)
                                          .limit(5)
  end
end
