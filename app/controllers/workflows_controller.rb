class WorkflowsController < ApplicationController
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :export, :export_pdf, :preview, :variables, :save_as_template]
  before_action :ensure_editor_or_admin!, only: [:new, :create, :import, :import_file]
  before_action :ensure_can_view_workflow!, only: [:show, :export, :export_pdf]
  before_action :ensure_can_edit_workflow!, only: [:edit, :update, :save_as_template]
  before_action :ensure_can_delete_workflow!, only: [:destroy]

  def index
    @workflows = Workflow.visible_to(current_user).recent
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
    pdf.text @workflow.description_text, size: 12 if @workflow.description_text.present?
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

  def import
    # Show import form
  end

  def import_file
    unless params[:file].present?
      redirect_to import_workflows_path, alert: "Please select a file to import."
      return
    end

    uploaded_file = params[:file]
    file_content = uploaded_file.read
    
    # Validate file size (max 10MB)
    if file_content.bytesize > 10.megabytes
      redirect_to import_workflows_path, alert: "File is too large. Maximum size is 10MB."
      return
    end

    # Detect file format
    format = detect_file_format(uploaded_file.original_filename, uploaded_file.content_type)
    
    unless format
      redirect_to import_workflows_path, alert: "Unsupported file format. Please use JSON, CSV, YAML, or Markdown files."
      return
    end

    # Parse file
    parser = create_parser(format, file_content)
    workflow_data = parser.parse

    unless workflow_data
      redirect_to import_workflows_path, alert: "Failed to parse file: #{parser.errors.join(', ')}"
      return
    end

    # Create workflow with import metadata
    @workflow = current_user.workflows.build(
      title: workflow_data[:title],
      description: workflow_data[:description] || "",
      steps: workflow_data[:steps] || [],
      is_public: false
    )

    # Store import metadata in a way we can access later
    @import_metadata = workflow_data[:import_metadata] || {}
    @import_warnings = parser.warnings
    @import_errors = parser.errors

    # Check if workflow has incomplete steps
    @has_incomplete_steps = workflow_data[:steps]&.any? { |step| step['_import_incomplete'] }

    # Try to save (validation will skip incomplete imported steps)
    if @workflow.save
      # If there are warnings or incomplete steps, redirect to edit with a notice
      if @has_incomplete_steps || @import_warnings.any?
        notice_parts = []
        notice_parts << "Workflow imported successfully!"
        notice_parts << "#{incomplete_steps_count} incomplete step(s) need attention." if @has_incomplete_steps
        notice_parts << "#{@import_warnings.count} warning(s) occurred." if @import_warnings.any?
        
        redirect_to edit_workflow_path(@workflow), notice: notice_parts.join(" ")
      else
        redirect_to @workflow, notice: "Workflow imported successfully!"
      end
    else
      redirect_to import_workflows_path, alert: "Failed to create workflow: #{@workflow.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:id])
  end

  # Override parent methods to use @workflow instance variable
  def ensure_can_view_workflow!
    unless @workflow.can_be_viewed_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to view this workflow."
    end
  end

  def ensure_can_edit_workflow!
    unless @workflow.can_be_edited_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to edit this workflow."
    end
  end

  def ensure_can_delete_workflow!
    unless @workflow.can_be_deleted_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to delete this workflow."
    end
  end

  def workflow_params
    # Permit nested steps hash structure
    params.require(:workflow).permit(:title, :description, :is_public, steps: [
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

  def detect_file_format(filename, content_type)
    extension = File.extname(filename).downcase
    
    case extension
    when '.json'
      :json
    when '.csv'
      :csv
    when '.yaml', '.yml'
      :yaml
    when '.md', '.markdown'
      :markdown
    else
      # Try content type as fallback
      case content_type
      when 'application/json', 'text/json'
        :json
      when 'text/csv', 'application/csv'
        :csv
      when 'text/x-yaml', 'application/x-yaml'
        :yaml
      when 'text/markdown', 'text/x-markdown'
        :markdown
      else
        nil
      end
    end
  end

  def create_parser(format, file_content)
    # Rails should autoload services automatically, but ensure it's loaded
    # Using const_get to handle autoloading gracefully
    case format
    when :json
      WorkflowParsers::JsonParser.new(file_content)
    when :csv
      WorkflowParsers::CsvParser.new(file_content)
    when :yaml
      WorkflowParsers::YamlParser.new(file_content)
    when :markdown
      WorkflowParsers::MarkdownParser.new(file_content)
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  rescue NameError => e
    # If autoloading fails, try explicit require
    Rails.logger.warn("Failed to autoload WorkflowParsers: #{e.message}")
    require Rails.root.join('app', 'services', 'workflow_parsers', 'base_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'json_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'csv_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'yaml_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'markdown_parser')
    retry
  end

  def incomplete_steps_count
    @workflow.steps&.count { |step| step['_import_incomplete'] } || 0
  end
end
