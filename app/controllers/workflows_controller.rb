class WorkflowsController < ApplicationController
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :export, :export_pdf, :preview, :variables, :save_as_template]
  before_action :ensure_owner, only: [:edit, :update, :destroy, :export, :export_pdf, :save_as_template]

  def index
    @workflows = current_user.workflows.recent
  end

  def show
  end

  def new
    @workflow = current_user.workflows.build
  end

  def create
    @workflow = current_user.workflows.build(workflow_params)
    
    if @workflow.save
      redirect_to @workflow, notice: "Workflow was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workflow.update(workflow_params)
      redirect_to @workflow, notice: "Workflow was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workflow.destroy
    redirect_to workflows_path, notice: "Workflow was successfully deleted."
  end

  def export
    send_data @workflow.to_json(except: [:id, :user_id]), 
              filename: "#{@workflow.title.parameterize}.json",
              type: "application/json"
  end

  def export_pdf
    require "prawn"
    
    pdf = Prawn::Document.new
    pdf.text @workflow.title, size: 24, style: :bold
    pdf.move_down 10
    pdf.text @workflow.description, size: 12 if @workflow.description.present?
    pdf.move_down 20

    if @workflow.steps.present?
      @workflow.steps.each_with_index do |step, index|
        pdf.text "#{index + 1}. #{step['title']}", size: 14, style: :bold
        pdf.text step['description'], size: 10 if step['description'].present?
        pdf.move_down 10
      end
    end

    send_data pdf.render, filename: "#{@workflow.title.parameterize}.pdf", type: "application/pdf"
  end

  def preview
    # Parse step data from params
    step_data = parse_step_from_params
    step_index = params[:step_index].to_i
    
    # Render preview partial within Turbo Frame
    render partial: "workflows/preview_pane", 
           locals: { step: step_data, index: step_index },
           formats: [:html]
  end

  def variables
    # Return available variables from workflow
    variables = @workflow.variables
    
    render json: { variables: variables }
  end

  def save_as_template
    template_params = params.require(:template).permit(:name, :category, :description, :is_public)
    
    template_data = @workflow.convert_to_template(
      name: template_params[:name],
      category: template_params[:category],
      description: template_params[:description],
      is_public: template_params[:is_public] == "true"
    )
    
    @template = Template.new(template_data)
    
    if @template.save
      redirect_to templates_path, notice: "Template '#{@template.name}' was successfully created."
    else
      redirect_to edit_workflow_path(@workflow), alert: "Failed to save template: #{@template.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:id])
  end

  def ensure_owner
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to access this workflow."
    end
  end

  def workflow_params
    # Permit nested steps hash structure
    params.require(:workflow).permit(:title, :description, steps: [
      :index, :type, :title, :description, :question, :answer_type, :variable_name,
      :condition, :true_path, :false_path, :else_path, :action_type, :instructions,
      options: [:label, :value],
      branches: [:condition, :path],
      attachments: []
    ])
  end

  def parse_step_from_params
    step_params = params[:step] || {}
    
    # Parse options if provided as JSON string or array
    options = step_params[:options]
    if options.is_a?(String)
      begin
        options = JSON.parse(options)
      rescue JSON::ParserError
        options = []
      end
    elsif options.is_a?(Array)
      # Options is already an array, process it
      options = options.map do |opt|
        if opt.is_a?(Hash)
          { 'label' => opt['label'] || opt[:label], 'value' => opt['value'] || opt[:value] }
        else
          { 'label' => opt.to_s, 'value' => opt.to_s }
        end
      end
    elsif options.is_a?(ActionController::Parameters)
      # Handle Rails strong parameters
      options = options.values.map do |opt|
        { 'label' => opt['label'] || opt[:label], 'value' => opt['value'] || opt[:value] }
      end
    else
      options = []
    end

    # Parse attachments if provided
    attachments = step_params[:attachments]
    if attachments.is_a?(String)
      begin
        attachments = JSON.parse(attachments)
      rescue JSON::ParserError
        attachments = []
      end
    elsif attachments.is_a?(Array)
      attachments = attachments.compact
    else
      attachments = []
    end

    {
      type: step_params[:type] || "",
      title: step_params[:title] || "",
      description: step_params[:description] || "",
      question: step_params[:question] || "",
      answer_type: step_params[:answer_type] || "",
      variable_name: step_params[:variable_name] || "",
      options: options || [],
      condition: step_params[:condition] || "",
      true_path: step_params[:true_path] || "",
      false_path: step_params[:false_path] || "",
      action_type: step_params[:action_type] || "",
      instructions: step_params[:instructions] || "",
      attachments: attachments || []
    }
  end
end

