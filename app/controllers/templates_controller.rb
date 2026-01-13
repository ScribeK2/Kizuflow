class TemplatesController < ApplicationController
  before_action :ensure_editor_or_admin!, only: [:use]

  def index
    base_scope = current_user&.admin? ? Template.all : Template.public_templates
    @templates = if params[:search].present?
      base_scope.search(params[:search])
    else
      base_scope
    end
    @templates = @templates.order(:name)
  end

  def show
    @template = Template.find(params[:id])
    # Only show public templates to non-admins
    unless current_user&.admin? || @template.is_public?
      redirect_to templates_path, alert: "You don't have permission to view this template."
    end
  end

  def use
    @template = Template.find(params[:id])
    @workflow = current_user.workflows.build(
      title: "#{@template.name} - #{Time.current.strftime('%Y-%m-%d')}",
      description: @template.description,
      steps: @template.workflow_data
    )

    if @workflow.save
      redirect_to edit_workflow_path(@workflow), notice: "Workflow created from template. Customize it as needed."
    else
      redirect_to templates_path, alert: "Failed to create workflow from template."
    end
  end
end

