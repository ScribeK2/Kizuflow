class TemplatesController < ApplicationController
  before_action :ensure_editor_or_admin!, only: [:use]

  def index
    base_scope = current_user&.admin? ? Template.all : Template.public_templates
    @templates = if params[:search].present?
                   base_scope.search(params[:search])
                 else
                   base_scope
                 end
    @categories = base_scope.distinct.pluck(:category).compact.sort
    @templates = @templates.where(category: params[:category]) if params[:category].present?
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

    # Enforce same visibility rules as show
    unless current_user&.admin? || @template.is_public?
      redirect_to templates_path, alert: "You don't have permission to use this template."
      return
    end

    # Deep copy the workflow_data to avoid modifying the template
    workflow_data = JSON.parse(@template.workflow_data.to_json)

    # Ensure all steps have IDs and normalize the data
    workflow_data = normalize_template_steps(workflow_data) if workflow_data.present?

    # Detect graph mode: template must have graph_mode enabled AND steps with transitions
    has_transitions = workflow_data&.any? { |step| step['transitions'].is_a?(Array) }
    is_graph_mode = @template.graph_mode? && has_transitions
    start_node_uuid = if is_graph_mode && workflow_data.present?
                        @template.start_node_uuid.presence || workflow_data.first['id']
                      end

    @workflow = current_user.workflows.build(
      title: "#{@template.name} - #{Time.current.strftime('%Y-%m-%d')}",
      description: @template.description,
      graph_mode: is_graph_mode
    )

    if @workflow.save
      create_ar_steps_from_template(workflow_data, start_node_uuid)
      redirect_to edit_workflow_path(@workflow), notice: "Workflow created from template. Customize it as needed."
    else
      redirect_to templates_path, alert: "Failed to create workflow from template: #{@workflow.errors.full_messages.join(', ')}"
    end
  end

  private

  # Normalize template steps to ensure they're in the correct format for workflow creation
  # Handles both graph mode (transitions) and legacy linear mode (branches)
  def normalize_template_steps(steps)
    return [] unless steps.is_a?(Array)

    steps.each do |step|
      next unless step.is_a?(Hash)

      # Assign ID if missing
      step['id'] ||= SecureRandom.uuid

      # Ensure title is present (required)
      step['title'] ||= "Untitled Step"

      # Auto-convert deprecated step types (same mapping as import system)
      case step['type']
      when 'decision', 'simple_decision'
        step['type'] = 'question'
        step['answer_type'] ||= 'text'
        step['variable_name'] ||= ''
      when 'checkpoint'
        step['type'] = 'message'
        step['content'] ||= step.delete('checkpoint_message') || ''
      end

      # Normalize graph mode transitions
      if step['transitions'].is_a?(Array)
        step['transitions'] = step['transitions'].select do |transition|
          transition.is_a?(Hash) && transition['target_uuid'].present?
        end
      end
    end

    steps
  end

  def step_class_for(type)
    case type.to_s
    when "question"  then Steps::Question
    when "action"    then Steps::Action
    when "message"   then Steps::Message
    when "escalate"  then Steps::Escalate
    when "resolve"   then Steps::Resolve
    when "sub_flow"  then Steps::SubFlow
    else Steps::Action
    end
  end

  def create_ar_steps_from_template(steps_data, start_node_uuid)
    return if steps_data.blank?

    step_records = {}
    steps_data.each_with_index do |step_data, index|
      uuid = step_data["id"].presence || SecureRandom.uuid
      step_type = step_data["type"].to_s
      sti_class = step_class_for(step_type)

      attrs = { workflow: @workflow, uuid: uuid, position: index, title: step_data["title"] }

      case step_type
      when "question"
        attrs.merge!(question: step_data["question"], answer_type: step_data["answer_type"],
                      variable_name: step_data["variable_name"], options: step_data["options"])
      when "action"
        attrs.merge!(can_resolve: step_data["can_resolve"] || false, action_type: step_data["action_type"],
                      output_fields: step_data["output_fields"])
      when "message"
        attrs.merge!(can_resolve: step_data["can_resolve"] || false)
      when "escalate"
        attrs.merge!(target_type: step_data["target_type"], priority: step_data["priority"])
      when "resolve"
        attrs.merge!(resolution_type: step_data["resolution_type"], resolution_code: step_data["resolution_code"])
      when "sub_flow"
        attrs.merge!(sub_flow_workflow_id: step_data["target_workflow_id"])
      end

      step = sti_class.create!(attrs)
      step.update(instructions: step_data["instructions"]) if step_type == "action" && step_data["instructions"].present?
      step.update(content: step_data["content"]) if step_type == "message" && step_data["content"].present?
      step.update(notes: step_data["notes"]) if step_type == "escalate" && step_data["notes"].present?
      step_records[uuid] = step
    end

    # Create transitions
    steps_data.each do |step_data|
      source = step_records[step_data["id"]]
      next unless source && step_data["transitions"].is_a?(Array)

      step_data["transitions"].each_with_index do |t, pos|
        target = step_records[t["target_uuid"]]
        next unless target
        Transition.create!(step: source, target_step: target, condition: t["condition"], label: t["label"], position: pos)
      end
    end

    # Set start step
    if start_node_uuid.present? && step_records[start_node_uuid]
      @workflow.update_column(:start_step_id, step_records[start_node_uuid].id)
    elsif step_records.values.first
      @workflow.update_column(:start_step_id, step_records.values.first.id)
    end
  end
end
