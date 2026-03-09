class Admin::TemplatesController < Admin::BaseController

  def index
    @templates = Template.order(:name)
  end

  def new
    @template = Template.new
  end

  def edit
    @template = Template.find(params[:id])
  end

  def create
    @template = Template.new(template_params)
    parse_workflow_data(@template)
    if @template.save
      redirect_to admin_templates_path, notice: "Template '#{@template.name}' was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @template = Template.find(params[:id])
    @template.assign_attributes(template_params)
    parse_workflow_data(@template)
    if @template.save
      redirect_to admin_templates_path, notice: "Template '#{@template.name}' was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @template = Template.find(params[:id])
    @template.destroy
    redirect_to admin_templates_path, notice: "Template was successfully deleted."
  end

  private

  def template_params
    params.require(:template).permit(:name, :description, :category, :is_public,
                                     :graph_mode, :start_node_uuid, :workflow_data)
  end

  def parse_workflow_data(template)
    # Visual editor mode: parse steps from JSON hidden input
    if params[:template][:editor_mode] == 'visual' && params[:template][:visual_editor_steps_json].present?
      begin
        template.workflow_data = JSON.parse(params[:template][:visual_editor_steps_json])
        template.start_node_uuid = params[:template][:start_node_uuid] if params[:template][:start_node_uuid].present?
      rescue JSON::ParserError => e
        template.errors.add(:workflow_data, "Invalid visual editor JSON: #{e.message}")
      end
    elsif params[:template][:workflow_data].present?
      begin
        workflow_data_json = params[:template][:workflow_data]
        template.workflow_data = JSON.parse(workflow_data_json)
      rescue JSON::ParserError => e
        template.errors.add(:workflow_data, "Invalid JSON format: #{e.message}")
      end
    end
  end
end
