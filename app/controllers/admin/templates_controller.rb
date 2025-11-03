class Admin::TemplatesController < ApplicationController
  before_action :ensure_admin!

  def index
    @templates = Template.order(:name)
  end

  def new
    @template = Template.new
  end

  def create
    @template = Template.new(template_params)
    parse_workflow_data(@template)
    if @template.save
      redirect_to admin_templates_path, notice: "Template '#{@template.name}' was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @template = Template.find(params[:id])
  end

  def update
    @template = Template.find(params[:id])
    @template.assign_attributes(template_params)
    parse_workflow_data(@template)
    if @template.save
      redirect_to admin_templates_path, notice: "Template '#{@template.name}' was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @template = Template.find(params[:id])
    @template.destroy
    redirect_to admin_templates_path, notice: "Template was successfully deleted."
  end

  private

  def template_params
    params.require(:template).permit(:name, :description, :category, :is_public, :workflow_data)
  end

  def parse_workflow_data(template)
    if params[:template][:workflow_data].present?
      begin
        workflow_data_json = params[:template][:workflow_data]
        template.workflow_data = JSON.parse(workflow_data_json)
      rescue JSON::ParserError => e
        template.errors.add(:workflow_data, "Invalid JSON format: #{e.message}")
      end
    end
  end
end

