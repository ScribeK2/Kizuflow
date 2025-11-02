class TemplatesController < ApplicationController
  def index
    @templates = if params[:search].present?
      Template.search(params[:search])
    else
      Template.public_templates
    end
    @templates = @templates.order(:name)
  end

  def show
    @template = Template.find(params[:id])
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

