class NavController < ApplicationController
  # Override Devise's default redirect for JSON requests on search_data
  skip_before_action :authenticate_user!, only: :search_data
  before_action :authenticate_user_for_json!, only: :search_data

  def search_data
    if current_user.admin?
      workflows = Workflow.all
    else
      visible_ids = Workflow.visible_to(current_user).select(:id)
      own_ids = Workflow.where(user: current_user).select(:id)
      workflows = Workflow.where(id: visible_ids).or(Workflow.where(id: own_ids))
    end

    can_edit = current_user.can_edit_workflows?
    data = workflows.includes(:tags).with_rich_text_description.order(updated_at: :desc).map do |w|
      {
        id: w.id,
        title: w.title,
        description: w.description_text.to_s.truncate(120),
        tags: w.tags.pluck(:name),
        status: w.status,
        # A regular user cannot open the builder or the execution landing page, so
        # every result used to resolve to the bare Player index — twelve
        # workflows, one destination. Picking "UI Escalate" from search landed on
        # a list, with no sign it had heard which one you chose. Starting a run
        # is a POST (it creates a Scenario), so the result cannot link straight
        # into one; it carries the title instead, and the Player index prefills
        # its own filter with it, leaving the chosen workflow one click away.
        path: if current_user.regular?
                play_path(q: w.title)
              elsif can_edit
                workflow_path(w)
              else
                new_workflow_execution_path(w)
              end
      }
    end
    render json: data
  end

  private

  # Return 401 for unauthenticated JSON requests instead of Devise's redirect
  def authenticate_user_for_json!
    return if current_user

    head :unauthorized
  end
end
