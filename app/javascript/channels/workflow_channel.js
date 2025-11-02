import consumer from "./consumer"

// Create a function to subscribe to workflow channel
export function subscribeToWorkflow(workflowId, callbacks = {}) {
  return consumer.subscriptions.create(
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
        
        // Handle autosave status updates
        if (data.status === "saved") {
          // Dispatch custom event for autosave controller to handle
          document.dispatchEvent(new CustomEvent("workflow:autosaved", { 
            detail: { timestamp: data.timestamp } 
          }))
          if (callbacks.saved) callbacks.saved(data)
        } else if (data.status === "error") {
          // Dispatch error event
          document.dispatchEvent(new CustomEvent("workflow:autosave-error", { 
            detail: { errors: data.errors } 
          }))
          if (callbacks.error) callbacks.error(data)
        } else if (callbacks.received) {
          callbacks.received(data)
        }
      },

      // Send autosave data to server
      autosave(data) {
        this.perform("autosave", data)
      }
    }
  )
}

// Export default subscription for backward compatibility
export default subscribeToWorkflow


