import { Controller } from "@hotwired/stimulus"
import { subscribeToWorkflow } from "../channels/workflow_channel"

export default class extends Controller {
  static targets = ["status"]
  static values = { 
    workflowId: Number,
    debounceMs: { type: Number, default: 1000 }
  }

  connect() {
    // Find the form element (the controller is on the form itself)
    this.formElement = this.element.tagName === "FORM" ? this.element : this.element.closest("form")
    
    if (!this.formElement) {
      console.error("Autosave controller: Form element not found")
      return
    }

    // Subscribe to workflow channel if workflow ID is available
    if (this.hasWorkflowIdValue) {
      this.subscription = subscribeToWorkflow(this.workflowIdValue, {
        connected: () => {
          console.log("Autosave: Connected to workflow channel")
          this.handleConnected()
        },
        disconnected: () => {
          console.log("Autosave: Disconnected from workflow channel")
          this.handleDisconnected()
        },
        saved: (data) => {
          console.log("Autosave: Received saved callback", data)
          this.handleSaved(data)
        },
        error: (data) => {
          console.log("Autosave: Received error callback", data)
          this.handleError(data)
        }
      })
      
      // Also listen for the custom event (backup)
      this.autosavedHandler = (event) => {
        console.log("Autosave: Received workflow:autosaved event", event.detail)
        if (event.detail.status === "saved") {
          this.handleSaved(event.detail)
        } else if (event.detail.status === "error") {
          this.handleError(event.detail)
        }
      }
      document.addEventListener("workflow:autosaved", this.autosavedHandler)
    }

    // Set up form change listeners
    this.debouncedAutosave = this.debounce(() => this.performAutosave(), this.debounceMsValue)
    
    // Store handlers so we can remove them later
    this.inputHandler = (event) => {
      // Skip autosave if this is a remote update from collaboration
      if (event.detail && event.detail.remoteUpdate) {
        return
      }
      this.debouncedAutosave()
    }
    
    this.changeHandler = (event) => {
      // Skip autosave if this is a remote update from collaboration
      if (event.detail && event.detail.remoteUpdate) {
        return
      }
      this.debouncedAutosave()
    }
    
    // Listen for form changes
    this.formElement.addEventListener("input", this.inputHandler)
    this.formElement.addEventListener("change", this.changeHandler)
    
    // Also listen for Trix changes
    this.formElement.addEventListener("trix-change", this.debouncedAutosave)
    
    // Initial status
    this.updateStatus("ready", "Ready to save")
  }

  disconnect() {
    // Cleanup
    if (this.formElement) {
      if (this.inputHandler) {
        this.formElement.removeEventListener("input", this.inputHandler)
      }
      if (this.changeHandler) {
        this.formElement.removeEventListener("change", this.changeHandler)
      }
      this.formElement.removeEventListener("trix-change", this.debouncedAutosave)
    }
    
    // Remove event listener
    if (this.autosavedHandler) {
      document.removeEventListener("workflow:autosaved", this.autosavedHandler)
    }
    
    // Unsubscribe from channel
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  performAutosave() {
    if (!this.hasWorkflowIdValue || !this.subscription) {
      console.warn("Cannot autosave: workflow ID or subscription missing")
      return
    }

    if (!this.formElement) {
      console.error("Cannot autosave: form element not found")
      return
    }

    console.log("Autosave: Starting autosave...")
    this.updateStatus("saving", "Saving...")
    
    // Collect form data
    const formData = new FormData(this.formElement)
    const workflowData = this.extractWorkflowData(formData)
    
    // Debug logging
    console.log("Autosave: Sending data to server", {
      workflowId: this.workflowIdValue,
      title: workflowData.title,
      stepsCount: workflowData.steps.length,
      steps: workflowData.steps
    })
    
    // Send to server via ActionCable
    this.subscription.autosave(workflowData)
  }

  extractWorkflowData(formData) {
    const data = {
      title: formData.get("workflow[title]") || "",
      description: formData.get("workflow[description]") || ""
    }

    // Extract steps data - Rails uses array notation workflow[steps][]
    // We need to group fields by their position in the form
    const steps = []
    const stepContainers = this.formElement.querySelectorAll(".step-item")
    
    stepContainers.forEach((container, containerIndex) => {
      const step = {}
      
      // Get all inputs within this step container
      const inputs = container.querySelectorAll("input, textarea, select")
      inputs.forEach(input => {
        const name = input.name
        if (!name || !name.startsWith("workflow[steps]")) return
        
        // Handle nested fields like workflow[steps][][attachments] or workflow[steps][][options][][label]
        if (name.includes("[attachments]")) {
          // Parse JSON string for attachments
          try {
            step.attachments = JSON.parse(input.value || "[]")
          } catch (e) {
            step.attachments = []
          }
        } else if (name.includes("[options]")) {
          // Handle options array - collect all option inputs
          if (!step.options) step.options = []
          const match = name.match(/\[options\]\[(\d+)\]\[(\w+)\]/)
          if (match) {
            const index = parseInt(match[1])
            const field = match[2]
            if (!step.options[index]) step.options[index] = {}
            step.options[index][field] = input.value
          }
        } else {
          // Regular field: workflow[steps][][field]
          const match = name.match(/workflow\[steps\]\[\]?\[(\w+)\]/)
          if (match) {
            const field = match[1]
            let value = input.value
            
            // Handle checkboxes
            if (input.type === "checkbox") {
              value = input.checked
            }
            
            // Skip if field already set (avoid overwriting)
            if (step[field] === undefined) {
              step[field] = value
            }
          }
        }
      })
      
      // Clean up options - remove empty ones
      if (step.options && Array.isArray(step.options)) {
        step.options = step.options.filter(opt => opt && (opt.label || opt.value))
      }
      
      // Handle branches for decision steps
      if (step.type === "decision") {
        const branches = []
        const branchItems = container.querySelectorAll(".branch-item")
        
        branchItems.forEach(branchItem => {
          const branch = {}
          const conditionInput = branchItem.querySelector("input[name*='[branches][][condition]']")
          const pathSelect = branchItem.querySelector("select[name*='[branches][][path]']")
          
          if (conditionInput) branch.condition = conditionInput.value
          if (pathSelect) branch.path = pathSelect.value
          
          if (branch.condition || branch.path) {
            branches.push(branch)
          }
        })
        
        if (branches.length > 0) {
          step.branches = branches
        }
        
        // Get else_path
        const elsePathSelect = container.querySelector("select[name*='[else_path]']")
        if (elsePathSelect && elsePathSelect.value) {
          step.else_path = elsePathSelect.value
        }
      }
      
      // Only add step if it has at least a type
      if (step.type) {
        steps.push(step)
      }
    })

    data.steps = steps
    return data
  }

  handleConnected() {
    console.log("Connected to workflow channel")
    this.updateStatus("ready", "Connected - ready to save")
  }

  handleDisconnected() {
    console.log("Disconnected from workflow channel")
    this.updateStatus("error", "Disconnected")
  }

  handleSaved(data) {
    console.log("Autosave successful:", data)
    const timestamp = data.timestamp ? new Date(data.timestamp).toLocaleTimeString() : new Date().toLocaleTimeString()
    this.updateStatus("saved", `Saved at ${timestamp}`)
    
    // Reset to ready after 3 seconds
    setTimeout(() => {
      if (this.hasStatusTarget && this.statusTarget.textContent.includes("Saved")) {
        this.updateStatus("ready", "Ready to save")
      }
    }, 3000)
  }

  handleError(data) {
    console.error("Autosave error:", data.errors)
    const errorMessage = data.errors && data.errors.length > 0 
      ? data.errors.join(", ") 
      : "Unknown error"
    this.updateStatus("error", `Error: ${errorMessage}`)
    
    // Reset to ready after 5 seconds
    setTimeout(() => {
      if (this.hasStatusTarget) {
        this.updateStatus("ready", "Ready to save")
      }
    }, 5000)
  }

  updateStatus(status, message) {
    if (!this.hasStatusTarget) return

    // Update status text
    this.statusTarget.textContent = message

    // Update status classes
    this.statusTarget.className = "text-sm font-medium "
    
    switch(status) {
      case "saving":
        this.statusTarget.className += "text-yellow-600"
        break
      case "saved":
        this.statusTarget.className += "text-green-600"
        break
      case "error":
        this.statusTarget.className += "text-red-600"
        break
      default:
        this.statusTarget.className += "text-gray-600"
    }
  }

  debounce(func, delay) {
    let timeout
    return function(...args) {
      const context = this
      clearTimeout(timeout)
      timeout = setTimeout(() => func.apply(context, args), delay)
    }
  }
}

