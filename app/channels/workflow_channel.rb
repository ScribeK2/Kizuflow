require 'set'

class WorkflowChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to updates for a specific workflow
    workflow = Workflow.find(params[:workflow_id])
    
    # Allow authorized users (editors/admins) to subscribe, not just owners
    if workflow.can_be_edited_by?(current_user)
      stream_from "workflow:#{workflow.id}"
      stream_from "workflow:#{workflow.id}:autosave"
      stream_from "workflow:#{workflow.id}:presence"
      
      # Track presence
      add_presence(workflow)
      
      # Notify other users that this user joined
      broadcast_presence_update(workflow, { type: "user_joined", user: user_info })
    else
      reject
    end
  end

  def unsubscribed
    # Clean up presence when user leaves
    workflow = Workflow.find_by(id: params[:workflow_id])
    if workflow
      remove_presence(workflow)
      broadcast_presence_update(workflow, { type: "user_left", user: user_info })
    end
  end

  # Handle title/description updates from other users
  def workflow_metadata_update(data)
    workflow = Workflow.find(params[:workflow_id])
    return unless workflow.can_be_edited_by?(current_user)
    
    Rails.logger.info "WorkflowChannel: Broadcasting workflow_metadata_update - field: #{data['field']}, value length: #{data['value'].to_s.length}"
    
    ActionCable.server.broadcast("workflow:#{workflow.id}", {
      type: "workflow_metadata_update",
      field: data["field"], # "title" or "description"
      value: data["value"],
      user: user_info,
      timestamp: Time.current.iso8601
    })
  end

  # Handle step updates from other users
  def step_update(data)
    workflow = Workflow.find(params[:workflow_id])
    return unless workflow.can_be_edited_by?(current_user)
    
    Rails.logger.info "WorkflowChannel: Broadcasting step_update - step_index: #{data['step_index']}"
    
    # Don't broadcast back to the sender
    ActionCable.server.broadcast("workflow:#{workflow.id}", {
      type: "step_update",
      step_index: data["step_index"],
      step_data: data["step_data"],
      user: user_info,
      timestamp: Time.current.iso8601
    })
  end

  # Handle auto-save requests from the client
  def autosave(data)
    workflow = Workflow.find(params[:workflow_id])
    
    # Ensure the user can edit the workflow (not just own it)
    return unless workflow.can_be_edited_by?(current_user)
    
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

  def user_info
    {
      id: current_user.id,
      email: current_user.email,
      name: current_user.email.split("@").first.titleize
    }
  end

  def add_presence(workflow)
    # Use Redis if available, otherwise use a class-level store
    presence_key = "workflow:#{workflow.id}:presence"
    if defined?(Redis) && Redis.current
      Redis.current.sadd(presence_key, current_user.id)
      Redis.current.expire(presence_key, 3600) # Expire after 1 hour of inactivity
    else
      # Fallback: use class-level store (works across connections)
      @@presence_store ||= {}
      @@presence_store[presence_key] ||= Set.new
      @@presence_store[presence_key].add(current_user.id)
    end
  end

  def remove_presence(workflow)
    presence_key = "workflow:#{workflow.id}:presence"
    if defined?(Redis) && Redis.current
      Redis.current.srem(presence_key, current_user.id)
    else
      @@presence_store ||= {}
      @@presence_store[presence_key]&.delete(current_user.id)
      @@presence_store.delete(presence_key) if @@presence_store[presence_key]&.empty?
    end
  end

  def get_active_users(workflow)
    presence_key = "workflow:#{workflow.id}:presence"
    
    if defined?(Redis) && Redis.current
      user_ids = Redis.current.smembers(presence_key).map(&:to_i)
      User.where(id: user_ids).map { |u| { id: u.id, email: u.email, name: u.email.split("@").first.titleize } }
    else
      # Fallback: in-memory store
      @@presence_store ||= {}
      user_ids = (@@presence_store[presence_key] || Set.new).to_a
      User.where(id: user_ids).map { |u| { id: u.id, email: u.email, name: u.email.split("@").first.titleize } }
    end
  end

  def broadcast_presence_update(workflow, message)
    ActionCable.server.broadcast("workflow:#{workflow.id}:presence", {
      **message,
      active_users: get_active_users(workflow),
      timestamp: Time.current.iso8601
    })
  end
end

