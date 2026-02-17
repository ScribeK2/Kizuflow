import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["container"]
  static values = {
    workflowId: Number
  }

  connect() {
    this.initializeSortable()
    // Listen for step addition from modal (kept for backward compatibility)
    this.boundHandleModalAddStep = this.handleModalAddStep.bind(this)
    document.addEventListener("step-modal:add-step", this.boundHandleModalAddStep)
    // Listen for inline step creation (Sprint 3)
    this.boundHandleInlineStepCreate = this.handleInlineStepCreate.bind(this)
    document.addEventListener("inline-step:create", this.boundHandleInlineStepCreate)
    // Set up event listeners for title changes (debounced)
    this.setupTitleChangeListeners()
    
    // Skip initial dropdown refresh - step_selector controllers handle their own initialization
    // This prevents O(n²) DOM queries on page load for large workflows
    // Dropdowns will be populated lazily when opened
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
    if (this.boundHandleModalAddStep) {
      document.removeEventListener("step-modal:add-step", this.boundHandleModalAddStep)
    }
    if (this.boundHandleInlineStepCreate) {
      document.removeEventListener("inline-step:create", this.boundHandleInlineStepCreate)
    }
    // Clean up container listeners
    if (this.hasContainerTarget) {
      if (this.boundContainerInputHandler) {
        this.containerTarget.removeEventListener("input", this.boundContainerInputHandler)
      }
      if (this.boundContainerChangeHandler) {
        this.containerTarget.removeEventListener("change", this.boundContainerChangeHandler)
      }
    }
    // Clear debounce timers
    if (this.titleChangeDebounceTimer) {
      clearTimeout(this.titleChangeDebounceTimer)
    }
    if (this.variableChangeDebounceTimer) {
      clearTimeout(this.variableChangeDebounceTimer)
    }
  }
  
  /**
   * Handle inline step creation (Sprint 3)
   */
  async handleInlineStepCreate(event) {
    const { type, afterIndex } = event.detail
    console.log(`[WorkflowBuilder] Creating inline step of type ${type} after index ${afterIndex}`)
    
    // Create the step with default data
    const stepData = {
      title: "",
      description: ""
    }
    
    // Add type-specific defaults
    if (type === "question") {
      stepData.question = ""
      stepData.answer_type = "yes_no"
      stepData.variable_name = ""
    } else if (type === "decision") {
      stepData.branches = []
    } else if (type === "action") {
      stepData.action_type = "Instruction"
      stepData.instructions = ""
    } else if (type === "sub_flow") {
      stepData.target_workflow_id = ""
      stepData.variable_mapping = {}
    } else if (type === "message") {
      stepData.content = ""
    } else if (type === "escalate") {
      stepData.target_type = ""
      stepData.target_value = ""
      stepData.priority = "normal"
      stepData.reason_required = false
      stepData.notes = ""
    } else if (type === "resolve") {
      stepData.resolution_type = "success"
      stepData.resolution_code = ""
      stepData.notes_required = false
      stepData.survey_trigger = false
    }

    // Insert the step at the specified position
    await this.addStepFromModal(type, stepData, afterIndex + 1)
  }

  async handleModalAddStep(event) {
    const { stepType, stepData } = event.detail
    console.log(`[WorkflowBuilder] Adding step from modal: ${stepType}`, stepData)
    await this.addStepFromModal(stepType, stepData)
  }

  /**
   * Add a step directly without opening the modal (Sprint 3.5)
   * This provides a more streamlined UX where clicking "Add Question" 
   * immediately adds a step that's ready for editing.
   */
  async addStepDirect(event) {
    event.preventDefault()
    
    const stepType = event.currentTarget.dataset.stepType
    if (!stepType) {
      console.error("[WorkflowBuilder] No step type specified")
      return
    }
    
    console.log(`[WorkflowBuilder] Adding step directly: ${stepType}`)
    
    // Create default step data based on type
    const stepData = {
      title: "",
      description: ""
    }
    
    // Add type-specific defaults
    switch (stepType) {
      case "question":
        stepData.question = ""
        stepData.answer_type = "yes_no"
        stepData.variable_name = ""
        break
      case "decision":
        stepData.branches = []
        break
      case "action":
        stepData.action_type = "Instruction"
        stepData.instructions = ""
        break
      case "checkpoint":
        stepData.checkpoint_message = ""
        break
      case "sub_flow":
        stepData.target_workflow_id = ""
        stepData.variable_mapping = {}
        break
      case "message":
        stepData.content = ""
        break
      case "escalate":
        stepData.target_type = ""
        stepData.target_value = ""
        stepData.priority = "normal"
        stepData.reason_required = false
        stepData.notes = ""
        break
      case "resolve":
        stepData.resolution_type = "success"
        stepData.resolution_code = ""
        stepData.notes_required = false
        stepData.survey_trigger = false
        break
    }
    
    // Add the step at the end
    await this.addStepFromModal(stepType, stepData)
  }

  initializeSortable() {
    if (!this.hasContainerTarget) {
      return
    }
    
    try {
      this.sortable = Sortable.create(this.containerTarget, {
        animation: 150,
        handle: ".drag-handle",
        onEnd: (event) => {
          this.updateOrder(event)
          this.refreshAllDropdowns()
          
          // Dispatch event for collaboration
          const newOrder = Array.from(this.containerTarget.querySelectorAll(".step-item")).map((step, index) => {
            const indexInput = step.querySelector("input[name*='[index]']")
            return indexInput ? parseInt(indexInput.value) : index
          })
          document.dispatchEvent(new CustomEvent("workflow-builder:steps-reordered", {
            detail: { newOrder }
          }))
        }
      })
    } catch (error) {
      console.error("Failed to load Sortable:", error)
    }
  }

  setupTitleChangeListeners() {
    if (!this.hasContainerTarget) return

    // Debounce timers for expensive operations
    this.titleChangeDebounceTimer = null
    this.variableChangeDebounceTimer = null

    // Use event delegation to handle title changes with debouncing
    // Store bound handler for cleanup
    this.boundContainerInputHandler = (event) => {
      if (event.target.matches("input[name*='[title]']")) {
        // Debounce dropdown refresh - 500ms delay to batch rapid typing
        if (this.titleChangeDebounceTimer) {
          clearTimeout(this.titleChangeDebounceTimer)
        }
        this.titleChangeDebounceTimer = setTimeout(() => {
          // Note: step_selector controllers now handle their own refresh
          // We only need to notify the preview
          this.notifyPreviewUpdate()
        }, 500)
      }
      // Also refresh variable dropdowns when variable names change (debounced)
      if (event.target.matches("input[name*='[variable_name]']")) {
        if (this.variableChangeDebounceTimer) {
          clearTimeout(this.variableChangeDebounceTimer)
        }
        this.variableChangeDebounceTimer = setTimeout(() => {
          this.refreshAllRuleBuilders()
        }, 500)
      }
    }
    this.containerTarget.addEventListener("input", this.boundContainerInputHandler)

    // Also listen for select changes (dropdown updates)
    // Store bound handler for cleanup
    this.boundContainerChangeHandler = (event) => {
      if (event.target.matches("select[name*='[true_path]'], select[name*='[false_path]']")) {
        this.notifyPreviewUpdate()
      }
    }
    this.containerTarget.addEventListener("change", this.boundContainerChangeHandler)
  }

  refreshAllRuleBuilders() {
    // Notify all rule builder controllers to refresh their variable dropdowns
    const form = this.element.closest("form")
    if (!form) return
    
    const ruleBuilders = form.querySelectorAll("[data-controller*='rule-builder']")
    ruleBuilders.forEach(element => {
      const application = window.Stimulus
      if (application) {
        const controller = application.getControllerForElementAndIdentifier(element, "rule-builder")
        if (controller && typeof controller.refreshVariables === 'function') {
          controller.refreshVariables()
        }
      }
    })
  }

  notifyPreviewUpdate() {
    // Dispatch custom event for flow preview to listen to
    document.dispatchEvent(new CustomEvent("workflow:updated"))
  }

  /**
   * Handle graph mode toggle
   */
  toggleGraphMode(event) {
    const enabled = event.target.checked
    console.log(`[WorkflowBuilder] Graph mode ${enabled ? 'enabled' : 'disabled'}`)

    // Notify the preview to update
    this.notifyPreviewUpdate()

    // Show/hide sub-flow button based on graph mode
    const subflowButton = document.querySelector('[data-step-type="sub_flow"]')
    if (subflowButton) {
      subflowButton.style.display = enabled ? '' : 'none'
    }

    // Dispatch event for other components
    document.dispatchEvent(new CustomEvent("workflow:graph-mode-changed", {
      detail: { enabled }
    }))
  }

  // Get all step titles from the current form
  getAllStepTitles(excludeIndex = null) {
    const titles = []
    const stepItems = this.containerTarget.querySelectorAll(".step-item")
    
    stepItems.forEach((stepItem, index) => {
      if (excludeIndex !== null && index === excludeIndex) return
      
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      if (titleInput && titleInput.value.trim()) {
        titles.push({
          value: titleInput.value.trim(),
          index: index
        })
      }
    })
    
    return titles
  }

  // Generate dropdown options HTML
  buildDropdownOptions(stepTitles, currentValue = "") {
    let options = '<option value="">-- Select step --</option>'
    let currentValueFound = false
    
    stepTitles.forEach(title => {
      const selected = title.value === currentValue ? "selected" : ""
      if (selected) currentValueFound = true
      options += `<option value="${this.escapeHtml(title.value)}" ${selected}>${this.escapeHtml(title.value)}</option>`
    })
    
    // If currentValue exists but isn't in the list, preserve it (broken reference)
    if (currentValue && !currentValueFound) {
      options += `<option value="${this.escapeHtml(currentValue)}" selected>${this.escapeHtml(currentValue)}</option>`
    }
    
    return options
  }

  // Escape HTML to prevent XSS
  getActionFieldsHtml(stepData = {}) {
    const attachments = stepData.attachments || []
    const attachmentsJson = JSON.stringify(attachments)
    
    // Generate HTML for existing attachments
    let attachmentsHtml = ""
    if (attachments.length > 0) {
      attachmentsHtml = attachments.map(signedId => {
        return `
          <div class="flex items-center justify-between p-2 bg-gray-50 rounded border" data-attachment-id="${this.escapeHtml(signedId)}">
            <div class="flex items-center gap-2">
              <span class="text-sm text-gray-700">File</span>
            </div>
            <button type="button" 
                    class="text-red-500 hover:text-red-700 text-sm"
                    data-action="click->file-attachment#removeAttachment"
                    data-attachment-id="${this.escapeHtml(signedId)}">
              Remove
            </button>
          </div>
        `
      }).join('')
    }
    
    return `
      <div class="field-container">
        <label class="block text-sm font-medium text-gray-700 mb-1">Instructions</label>
        <textarea name="workflow[steps][][instructions]" 
                  placeholder="Detailed instructions for this action..." 
                  class="w-full border rounded px-3 py-2" 
                  rows="3"
                  data-step-form-target="field">${this.escapeHtml(stepData.instructions || "")}</textarea>
      </div>
      
      <div class="field-container" 
           data-controller="file-attachment"
           data-file-attachment-step-index-value="">
        <label class="block text-sm font-medium text-gray-700 mb-1">Attachments</label>
        
        <input type="hidden" 
               name="workflow[steps][][attachments]" 
               value="${this.escapeHtml(attachmentsJson)}"
               data-file-attachment-target="attachmentsInput"
               data-step-form-target="field">
        
        <div class="mt-2">
          <input type="file" 
                 class="block w-full text-sm text-gray-500
                        file:mr-4 file:py-2 file:px-4
                        file:rounded-full file:border-0
                        file:text-sm file:font-semibold
                        file:bg-blue-50 file:text-blue-700
                        hover:file:bg-blue-100
                        cursor-pointer"
                 data-file-attachment-target="fileInput"
                 data-action="change->file-attachment#handleFileSelect"
                 multiple
                 accept="image/*,.pdf,.doc,.docx,.txt,.csv">
          <p class="mt-1 text-xs text-gray-500">Upload files (images, PDFs, documents). Multiple files allowed.</p>
        </div>
        
        <div data-file-attachment-target="attachmentsList" class="mt-3 space-y-2">
          ${attachmentsHtml}
        </div>
      </div>
    `
  }

  refreshAllTransitions() {
    const transitionControllers = this.application.controllers.filter(c => c.identifier === "step-transitions")
    transitionControllers.forEach(controller => {
      if (typeof controller.refresh === 'function') {
        controller.refresh()
      }
    })
  }

  // Refresh all dropdowns in all decision steps
  refreshAllDropdowns() {
    if (!this.hasContainerTarget) return
    
    const stepItems = this.containerTarget.querySelectorAll(".step-item")
    
    stepItems.forEach((stepItem, index) => {
      const stepTypeInput = stepItem.querySelector("input[name*='[type]']")
      if (stepTypeInput && stepTypeInput.value === "decision") {
        const stepTitles = this.getAllStepTitles(index)
        
        // Update true_path dropdown
        const truePathSelect = stepItem.querySelector("select[name*='[true_path]']")
        if (truePathSelect) {
          const currentValue = truePathSelect.value
          truePathSelect.innerHTML = this.buildDropdownOptions(stepTitles, currentValue)
          // Initialize searchable dropdown if controller exists
          this.initializeSearchableDropdown(truePathSelect)
        }
        
        // Update false_path dropdown
        const falsePathSelect = stepItem.querySelector("select[name*='[false_path]']")
        if (falsePathSelect) {
          const currentValue = falsePathSelect.value
          falsePathSelect.innerHTML = this.buildDropdownOptions(stepTitles, currentValue)
          // Initialize searchable dropdown if controller exists
          this.initializeSearchableDropdown(falsePathSelect)
        }
      }
    })
  }

  // Initialize searchable dropdown functionality on a select element
  initializeSearchableDropdown(selectElement) {
    // Find the searchable dropdown controller instance
    const wrapper = selectElement.closest('[data-controller*="searchable-dropdown"]')
    if (!wrapper) return
    
    // Get the Stimulus controller instance
    const application = window.Stimulus
    if (!application) return
    
    const controller = application.getControllerForElementAndIdentifier(wrapper, "searchable-dropdown")
    if (controller && typeof controller.refreshDropdown === 'function') {
      controller.refreshDropdown()
    }
  }

  updateOrder(event) {
    const form = this.element.closest("form")
    if (form) {
      const inputs = this.containerTarget.querySelectorAll("[data-step-index]")
      inputs.forEach((input, index) => {
        input.value = index
      })
    }
    this.refreshAllDropdowns()
    this.notifyPreviewUpdate()
  }

  addStep(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (!this.hasContainerTarget) {
      return
    }
    
    const stepType = event.params.type
    const stepIndex = this.containerTarget.children.length
    const stepHtml = this.buildStepHtml(stepType, stepIndex)
    
    this.containerTarget.insertAdjacentHTML("beforeend", stepHtml)
    
    // Refresh dropdowns after adding new step
    this.refreshAllDropdowns()
    this.refreshAllRuleBuilders()
    this.notifyPreviewUpdate()
    
    // Dispatch event for collaboration
    const stepElement = this.containerTarget.querySelector(`[data-step-index="${stepIndex}"]`)
    const stepData = this.extractStepData(stepElement)
    document.dispatchEvent(new CustomEvent("workflow-builder:step-added", {
      detail: { stepIndex, stepType, stepData }
    }))
    
    // Reinitialize Sortable after adding new element
    if (this.sortable) {
      this.sortable.destroy()
    }
    this.initializeSortable()
  }

  async addStepFromModal(stepType, stepData, insertAtIndex = null) {
    if (!this.hasContainerTarget) {
      console.warn("[WorkflowBuilder] No container target found")
      return
    }

    // Remove empty state if present
    this.removeEmptyState()

    const existingSteps = this.containerTarget.querySelectorAll(".step-item")
    const totalSteps = existingSteps.length
    
    // Determine where to insert
    const insertIndex = insertAtIndex !== null ? Math.min(insertAtIndex, totalSteps) : totalSteps
    
    // Get workflow ID for server-side rendering
    const workflowId = this.getWorkflowIdFromPage()
    console.log(`[WorkflowBuilder] Adding step: type=${stepType}, index=${insertIndex}`)
    console.log(`[WorkflowBuilder] Workflow ID from page: ${workflowId}`)
    console.log(`[WorkflowBuilder] Has workflowIdValue: ${this.hasWorkflowIdValue}, value: ${this.workflowIdValue}`)
    
    let stepHtml
    let usedServerRendering = false

    // Try server-side rendering if we have a workflow ID
    if (workflowId) {
      try {
        console.log("[WorkflowBuilder] Attempting server-side rendering...")
        stepHtml = await this.fetchStepHtml(workflowId, stepType, insertIndex, stepData)
        console.log("[WorkflowBuilder] Server-side rendering successful, HTML length:", stepHtml.length)
        usedServerRendering = true
      } catch (error) {
        console.warn("[WorkflowBuilder] Server-side rendering failed:", error.message)
        console.warn("[WorkflowBuilder] Falling back to client-side rendering")
        stepHtml = this.buildStepHtml(stepType, insertIndex, stepData)
      }
    } else {
      // Fallback to client-side rendering for new workflows
      console.log("[WorkflowBuilder] No workflow ID found, using client-side rendering")
      console.log("[WorkflowBuilder] URL:", window.location.pathname)
      console.log("[WorkflowBuilder] Element:", this.element?.id || 'no-id')
      stepHtml = this.buildStepHtml(stepType, insertIndex, stepData)
    }

    console.log(`[WorkflowBuilder] Inserting step (server=${usedServerRendering}), HTML preview:`, stepHtml.substring(0, 200))
    
    // Insert at the specified position
    if (insertAtIndex !== null && insertAtIndex < totalSteps) {
      // Insert before the step at insertAtIndex
      const referenceStep = existingSteps[insertAtIndex]
      referenceStep.insertAdjacentHTML("beforebegin", stepHtml)
    } else {
      // Insert at the end
      this.containerTarget.insertAdjacentHTML("beforeend", stepHtml)
    }

    // Wait for Stimulus to connect controllers in the new HTML
    // Use a small delay to ensure MutationObserver has processed the changes
    await new Promise(resolve => setTimeout(resolve, 50))

    // Update indices for all steps
    this.updateAllStepIndices()

    // Refresh dropdowns after adding new step
    this.refreshAllDropdowns()
    this.refreshAllRuleBuilders()
    this.refreshAllTransitions()
    this.notifyPreviewUpdate()
    
    // Dispatch events
    const stepElement = this.containerTarget.querySelector(`[data-step-index="${insertIndex}"]`)
    const extractedStepData = this.extractStepData(stepElement)
    document.dispatchEvent(new CustomEvent("workflow-builder:step-added", {
      detail: { stepIndex: insertIndex, stepType, stepData: extractedStepData }
    }))
    
    // Also dispatch for step outline to refresh
    document.dispatchEvent(new CustomEvent("workflow:updated"))
    
    // Reinitialize Sortable after adding new element
    if (this.sortable) {
      this.sortable.destroy()
    }
    this.initializeSortable()
    
    // Scroll the new step into view and expand it
    if (stepElement) {
      stepElement.scrollIntoView({ behavior: "smooth", block: "center" })
      
      // Highlight the new step briefly
      stepElement.classList.add("ring-2", "ring-blue-500", "ring-offset-2")
      setTimeout(() => {
        stepElement.classList.remove("ring-2", "ring-blue-500", "ring-offset-2")
      }, 1500)
    }
  }
  
  /**
   * Fetch step HTML from the server (Sprint 3)
   * This enables server-side rendering with all the new features
   */
  async fetchStepHtml(workflowId, stepType, stepIndex, stepData = {}) {
    const url = `/workflows/${workflowId}/render_step`
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    console.log(`[WorkflowBuilder] Fetching step HTML from ${url}`)
    console.log(`[WorkflowBuilder] CSRF Token present: ${!!csrfToken}`)

    const requestBody = {
      step_type: stepType,
      step_index: stepIndex,
      step_data: stepData
    }
    console.log("[WorkflowBuilder] Request body:", requestBody)

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken || '',
          'Accept': 'text/html'
        },
        credentials: 'same-origin', // Ensure cookies are sent
        body: JSON.stringify(requestBody)
      })

      console.log(`[WorkflowBuilder] Server response status: ${response.status}`)

      if (!response.ok) {
        const errorText = await response.text()
        console.error(`[WorkflowBuilder] Server error response:`, errorText.substring(0, 500))
        throw new Error(`Server returned ${response.status}`)
      }

      const html = await response.text()
      console.log(`[WorkflowBuilder] Received HTML (${html.length} chars)`)

      // Validate that we got actual step HTML, not an error page
      if (!html.includes('step-item') && !html.includes('data-step-index')) {
        console.warn('[WorkflowBuilder] Response does not appear to be valid step HTML')
        throw new Error('Invalid step HTML response')
      }

      return html
    } catch (fetchError) {
      console.error('[WorkflowBuilder] Fetch error:', fetchError.message)
      throw fetchError
    }
  }
  
  /**
   * Get workflow ID from the current page
   */
  getWorkflowIdFromPage() {
    // First, try getting from Stimulus value (most reliable)
    if (this.hasWorkflowIdValue && this.workflowIdValue) {
      return this.workflowIdValue.toString()
    }
    
    // Try getting from URL
    const urlMatch = window.location.pathname.match(/\/workflows\/(\d+)/)
    if (urlMatch) {
      return urlMatch[1]
    }
    
    // Try getting from form action
    const form = this.element.closest("form")
    if (form) {
      const actionMatch = form.action?.match(/\/workflows\/(\d+)/)
      if (actionMatch) {
        return actionMatch[1]
      }
    }
    
    return null
  }
  
  /**
   * Update all step indices after insertion or removal
   */
  updateAllStepIndices() {
    const stepItems = this.containerTarget.querySelectorAll(".step-item")
    stepItems.forEach((stepItem, index) => {
      // Update data attribute
      stepItem.dataset.stepIndex = index
      
      // Update hidden index input
      const indexInput = stepItem.querySelector("input[name*='[index]']")
      if (indexInput) {
        indexInput.value = index
      }
      
      // Update step number display in collapsible header
      const stepNumber = stepItem.querySelector(".step-number, .rounded-full.bg-white\\/20")
      if (stepNumber) {
        stepNumber.textContent = index + 1
      }
    })
  }

  removeStep(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const stepElement = event.target.closest("[data-step-index]")
    if (stepElement) {
      const stepIndex = parseInt(stepElement.getAttribute("data-step-index") || stepElement.querySelector("input[name*='[index]']")?.value || "0")
      
      // Dispatch event for collaboration before removing
      document.dispatchEvent(new CustomEvent("workflow-builder:step-removed", {
        detail: { stepIndex }
      }))
      
      stepElement.remove()
      this.updateOrderIndices()
      this.refreshAllDropdowns()
      this.refreshAllRuleBuilders()
      this.refreshAllTransitions()
      this.notifyPreviewUpdate()
      
      // Reinitialize Sortable after removing element
      if (this.sortable) {
        this.sortable.destroy()
      }
      this.initializeSortable()
    }
  }

  updateOrderIndices() {
    const inputs = this.containerTarget.querySelectorAll("[data-step-index]")
    inputs.forEach((input, index) => {
      input.value = index
    })
  }

  buildStepHtml(stepType, index, stepData = {}) {
    const stepTitles = this.getAllStepTitles(index)
    const truePathOptions = this.buildDropdownOptions(stepTitles, stepData.true_path || "")
    const falsePathOptions = this.buildDropdownOptions(stepTitles, stepData.false_path || "")
    
    // Get workflow ID from form action or data attribute
    const form = this.element.closest("form")
    const workflowId = form?.dataset?.workflowId || this.getWorkflowIdFromForm(form)
    const previewUrl = workflowId ? `/workflows/${workflowId}/preview` : ""
    
    return `
      <div class="step-item border rounded p-4 mb-4" 
           data-step-index="${index}"
           data-controller="step-form"
           data-step-form-step-type-value="${stepType}"
           data-step-form-step-index-value="${index}">
        <div class="flex items-center justify-between mb-2">
          <span class="drag-handle cursor-move text-gray-500">☰</span>
          <button type="button" data-action="click->workflow-builder#removeStep" class="text-red-500 hover:text-red-700">Remove</button>
        </div>
        <input type="hidden" name="workflow[steps][][index]" value="${index}">
        <input type="hidden" name="workflow[steps][][type]" value="${stepType}">
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4" 
             ${previewUrl ? `data-controller="preview-updater" data-preview-updater-url-value="${previewUrl}" data-preview-updater-index-value="${index}"` : ""}>
          <div class="space-y-2 min-w-0">
            <div class="field-container">
              <input type="text" 
                     name="workflow[steps][][title]" 
                     value="${this.escapeHtml(stepData.title || "")}"
                     placeholder="Step title" 
                     class="w-full border rounded px-3 py-2" 
                     required
                     data-step-form-target="field">
            </div>
            <div class="field-container">
              <textarea name="workflow[steps][][description]" 
                        placeholder="Step description" 
                        class="w-full border rounded px-3 py-2" 
                        rows="2"
                        data-step-form-target="field">${this.escapeHtml(stepData.description || "")}</textarea>
            </div>
            ${this.getStepTypeSpecificFields(stepType, stepData, truePathOptions, falsePathOptions)}
          </div>
          
          ${previewUrl ? `
            <div class="min-w-0">
              <turbo-frame id="step_preview_${index}" data-preview-updater-target="previewFrame">
                ${this.getPreviewHtml(stepType, stepData)}
              </turbo-frame>
            </div>
          ` : `
            <div class="preview-pane bg-gray-50 border rounded-lg p-4">
              <h4 class="text-sm font-semibold text-gray-700 mb-2">Live Preview</h4>
              <p class="text-sm text-gray-500 text-center py-4">Save workflow to enable live preview</p>
            </div>
          `}
        </div>
      </div>
    `
  }
  
  getWorkflowIdFromForm(form) {
    if (!form) return null
    const action = form.action || ""
    const match = action.match(/\/workflows\/(\d+)/)
    return match ? match[1] : null
  }
  
  getPreviewHtml(stepType, stepData) {
    // Basic HTML preview for client-side rendering
    return `
      <div class="preview-pane bg-gray-50 border rounded-lg p-4">
        <h4 class="text-sm font-semibold text-gray-700 mb-2">Live Preview</h4>
        <p class="text-sm text-gray-500">Start filling in the form to see preview</p>
      </div>
    `
  }

  getStepTypeSpecificFields(stepType, stepData = {}, truePathOptions = "", falsePathOptions = "") {
    const templateSelector = this.getTemplateSelectorHtml(stepType)
    switch(stepType) {
      case "question":
        return this.getQuestionFieldsHtml(stepData)
      case "decision":
        return templateSelector + this.getDecisionFieldsHtml(stepData, truePathOptions, falsePathOptions)
      case "action":
        return this.getActionFieldsHtml(stepData)
      case "sub_flow":
        return this.getSubflowFieldsHtml(stepData)
      case "checkpoint":
        return this.getCheckpointFieldsHtml(stepData)
      case "message":
        return this.getMessageFieldsHtml(stepData)
      case "escalate":
        return this.getEscalateFieldsHtml(stepData)
      case "resolve":
        return this.getResolveFieldsHtml(stepData)
      default:
        return ""
    }
  }

  getCheckpointFieldsHtml(stepData = {}) {
    return `
      <div class="field-container">
        <label class="block text-sm font-medium text-gray-700 mb-1">Checkpoint Message</label>
        <textarea name="workflow[steps][][checkpoint_message]"
                  placeholder="Message to display at checkpoint..."
                  class="w-full border rounded px-3 py-2"
                  rows="2"
                  data-step-form-target="field">${this.escapeHtml(stepData.checkpoint_message || "")}</textarea>
        <p class="mt-1 text-xs text-gray-500">This message will be shown when the simulation reaches this checkpoint.</p>
      </div>
    `
  }

  getMessageFieldsHtml(stepData = {}) {
    return `
      <div class="field-container">
        <div class="bg-cyan-50 border border-cyan-200 rounded-lg p-3 mb-4">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-cyan-600 mr-2 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-sm text-cyan-800">
              <strong>Message Step:</strong> Display information to the CSR. Auto-advances without user input.
            </p>
          </div>
        </div>

        <label class="block text-sm font-medium text-gray-700 mb-1">Message Content</label>
        <textarea name="workflow[steps][][content]"
                  placeholder="Enter the message to display..."
                  class="w-full border rounded px-3 py-2"
                  rows="4"
                  data-step-form-target="field">${this.escapeHtml(stepData.content || "")}</textarea>
        <p class="mt-1 text-xs text-gray-500">Supports variable interpolation with {{variable_name}} syntax.</p>
      </div>
    `
  }

  getEscalateFieldsHtml(stepData = {}) {
    const targetTypes = ['department', 'supervisor', 'channel', 'ticket']
    const priorities = ['low', 'medium', 'high', 'critical']

    return `
      <div class="field-container">
        <div class="bg-orange-50 border border-orange-200 rounded-lg p-3 mb-4">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-orange-600 mr-2 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11l5-5m0 0l5 5m-5-5v12" />
            </svg>
            <p class="text-sm text-orange-800">
              <strong>Escalate Step:</strong> Transfer to another team, queue, or supervisor.
            </p>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Target Type</label>
          <select name="workflow[steps][][target_type]"
                  class="w-full border rounded px-3 py-2"
                  data-step-form-target="field">
            <option value="">-- Select target type --</option>
            ${targetTypes.map(t => `<option value="${t}" ${stepData.target_type === t ? 'selected' : ''}>${t.charAt(0).toUpperCase() + t.slice(1)}</option>`).join('')}
          </select>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Target Name/ID</label>
          <input type="text"
                 name="workflow[steps][][target_value]"
                 value="${this.escapeHtml(stepData.target_value || "")}"
                 placeholder="e.g., Billing Team, Supervisor Queue"
                 class="w-full border rounded px-3 py-2"
                 data-step-form-target="field">
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Priority</label>
          <select name="workflow[steps][][priority]"
                  class="w-full border rounded px-3 py-2"
                  data-step-form-target="field">
            ${priorities.map(p => `<option value="${p}" ${(stepData.priority || 'medium') === p ? 'selected' : ''}>${p.charAt(0).toUpperCase() + p.slice(1)}</option>`).join('')}
          </select>
        </div>

        <div class="mb-4">
          <label class="flex items-center cursor-pointer">
            <input type="hidden" name="workflow[steps][][reason_required]" value="false">
            <input type="checkbox"
                   name="workflow[steps][][reason_required]"
                   value="true"
                   ${stepData.reason_required ? 'checked' : ''}
                   class="h-4 w-4 text-orange-600 border-gray-300 rounded"
                   data-step-form-target="field">
            <span class="ml-2 text-sm text-gray-700">Require reason for escalation</span>
          </label>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Notes (optional)</label>
          <textarea name="workflow[steps][][notes]"
                    placeholder="Additional context for the escalation..."
                    class="w-full border rounded px-3 py-2"
                    rows="2"
                    data-step-form-target="field">${this.escapeHtml(stepData.notes || "")}</textarea>
        </div>
      </div>
    `
  }

  getResolveFieldsHtml(stepData = {}) {
    const resolutionTypes = [
      { value: 'success', label: 'Success' },
      { value: 'transfer', label: 'Transfer' },
      { value: 'ticket', label: 'Ticket' },
      { value: 'manager_escalation', label: 'Manager Escalation' }
    ]

    return `
      <div class="field-container">
        <div class="bg-green-50 border border-green-200 rounded-lg p-3 mb-4">
          <div class="flex items-start">
            <svg class="w-5 h-5 text-green-600 mr-2 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <p class="text-sm text-green-800">
              <strong>Resolve Step:</strong> Terminal step that completes the workflow. Cannot have outgoing connections.
            </p>
          </div>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Resolution Type</label>
          <select name="workflow[steps][][resolution_type]"
                  class="w-full border rounded px-3 py-2"
                  data-step-form-target="field">
            ${resolutionTypes.map(t => `<option value="${t.value}" ${(stepData.resolution_type || 'success') === t.value ? 'selected' : ''}>${t.label}</option>`).join('')}
          </select>
        </div>
      </div>
    `
  }

  getSubflowFieldsHtml(stepData = {}) {
    const workflowId = this.getWorkflowIdFromPage()

    return `
      <div class="field-container" data-controller="subflow-selector" data-subflow-selector-current-workflow-id-value="${workflowId || ''}">
        <label class="block text-sm font-medium text-gray-700 mb-1">Target Workflow</label>
        <input type="hidden"
               name="workflow[steps][][target_workflow_id]"
               value="${this.escapeHtml(stepData.target_workflow_id || "")}"
               data-subflow-selector-target="hiddenInput"
               data-step-form-target="field">
        <select data-subflow-selector-target="select"
                data-action="change->subflow-selector#selectWorkflow"
                class="w-full border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
          <option value="">-- Select a workflow --</option>
        </select>
        <p class="mt-1 text-xs text-gray-500">Select a published workflow to run as a sub-routine. Variables will be inherited.</p>
      </div>

      <div class="field-container mt-3">
        <label class="block text-sm font-medium text-gray-700 mb-1">Variable Mapping (Optional)</label>
        <div class="bg-gray-50 rounded p-3 border border-gray-200">
          <p class="text-xs text-gray-500 mb-2">
            Map parent workflow variables to child workflow variables. Child workflow results will be merged back.
          </p>
          <input type="hidden"
                 name="workflow[steps][][variable_mapping]"
                 value="${this.escapeHtml(JSON.stringify(stepData.variable_mapping || {}))}"
                 data-step-form-target="field">
          <div class="text-xs text-gray-400 italic">
            Variable mapping editor coming soon. Currently, all parent variables are automatically passed to sub-flows.
          </div>
        </div>
      </div>
    `
  }

  getTemplateSelectorHtml(stepType) {
    // Get templates from page data
    const templatesData = this.getTemplatesFromPage()
    const templates = templatesData[stepType] || []
    
    if (templates.length === 0) return ""
    
    const optionsHtml = templates.map(t => 
      `<option value="${this.escapeHtml(t.key)}">${this.escapeHtml(t.name)}</option>`
    ).join('')
    
    // Escape JSON for HTML attribute (escape quotes and HTML entities)
    const templatesJson = JSON.stringify(templates)
    const escapedTemplatesJson = templatesJson
      .replace(/&/g, '&amp;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;')
    
    return `
      <div class="field-container mb-3" 
           data-controller="step-template"
           data-step-template-step-type-value="${stepType}"
           data-step-template-templates-data="${escapedTemplatesJson}">
        <label class="block text-sm font-medium text-gray-700 mb-1">Apply Template</label>
        <select data-step-template-target="select"
                data-action="change->step-template#applyTemplate"
                class="w-full border rounded px-3 py-2 text-sm">
          <option value="">-- Select a template --</option>
          ${optionsHtml}
        </select>
        <p class="mt-1 text-xs text-gray-500">Quickly fill form fields with a predefined template</p>
      </div>
    `
  }

  getTemplatesFromPage() {
    const scriptTag = document.getElementById('step-templates-data')
    if (!scriptTag) return { question: [], decision: [], action: [] }
    
    try {
      return JSON.parse(scriptTag.textContent)
    } catch (e) {
      console.error("Failed to parse step templates:", e)
      return { question: [], decision: [], action: [] }
    }
  }

  getQuestionFieldsHtml(stepData = {}) {
    const answerTypes = [
      { value: 'text', label: 'Text' },
      { value: 'yes_no', label: 'Yes/No' },
      { value: 'multiple_choice', label: 'Multiple Choice' },
      { value: 'dropdown', label: 'Dropdown' },
      { value: 'date', label: 'Date' },
      { value: 'number', label: 'Number' },
      { value: 'file', label: 'File Upload' }
    ]
    
    const currentAnswerType = stepData.answer_type || ""
    const showOptions = currentAnswerType === 'multiple_choice' || currentAnswerType === 'dropdown'
    
    let answerTypeRadios = answerTypes.map(type => {
      const checked = currentAnswerType === type.value ? 'checked' : ''
      const selectedClass = checked ? 'bg-blue-50 border-blue-500' : ''
      return `
        <label class="flex items-center gap-2 p-2 border rounded cursor-pointer hover:bg-gray-50 ${selectedClass}">
          <input type="radio" 
                 name="workflow[steps][][answer_type]" 
                 value="${type.value}"
                 ${checked}
                 data-question-form-target="answerType"
                 data-action="change->question-form#handleAnswerTypeChange"
                 data-step-form-target="field"
                 class="cursor-pointer">
          <span class="text-sm">${type.label}</span>
        </label>
      `
    }).join('')
    
    let optionsHtml = ""
    if (stepData.options && Array.isArray(stepData.options) && stepData.options.length > 0) {
      optionsHtml = stepData.options.map(option => {
        const label = option.label || option.value || option || ""
        const value = option.value || option.label || option || ""
        return `
          <div class="flex gap-2 items-center option-item">
            <span class="drag-handle cursor-move text-gray-500 text-lg" title="Drag to reorder">☰</span>
            <input type="text" 
                   name="workflow[steps][][options][][label]" 
                   value="${this.escapeHtml(label)}"
                   placeholder="Option label" 
                   class="flex-1 border rounded px-2 py-1 text-sm"
                   data-step-form-target="field">
            <input type="text" 
                   name="workflow[steps][][options][][value]" 
                   value="${this.escapeHtml(value)}"
                   placeholder="Option value" 
                   class="flex-1 border rounded px-2 py-1 text-sm"
                   data-step-form-target="field">
            <button type="button" 
                    class="text-red-500 hover:text-red-700 text-sm px-2"
                    data-action="click->question-form#removeOption">
              Remove
            </button>
          </div>
        `
      }).join('')
    }
    
    return `
      <div class="field-container">
        <input type="text" 
               name="workflow[steps][][question]" 
               value="${this.escapeHtml(stepData.question || "")}" 
               placeholder="Question text" 
               class="w-full border rounded px-3 py-2"
               data-step-form-target="field"
               data-required="true">
      </div>
      
      <div class="field-container" data-controller="question-form">
        <label class="block text-sm font-medium text-gray-700 mb-2">Answer Type</label>
        <div class="grid grid-cols-2 gap-2" data-question-form-target="answerTypeContainer">
          ${answerTypeRadios}
        </div>
        <input type="hidden" name="workflow[steps][][answer_type]" value="${this.escapeHtml(currentAnswerType)}" data-question-form-target="hiddenAnswerType">
        
        <div class="mt-4 ${showOptions ? '' : 'hidden'}" 
             data-question-form-target="optionsContainer">
          <label class="block text-sm font-medium text-gray-700 mb-2">Options</label>
          <div data-question-form-target="optionsList" class="space-y-2">
            ${optionsHtml}
          </div>
          <button type="button" 
                  class="mt-2 text-sm text-blue-600 hover:text-blue-800"
                  data-action="click->question-form#addOption">
            + Add Option
          </button>
        </div>
      </div>
      
      <div class="field-container">
        <label class="block text-sm font-medium text-gray-700 mb-1">Variable Name</label>
        <input type="text" 
               name="workflow[steps][][variable_name]" 
               value="${this.escapeHtml(stepData.variable_name || "")}" 
               placeholder="e.g., user_name, age, etc." 
               class="w-full border rounded px-3 py-2"
               data-step-form-target="field">
        <p class="mt-1 text-xs text-gray-500">Optional: Name this answer for use in decision steps</p>
      </div>
    `
  }

  getDecisionFieldsHtml(stepData = {}, truePathOptions = "", falsePathOptions = "") {
    const workflowId = this.getWorkflowIdFromForm(this.element.closest("form"))
    const variablesUrl = workflowId ? `/workflows/${workflowId}/variables` : ""
    
    // Check if step has branches (new format) or legacy true_path/false_path
    const branches = stepData.branches || []
    const hasBranches = branches.length > 0
    
    // Generate branches HTML
    let branchesHtml = ""
    if (hasBranches) {
      branchesHtml = branches.map((branch, index) => {
        return this.getBranchHtml(index, branch.condition || "", branch.path || "", workflowId, variablesUrl)
      }).join('')
    }
    
    return `
      <div class="field-container" 
           data-controller="multi-branch" 
           ${workflowId ? `data-multi-branch-workflow-id-value="${workflowId}"` : ""}
           ${variablesUrl ? `data-multi-branch-variables-url-value="${variablesUrl}"` : ""}>
        
        <div class="flex items-center justify-between mb-3">
          <label class="block text-sm font-medium text-gray-700">Decision Branches</label>
          <button type="button" 
                  class="text-sm text-blue-600 hover:text-blue-800"
                  data-action="click->multi-branch#addBranch">
            + Add Branch
          </button>
        </div>
        
        <div data-multi-branch-target="branchesContainer" class="space-y-2">
          ${branchesHtml}
        </div>
        
        <div class="mt-4" data-multi-branch-target="elsePathContainer">
          <label class="block text-sm font-medium text-gray-700">Else (default), go to:</label>
          <div class="field-container mt-1 relative">
            <div data-controller="step-selector"
                 data-step-selector-selected-value-value="${stepData.else_path || ""}"
                 data-step-selector-placeholder-value="-- Select step --">
              <input type="hidden" 
                     name="workflow[steps][][else_path]" 
                     value="${stepData.else_path || ""}"
                     data-step-selector-target="hiddenInput"
                     data-step-form-target="field">
              <button type="button"
                      class="w-full text-left border rounded px-3 py-2 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      data-step-selector-target="button"
                      data-action="click->step-selector#toggle">
                ${stepData.else_path ? `<span class="font-medium">${this.escapeHtml(stepData.else_path)}</span>` : '<span class="text-gray-500">-- Select step --</span>'}
              </button>
              <div class="hidden absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-64 overflow-hidden"
                   data-step-selector-target="dropdown">
                <div class="p-2 border-b border-gray-200">
                  <input type="text"
                         placeholder="Search steps..."
                         class="w-full px-3 py-2 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                         data-step-selector-target="search"
                         data-action="input->step-selector#search">
                </div>
                <div class="overflow-y-auto max-h-56" data-step-selector-target="options">
                  <!-- Options will be rendered here -->
                </div>
              </div>
            </div>
          </div>
          <p class="mt-1 text-xs text-gray-500">Optional: Path to take when no branch conditions match</p>
        </div>
        
        <input type="hidden" name="workflow[steps][][true_path]" value="${stepData.true_path || ""}">
        <input type="hidden" name="workflow[steps][][false_path]" value="${stepData.false_path || ""}">
        
        <p class="mt-2 text-xs text-gray-500">Available variables come from question steps with variable names</p>
      </div>
    `
  }

  getBranchHtml(index, condition, path, workflowId, variablesUrl) {
    // Note: stepOptions no longer needed - using step selector component instead
    
    // Parse condition for initial values
    let variable = "", operator = "", value = ""
    if (condition) {
      const patterns = [
        /^(\w+)\s*(==|!=)\s*['"]([^'"]*)['"]$/,
        /^(\w+)\s*(>|>=|<|<=)\s*(\d+)$/
      ]
      
      for (const pattern of patterns) {
        const match = condition.match(pattern)
        if (match) {
          variable = match[1]
          operator = match[2]
          value = match[3] || ""
          break
        }
      }
    }
    
    const operatorOptions = [
      { value: "==", label: "Equals (==)", selected: operator === "==" },
      { value: "!=", label: "Not Equals (!=)", selected: operator === "!=" },
      { value: ">", label: "Greater Than (>)", selected: operator === ">" && operator !== ">=" },
      { value: ">=", label: "Greater or Equal (>=)", selected: operator === ">=" },
      { value: "<", label: "Less Than (<)", selected: operator === "<" && operator !== "<=" },
      { value: "<=", label: "Less or Equal (<=)", selected: operator === "<=" }
    ]
    
    return `
      <div class="branch-item border rounded p-3 mb-3 bg-gray-50" data-branch-index="${index}">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-gray-700">Branch ${index + 1}</span>
          <button type="button" 
                  class="text-red-500 hover:text-red-700 text-sm"
                  data-action="click->multi-branch#removeBranch"
                  data-branch-index="${index}">
            Remove
          </button>
        </div>
        
        <div class="grid grid-cols-1 gap-3">
          <div data-controller="rule-builder" 
               ${workflowId ? `data-rule-builder-workflow-id-value="${workflowId}"` : ""}
               ${variablesUrl ? `data-rule-builder-variables-url-value="${variablesUrl}"` : ""}>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-xs font-medium text-gray-700">Condition</label>
              <div class="flex gap-1" data-rule-builder-target="presetButtons">
                <button type="button"
                        class="px-2 py-1 text-xs bg-blue-50 text-blue-700 rounded hover:bg-blue-100 border border-blue-200"
                        data-preset="equals"
                        data-action="click->rule-builder#applyPreset"
                        title="Equals">
                  ==
                </button>
                <button type="button"
                        class="px-2 py-1 text-xs bg-blue-50 text-blue-700 rounded hover:bg-blue-100 border border-blue-200"
                        data-preset="not_equals"
                        data-action="click->rule-builder#applyPreset"
                        title="Not Equals">
                  !=
                </button>
                <button type="button"
                        class="px-2 py-1 text-xs bg-blue-50 text-blue-700 rounded hover:bg-blue-100 border border-blue-200"
                        data-preset="is_empty"
                        data-action="click->rule-builder#applyPreset"
                        title="Is Empty">
                  Empty
                </button>
              </div>
            </div>
            
            <input type="hidden" 
                   name="workflow[steps][][branches][][condition]" 
                   value="${this.escapeHtml(condition)}"
                   data-rule-builder-target="conditionInput"
                   data-step-form-target="field">
            
            <div class="grid grid-cols-3 gap-2 items-end">
              <div>
                <label class="block text-xs text-gray-600 mb-1">Variable</label>
                <select data-rule-builder-target="variableSelect" 
                        class="w-full border rounded px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        data-action="change->rule-builder#buildCondition">
                  <option value="">-- Select variable --</option>
                </select>
              </div>
              
              <div>
                <label class="block text-xs text-gray-600 mb-1">Operator</label>
                <select data-rule-builder-target="operatorSelect" 
                        class="w-full border rounded px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                        data-action="change->rule-builder#buildCondition">
                  <option value="">-- Select --</option>
                  ${operatorOptions.map(opt => 
                    `<option value="${opt.value}" ${opt.selected ? 'selected' : ''}>${opt.label}</option>`
                  ).join('')}
                </select>
              </div>
              
              <div>
                <label class="block text-xs text-gray-600 mb-1">Value</label>
                <div class="relative">
                  <input type="text" 
                         data-rule-builder-target="valueInput" 
                         value="${this.escapeHtml(value)}"
                         placeholder="Value"
                         class="w-full border rounded px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                         data-action="input->rule-builder#buildCondition"
                         list="value-suggestions-${index}">
                  <datalist id="value-suggestions-${index}" data-rule-builder-target="valueSuggestions">
                    <!-- Options will be populated dynamically -->
                  </datalist>
                </div>
              </div>
            </div>
            
            <div class="mt-2 p-2 bg-gray-50 rounded border border-gray-200">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="text-xs text-gray-500">Condition:</span>
                  <span data-rule-builder-target="conditionDisplay" class="text-xs font-mono text-gray-900">${condition || "Not set"}</span>
                </div>
              </div>
              <div data-rule-builder-target="validationMessage" class="hidden"></div>
              <div data-rule-builder-target="helpText" class="mt-1 text-xs text-gray-500">
                <span class="font-medium">Tip:</span> Select a variable first, then choose an operator and enter a value.
              </div>
            </div>
          </div>
          
          <div>
            <label class="block text-xs text-gray-600 mb-1">Go to:</label>
            <div data-controller="step-selector"
                 data-step-selector-selected-value-value="${path}"
                 data-step-selector-placeholder-value="-- Select step --"
                 class="relative">
              <input type="hidden" 
                     name="workflow[steps][][branches][][path]" 
                     value="${this.escapeHtml(path)}"
                     data-step-selector-target="hiddenInput"
                     data-step-form-target="field"
                     data-multi-branch-target="branchPathSelect">
              <button type="button"
                      class="w-full text-left border rounded px-3 py-2 text-sm bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      data-step-selector-target="button"
                      data-action="click->step-selector#toggle">
                ${path ? `<span class="font-medium">${this.escapeHtml(path)}</span>` : '<span class="text-gray-500">-- Select step --</span>'}
              </button>
              <div class="hidden absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-64 overflow-hidden"
                   data-step-selector-target="dropdown">
                <div class="p-2 border-b border-gray-200">
                  <input type="text"
                         placeholder="Search steps..."
                         class="w-full px-3 py-2 text-sm border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                         data-step-selector-target="search"
                         data-action="input->step-selector#search">
                </div>
                <div class="overflow-y-auto max-h-56" data-step-selector-target="options">
                  <!-- Options will be rendered here -->
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Remove the empty state message when steps are added
   */
  removeEmptyState() {
    if (!this.hasContainerTarget) return

    // Find and remove the empty state div (contains "No steps yet" text)
    const emptyState = this.containerTarget.querySelector('.text-center.py-12')
    if (emptyState && emptyState.textContent.includes('No steps yet')) {
      emptyState.remove()
    }
  }

  extractStepData(stepElement) {
    if (!stepElement) return {}
    
    const data = {}
    
    // Extract title
    const titleInput = stepElement.querySelector("input[name*='[title]']")
    if (titleInput) data.title = titleInput.value
    
    // Extract description
    const descInput = stepElement.querySelector("textarea[name*='[description]']")
    if (descInput) data.description = descInput.value
    
    // Extract type-specific fields
    const typeInput = stepElement.querySelector("input[name*='[type]']")
    if (typeInput) data.type = typeInput.value
    
    if (data.type === "question") {
      const questionInput = stepElement.querySelector("input[name*='[question]']")
      if (questionInput) data.question = questionInput.value
      
      const answerTypeInput = stepElement.querySelector("input[name*='[answer_type]']")
      if (answerTypeInput) data.answer_type = answerTypeInput.value
      
      const variableInput = stepElement.querySelector("input[name*='[variable_name]']")
      if (variableInput) data.variable_name = variableInput.value
    } else if (data.type === "action") {
      const instructionsInput = stepElement.querySelector("textarea[name*='[instructions]']")
      if (instructionsInput) data.instructions = instructionsInput.value
    }
    
    return data
  }
}
