import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.initializeSortable()
    // Set up event listeners for title changes
    this.setupTitleChangeListeners()
    // Refresh dropdowns on initial load (for edit views with existing steps)
    setTimeout(() => {
      this.refreshAllDropdowns()
    }, 100)
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async initializeSortable() {
    if (!this.hasContainerTarget) {
      return
    }
    
    try {
      const Sortable = (await import("sortablejs")).default
      this.sortable = Sortable.create(this.containerTarget, {
        animation: 150,
        handle: ".drag-handle",
        onEnd: (event) => {
          this.updateOrder(event)
          this.refreshAllDropdowns()
        }
      })
    } catch (error) {
      console.error("Failed to load Sortable:", error)
    }
  }

  setupTitleChangeListeners() {
    if (!this.hasContainerTarget) return
    
    // Use event delegation to handle title changes
    this.containerTarget.addEventListener("input", (event) => {
      if (event.target.matches("input[name*='[title]']")) {
        this.refreshAllDropdowns()
        this.notifyPreviewUpdate()
      }
      // Also refresh variable dropdowns when variable names change
      if (event.target.matches("input[name*='[variable_name]']")) {
        this.refreshAllRuleBuilders()
      }
    })
    
    // Also listen for select changes (dropdown updates)
    this.containerTarget.addEventListener("change", (event) => {
      if (event.target.matches("select[name*='[true_path]'], select[name*='[false_path]']")) {
        this.notifyPreviewUpdate()
      }
    })
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
        <label class="block text-sm font-medium text-gray-700 mb-1">Action Type</label>
        <input type="text" 
               name="workflow[steps][][action_type]" 
               value="${this.escapeHtml(stepData.action_type || "")}" 
               placeholder="e.g., Email, Notification, etc." 
               class="w-full border rounded px-3 py-2"
               data-step-form-target="field">
      </div>
      
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
    
    // Reinitialize Sortable after adding new element
    if (this.sortable) {
      this.sortable.destroy()
    }
    this.initializeSortable()
  }

  removeStep(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const stepElement = event.target.closest("[data-step-index]")
    if (stepElement) {
      stepElement.remove()
      this.updateOrderIndices()
      this.refreshAllDropdowns()
      this.refreshAllRuleBuilders()
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
                     value="${stepData.title || ""}" 
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
                        data-step-form-target="field">${stepData.description || ""}</textarea>
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
        return templateSelector + this.getQuestionFieldsHtml(stepData)
      case "decision":
        return templateSelector + this.getDecisionFieldsHtml(stepData, truePathOptions, falsePathOptions)
      case "action":
        return templateSelector + this.getActionFieldsHtml(stepData)
      default:
        return ""
    }
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
    
    // Generate else path options
    const elsePathOptions = this.buildDropdownOptions(this.getAllStepTitles(-1), stepData.else_path || "")
    
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
          <div class="field-container mt-1" data-controller="searchable-dropdown" data-searchable-dropdown-placeholder-value="-- Select step --">
            <select name="workflow[steps][][else_path]" 
                    class="w-full border rounded px-3 py-2"
                    data-step-form-target="field"
                    data-searchable-dropdown-target="select">
              ${elsePathOptions}
            </select>
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
    const stepOptions = this.buildDropdownOptions(this.getAllStepTitles(-1), path)
    
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
            <label class="block text-xs text-gray-600 mb-1">Condition</label>
            <input type="hidden" 
                   name="workflow[steps][][branches][][condition]" 
                   value="${this.escapeHtml(condition)}"
                   data-rule-builder-target="conditionInput"
                   data-step-form-target="field">
            
            <div class="grid grid-cols-3 gap-2 items-end">
              <div>
                <label class="block text-xs text-gray-600 mb-1">Variable</label>
                <select data-rule-builder-target="variableSelect" 
                        class="w-full border rounded px-2 py-1 text-sm"
                        data-action="change->rule-builder#buildCondition">
                  <option value="">-- Select variable --</option>
                </select>
              </div>
              
              <div>
                <label class="block text-xs text-gray-600 mb-1">Operator</label>
                <select data-rule-builder-target="operatorSelect" 
                        class="w-full border rounded px-2 py-1 text-sm"
                        data-action="change->rule-builder#buildCondition">
                  <option value="">-- Select --</option>
                  ${operatorOptions.map(opt => 
                    `<option value="${opt.value}" ${opt.selected ? 'selected' : ''}>${opt.label}</option>`
                  ).join('')}
                </select>
              </div>
              
              <div>
                <label class="block text-xs text-gray-600 mb-1">Value</label>
                <input type="text" 
                       data-rule-builder-target="valueInput" 
                       value="${this.escapeHtml(value)}"
                       placeholder="Value"
                       class="w-full border rounded px-2 py-1 text-sm"
                       data-action="input->rule-builder#buildCondition">
              </div>
            </div>
            
            <div class="mt-1 p-1 bg-gray-100 rounded text-xs font-mono text-gray-700">
              <span class="text-gray-500">Condition:</span>
              <span data-rule-builder-target="conditionDisplay">${condition || "Not set"}</span>
            </div>
          </div>
          
          <div>
            <label class="block text-xs text-gray-600 mb-1">Go to:</label>
            <select name="workflow[steps][][branches][][path]" 
                    class="w-full border rounded px-2 py-1 text-sm"
                    data-step-form-target="field"
                    data-multi-branch-target="branchPathSelect">
              ${stepOptions}
            </select>
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
}
