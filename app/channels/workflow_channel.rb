class WorkflowChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to updates for a specific workflow
    workflow = Workflow.find(params[:workflow_id])
    
    # Ensure the user owns the workflow
    if workflow.user == current_user
      stream_from "workflow:#{workflow.id}"
      stream_from "workflow:#{workflow.id}:autosave"
    else
      reject
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  # Handle auto-save requests from the client
  def autosave(data)
    workflow = Workflow.find(params[:workflow_id])
    
    # Ensure the user owns the workflow
    return unless workflow.user == current_user
    
    # Convert data to Rails-friendly format
    # Handle both string keys and symbol keys
    title = data["title"] || data[:title] || workflow.title
    steps_data = data["steps"] || data[:steps] || []
    
    # Convert steps data to ensure proper format (string keys, handle nested arrays)
    formatted_steps = steps_data.map do |step|
      formatted_step = {}
      
      # Convert all keys to strings and handle nested structures
      step.each do |key, value|
        key_str = key.to_s
        
        case key_str
        when "attachments"
          # Ensure attachments is an array
          formatted_step[key_str] = value.is_a?(Array) ? value : []
        when "options"
          # Ensure options is an array of hashes
          if value.is_a?(Array)
            formatted_step[key_str] = value.map do |opt|
              if opt.is_a?(Hash)
                opt.transform_keys(&:to_s)
              else
                opt
              end
            end
          else
            formatted_step[key_str] = []
          end
        when "branches"
          # Ensure branches is an array of hashes
          if value.is_a?(Array)
            formatted_step[key_str] = value.map do |branch|
              if branch.is_a?(Hash)
                branch.transform_keys(&:to_s)
              else
                branch
              end
            end
          else
            formatted_step[key_str] = []
          end
        else
          # Regular field - convert to string
          formatted_step[key_str] = value
        end
      end
      
      formatted_step
    end
    
    # Build workflow params
    # Note: We skip description for now since rich text handling via ActionCable
    # requires special handling. Description will be saved via regular form submission.
    workflow_params = {
      title: title,
      steps: formatted_steps
    }
    
    # Debug logging
    Rails.logger.info "Autosave: Updating workflow #{workflow.id} with #{formatted_steps.length} steps"
    
    # Update workflow with the provided data
    # Skip validation for autosave - allow incomplete forms to be saved
    # This allows users to save work in progress without filling out all required fields
    begin
      workflow.title = workflow_params[:title] unless workflow_params[:title].blank?
      workflow.steps = formatted_steps
      workflow.save(validate: false)
      
      # Broadcast success to all subscribers
      broadcast_to_workflow(workflow, { status: "saved", timestamp: Time.current.iso8601 })
      Rails.logger.info "Autosave: Successfully saved workflow #{workflow.id}"
    rescue => e
      # Broadcast errors if save failed
      Rails.logger.error "Autosave: Failed to save workflow #{workflow.id}: #{e.message}"
      broadcast_to_workflow(workflow, { 
        status: "error", 
        errors: [e.message],
        timestamp: Time.current.iso8601 
      })
    end
  end

  private

  def broadcast_to_workflow(workflow, message)
    ActionCable.server.broadcast("workflow:#{workflow.id}:autosave", message)
  end
end

