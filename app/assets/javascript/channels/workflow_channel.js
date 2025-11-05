import consumer from "./consumer"

// Create a function to subscribe to workflow channel
export function subscribeToWorkflow(workflowId, callbacks = {}) {
  const subscription = consumer.subscriptions.create(
    { channel: "WorkflowChannel", workflow_id: workflowId },
    {
      connected() {
        console.log("Connected to WorkflowChannel for workflow", workflowId)
        if (callbacks.connected) callbacks.connected()
      },

      disconnected() {
        console.log("Disconnected from WorkflowChannel")
        if (callbacks.disconnected) callbacks.disconnected()
      },

      received(data) {
        console.log("Received data from WorkflowChannel:", data)
        
        // Handle autosave status updates (from autosave stream)
        if (data.status === "saved" || data.status === "error") {
          console.log("Autosave status received:", data.status, data)
          // Dispatch custom event for autosave controller to handle
          document.dispatchEvent(new CustomEvent("workflow:autosaved", { 
            detail: { timestamp: data.timestamp, status: data.status, errors: data.errors } 
          }))
          if (callbacks.saved) callbacks.saved(data)
          if (callbacks.error && data.status === "error") callbacks.error(data)
          return
        }
        
        // Handle presence updates (from presence stream)
        if (data.type === "user_joined" || data.type === "user_left" || data.active_users) {
          console.log("Presence update received:", data.type)
          document.dispatchEvent(new CustomEvent("workflow:presence", { 
            detail: data 
          }))
          if (callbacks.presence) callbacks.presence(data)
          return
        }
        
        // Handle real-time collaboration updates (from main workflow stream)
        if (data.type) {
          console.log("Collaboration update received:", data.type, data)
          document.dispatchEvent(new CustomEvent(`workflow:${data.type}`, { 
            detail: data 
          }))
          if (callbacks.update) callbacks.update(data)
        }
        
        // Legacy callback support
        if (callbacks.received) {
          callbacks.received(data)
        }
      },

      // Send autosave data to server
      autosave(data) {
        this.perform("autosave", data)
      },
      
      // Send step update to other users
      stepUpdate(data) {
        this.perform("step_update", data)
      },
      
      // Send step addition to other users
      stepAdded(data) {
        this.perform("step_added", data)
      },
      
      // Send step removal to other users
      stepRemoved(data) {
        this.perform("step_removed", data)
      },
      
      // Send step reordering to other users
      stepsReordered(data) {
        this.perform("steps_reordered", data)
      },
      
      // Send metadata update to other users
      workflowMetadataUpdate(data) {
        this.perform("workflow_metadata_update", data)
      }
    }
  )
  
  // Expose helper methods
  subscription.broadcastStepUpdate = function(stepIndex, stepData) {
    this.stepUpdate({ step_index: stepIndex, step_data: stepData })
  }
  
  subscription.broadcastStepAdded = function(stepIndex, stepType, stepData) {
    this.stepAdded({ step_index: stepIndex, step_type: stepType, step_data: stepData })
  }
  
  subscription.broadcastStepRemoved = function(stepIndex) {
    this.stepRemoved({ step_index: stepIndex })
  }
  
  subscription.broadcastStepsReordered = function(newOrder) {
    this.stepsReordered({ new_order: newOrder })
  }
  
  subscription.broadcastMetadataUpdate = function(field, value) {
    this.workflowMetadataUpdate({ field: field, value: value })
  }
  
  return subscription
}

// Export default subscription for backward compatibility
export default subscribeToWorkflow


