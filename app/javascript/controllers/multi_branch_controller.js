import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["branchesContainer", "branchTemplate", "elsePathContainer"]
  static values = {
    workflowId: Number,
    variablesUrl: String
  }

  connect() {
    // Check if branches already exist (rendered by ERB)
    const existingBranches = this.branchesContainerTarget.querySelectorAll('.branch-item')
    
    if (existingBranches.length === 0) {
      // No branches exist, check for legacy format or add one empty branch
      this.initializeBranches()
    } else {
      // Branches already exist from ERB, initialize rule builders
      // Use a longer delay to ensure Stimulus controllers are connected
      setTimeout(() => {
        existingBranches.forEach((branchItem, index) => {
          this.initializeBranchRuleBuilder(index)
        })
      }, 300)
    }
    
    // Set up listeners for workflow changes
    this.setupWorkflowChangeListener()
  }

  initializeBranches() {
    // Check for legacy true_path/false_path
    const truePath = this.getLegacyTruePath()
    const falsePath = this.getLegacyFalsePath()
    
    if (truePath || falsePath) {
      // Convert legacy format to branches
      // Note: We need to get the condition from the legacy condition input
      const stepItem = this.element.closest('.step-item')
      const conditionInput = stepItem?.querySelector('input[name*="[condition]"]')
      const condition = conditionInput ? conditionInput.value : ""
      
      if (truePath) {
        this.addBranchDirect(condition, truePath)
      }
      if (falsePath) {
        // For false path, we need to create a condition that's the opposite
        // For simplicity, we'll add it as-is and let the user edit it
        this.addBranchDirect("", falsePath)
      }
    } else {
      // Start with one empty branch
      this.addBranchDirect()
    }
  }

  addBranchDirect(condition = "", path = "") {
    if (!this.hasBranchesContainerTarget) return
    
    const branchIndex = this.branchesContainerTarget.querySelectorAll('.branch-item').length
    const branchHtml = this.createBranchHtml(branchIndex, condition, path)
    
    this.branchesContainerTarget.insertAdjacentHTML('beforeend', branchHtml)
    
    // Initialize rule builder for the new branch
    this.initializeBranchRuleBuilder(branchIndex)
    
    // Update hidden inputs
    this.updateBranchesInputs()
    
    // Refresh dropdowns
    this.refreshAllBranchDropdowns()
  }

  getExistingBranches() {
    // Extract branches from hidden inputs
    const branches = []
    const stepItem = this.element.closest('.step-item')
    if (!stepItem) return branches
    
    const branchInputs = stepItem.querySelectorAll('input[name*="[branches]"][name*="[condition]"]')
    branchInputs.forEach(input => {
      const condition = input.value
      const pathInput = input.closest('.branch-item')?.querySelector('select[name*="[path]"]')
      const path = pathInput ? pathInput.value : ''
      
      if (condition || path) {
        branches.push({ condition, path })
      }
    })
    
    return branches
  }

  getLegacyTruePath() {
    const stepItem = this.element.closest('.step-item')
    if (!stepItem) return null
    
    const truePathInput = stepItem.querySelector('input[name*="[true_path]"]')
    return truePathInput ? truePathInput.value : null
  }

  getLegacyFalsePath() {
    const stepItem = this.element.closest('.step-item')
    if (!stepItem) return null
    
    const falsePathInput = stepItem.querySelector('input[name*="[false_path]"]')
    return falsePathInput ? falsePathInput.value : null
  }

  setupWorkflowChangeListener() {
    const form = this.element.closest("form")
    if (form) {
      this.workflowChangeHandler = () => {
        // Refresh step options in all branch dropdowns
        this.refreshAllBranchDropdowns()
      }
      form.addEventListener("input", this.workflowChangeHandler)
      form.addEventListener("change", this.workflowChangeHandler)
    }
  }

  addBranch(event) {
    // Handle both event-based calls and direct calls
    if (event && event.preventDefault) {
      event.preventDefault()
    }
    
    if (!this.hasBranchesContainerTarget) {
      console.error("Multi-branch controller: branchesContainer target not found")
      return
    }
    
    const branchIndex = this.branchesContainerTarget.querySelectorAll('.branch-item').length
    const branchHtml = this.createBranchHtml(branchIndex, "", "")
    
    this.branchesContainerTarget.insertAdjacentHTML('beforeend', branchHtml)
    
    // Initialize rule builder for the new branch
    this.initializeBranchRuleBuilder(branchIndex)
    
    // Update hidden inputs
    this.updateBranchesInputs()
    
    // Refresh dropdowns
    this.refreshAllBranchDropdowns()
    
    // Notify preview update
    this.notifyPreviewUpdate()
  }

  createBranchHtml(index, condition, path) {
    const availableSteps = this.getAvailableSteps()
    const stepOptions = availableSteps.map(step => {
      const selected = step.title === path ? 'selected' : ''
      return `<option value="${this.escapeHtml(step.title)}" ${selected}>${this.escapeHtml(step.title)}</option>`
    }).join('')
    
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
               data-rule-builder-workflow-id-value="${this.workflowIdValue || ''}"
               data-rule-builder-variables-url-value="${this.variablesUrlValue || ''}">
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
                  <option value="==" ${condition.includes('==') ? 'selected' : ''}>Equals (==)</option>
                  <option value="!=" ${condition.includes('!=') ? 'selected' : ''}>Not Equals (!=)</option>
                  <option value=">" ${condition.match(/\s>\s/) && !condition.match(/>\s*=/) ? 'selected' : ''}>Greater Than (>)</option>
                  <option value=">=" ${condition.includes('>=') ? 'selected' : ''}>Greater or Equal (>=)</option>
                  <option value="<" ${condition.match(/\s<\s/) && !condition.match(/<\s*=/) ? 'selected' : ''}>Less Than (<)</option>
                  <option value="<=" ${condition.includes('<=') ? 'selected' : ''}>Less or Equal (<=)</option>
                </select>
              </div>
              
              <div>
                <label class="block text-xs text-gray-600 mb-1">Value</label>
                <input type="text" 
                       data-rule-builder-target="valueInput" 
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
              <option value="">-- Select step --</option>
              ${stepOptions}
            </select>
          </div>
        </div>
      </div>
    `
  }

  initializeBranchRuleBuilder(index) {
    const branchItem = this.branchesContainerTarget.querySelector(`[data-branch-index="${index}"]`)
    if (!branchItem) return
    
    const ruleBuilder = branchItem.querySelector('[data-controller*="rule-builder"]')
    if (!ruleBuilder) {
      console.warn(`Rule builder not found for branch ${index}`)
      return
    }
    
    // The rule builder should initialize itself via Stimulus
    // Just dispatch a refresh event to ensure it refreshes variables
    // Use a delay to ensure Stimulus has connected the controller
    setTimeout(() => {
      ruleBuilder.dispatchEvent(new CustomEvent('refresh-variables'))
      
      // Also try to get the controller directly (for debugging)
      const application = window.Stimulus
      if (application) {
        try {
          const controller = application.getControllerForElementAndIdentifier(ruleBuilder, "rule-builder")
          if (controller) {
            console.log(`Rule builder found for branch ${index}, refreshing variables`)
            if (typeof controller.refreshVariables === 'function') {
              controller.refreshVariables()
            }
          } else {
            console.warn(`Rule builder controller not found for branch ${index}, but element exists`)
          }
        } catch (e) {
          console.warn(`Error getting rule builder controller: ${e.message}`)
        }
      }
    }, 500)
  }

  removeBranch(event) {
    const branchIndex = event.currentTarget.dataset.branchIndex
    const branchItem = this.branchesContainerTarget.querySelector(`[data-branch-index="${branchIndex}"]`)
    
    if (branchItem) {
      branchItem.remove()
      this.updateBranchesInputs()
      this.refreshAllBranchDropdowns()
      this.notifyPreviewUpdate()
    }
  }

  updateBranchesInputs() {
    // Update branch indices
    const branchItems = this.branchesContainerTarget.querySelectorAll('.branch-item')
    branchItems.forEach((item, index) => {
      item.setAttribute('data-branch-index', index)
      const header = item.querySelector('.text-sm.font-medium')
      if (header) {
        header.textContent = `Branch ${index + 1}`
      }
    })
  }

  refreshAllBranchDropdowns() {
    const availableSteps = this.getAvailableSteps()
    const branchPathSelects = this.element.querySelectorAll('[data-multi-branch-target="branchPathSelect"]')
    
    branchPathSelects.forEach(select => {
      const currentValue = select.value
      const currentOptions = Array.from(select.options).map(opt => opt.value)
      
      // Update options
      const optionsHtml = availableSteps.map(step => {
        const selected = step.title === currentValue ? 'selected' : ''
        return `<option value="${this.escapeHtml(step.title)}" ${selected}>${this.escapeHtml(step.title)}</option>`
      }).join('')
      
      select.innerHTML = '<option value="">-- Select step --</option>' + optionsHtml
      
      // Restore selection if still valid
      if (currentValue && availableSteps.some(s => s.title === currentValue)) {
        select.value = currentValue
      }
    })
  }

  getAvailableSteps() {
    const steps = []
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    const stepItems = workflowBuilder 
      ? workflowBuilder.querySelectorAll(".step-item")
      : document.querySelectorAll(".step-item")
    
    stepItems.forEach(stepItem => {
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      const currentStepItem = this.element.closest('.step-item')
      
      if (typeInput && titleInput && stepItem !== currentStepItem) {
        const title = titleInput.value.trim()
        if (title) {
          steps.push({ title })
        }
      }
    })
    
    return steps
  }

  notifyPreviewUpdate() {
    // Dispatch event for preview updater
    this.element.dispatchEvent(new CustomEvent("workflow-steps-changed", { bubbles: true }))
    
    // Also trigger workflow builder update
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    if (workflowBuilder) {
      workflowBuilder.dispatchEvent(new CustomEvent("workflow:updated"))
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

