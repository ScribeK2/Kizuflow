class WorkflowVersionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workflow
  before_action :set_version, only: [:show, :restore]
  before_action :ensure_can_view_workflow!

  def show
  end

  def restore
    unless @workflow.can_be_edited_by?(current_user)
      redirect_to @workflow, alert: "You don't have permission to restore versions."
      return
    end

    Workflow.transaction do
      @workflow.update!(graph_mode: @version.metadata_snapshot["graph_mode"] || false)
      restore_ar_steps_from_snapshot(@version.steps_snapshot, @version.metadata_snapshot["start_node_uuid"])
    end

    redirect_to edit_workflow_path(@workflow), notice: "Restored version #{@version.version_number}."
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:workflow_id])
  end

  def set_version
    @version = @workflow.versions.find(params[:id])
  end

  def restore_ar_steps_from_snapshot(steps_snapshot, start_node_uuid)
    # Clear existing AR steps
    @workflow.steps.destroy_all
    @workflow.update_column(:start_step_id, nil)

    return if steps_snapshot.blank?

    step_records = {}
    steps_snapshot.each_with_index do |step_data, index|
      uuid = step_data["id"].presence || SecureRandom.uuid
      step_type = step_data["type"].to_s
      sti_class = case step_type
                  when "question"  then Steps::Question
                  when "action"    then Steps::Action
                  when "message"   then Steps::Message
                  when "escalate"  then Steps::Escalate
                  when "resolve"   then Steps::Resolve
                  when "sub_flow"  then Steps::SubFlow
                  else Steps::Action
                  end

      attrs = { workflow: @workflow, uuid: uuid, position: index, title: step_data["title"] }

      case step_type
      when "question"
        attrs.merge!(question: step_data["question"], answer_type: step_data["answer_type"],
                      variable_name: step_data["variable_name"], options: step_data["options"])
      when "action"
        attrs.merge!(can_resolve: step_data["can_resolve"] || false, action_type: step_data["action_type"],
                      output_fields: step_data["output_fields"])
      when "escalate"
        attrs.merge!(target_type: step_data["target_type"], target_value: step_data["target_value"],
                      priority: step_data["priority"])
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

    # Restore transitions
    steps_snapshot.each do |step_data|
      source = step_records[step_data["id"]]
      next unless source && step_data["transitions"].present?

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

  def ensure_can_view_workflow!
    unless @workflow.can_be_viewed_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to view this workflow."
    end
  end
end
