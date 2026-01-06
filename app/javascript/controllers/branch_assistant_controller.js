import { Controller } from "@hotwired/stimulus"
import { BranchSuggestionService } from "../services/branch_suggestion_service"

export default class extends Controller {
  static targets = ["panel", "suggestionsContainer", "suggestionTemplate"]
  static values = {
    workflowId: Number
  }

  connect() {
    this.suggestions = []
    // Delay to ensure DOM is ready
    setTimeout(() => {
      this.loadSuggestions()
    }, 200)
    this.setupWorkflowChangeListener()
  }

  disconnect() {
    this.removeWorkflowChangeListener()
  }

  setupWorkflowChangeListener() {
    const form = this.element.closest("form")
    if (form) {
      this.workflowChangeHandler = () => {
        setTimeout(() => {
          this.loadSuggestions()
        }, 100)
      }
      form.addEventListener("input", this.workflowChangeHandler)
      form.addEventListener("change", this.workflowChangeHandler)
    }
  }

  removeWorkflowChangeListener() {
    const form = this.element.closest("form")
    if (form && this.workflowChangeHandler) {
      form.removeEventListener("input", this.workflowChangeHandler)
      form.removeEventListener("change", this.workflowChangeHandler)
    }
  }

  loadSuggestions() {
    const workflowSteps = this.getWorkflowSteps()
    const currentStepIndex = this.getCurrentStepIndex()
    
    if (currentStepIndex === null) {
      this.hidePanel()
      return
    }
    
    // Get suggestions from service
    this.suggestions = BranchSuggestionService.suggestBranches(workflowSteps, currentStepIndex)
    
    // Render suggestions
    this.renderSuggestions()
    
    // Show panel if we have suggestions and no branches exist yet
    const hasBranches = this.hasExistingBranches()
    
    
    if (this.suggestions.length > 0 && !hasBranches) {
      this.showPanel()
    } else {
      this.hidePanel()
    }
  }

  getWorkflowSteps() {
    const steps = []
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    const stepItems = workflowBuilder 
      ? workflowBuilder.querySelectorAll(".step-item")
      : document.querySelectorAll(".step-item")
    
    stepItems.forEach((stepItem, index) => {
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      
      if (!typeInput || !titleInput) return
      
      const type = typeInput.value
      const title = titleInput.value.trim()
      
      if (!type || !title) return
      
      const step = {
        index: index,
        type: type,
        title: title,
        answer_type: "",
        variable_name: "",
        options: []
      }
      
      // Get type-specific fields
      if (type === "question") {
        const questionInput = stepItem.querySelector("input[name*='[question]']")
        step.question = questionInput ? questionInput.value : ""
        
        // Try multiple ways to get answer_type (hidden input, checked radio, or any input)
        let answerTypeInput = stepItem.querySelector("input[name*='[answer_type]'][type='hidden']")
        if (!answerTypeInput || !answerTypeInput.value) {
          answerTypeInput = stepItem.querySelector("input[name*='[answer_type]']:checked")
        }
        if (!answerTypeInput || !answerTypeInput.value) {
          answerTypeInput = stepItem.querySelector("input[name*='[answer_type]']")
        }
        step.answer_type = answerTypeInput ? answerTypeInput.value : ""
        
        const variableInput = stepItem.querySelector("input[name*='[variable_name]']")
        step.variable_name = variableInput ? variableInput.value.trim() : ""
        
        // Get options for multiple choice/dropdown
        if (step.answer_type === 'multiple_choice' || step.answer_type === 'dropdown') {
          const optionInputs = stepItem.querySelectorAll("input[name*='[options]'][name*='[label]']")
          step.options = Array.from(optionInputs).map(input => {
            const valueInput = input.closest('.option-item')?.querySelector("input[name*='[value]']")
            return {
              label: input.value,
              value: valueInput ? valueInput.value : input.value
            }
          }).filter(opt => opt.label || opt.value)
        }
      }
      
      steps.push(step)
    })
    
    return steps
  }

  getCurrentStepIndex() {
    const stepItem = this.element.closest('.step-item')
    if (!stepItem) {
      // Try alternative: find step item by looking for parent with step-item class
      let parent = this.element.parentElement
      while (parent && !parent.classList.contains('step-item')) {
        parent = parent.parentElement
      }
      if (parent) {
        const indexInput = parent.querySelector("input[name*='[index]']")
        return indexInput ? parseInt(indexInput.value) : null
      }
      return null
    }
    
    const indexInput = stepItem.querySelector("input[name*='[index]']")
    if (indexInput) {
      return parseInt(indexInput.value)
    }
    
    // Fallback: try to determine index from position in workflow
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    if (workflowBuilder) {
      const stepItems = workflowBuilder.querySelectorAll(".step-item")
      return Array.from(stepItems).indexOf(stepItem)
    }
    
    return null
  }

  hasExistingBranches() {
    // Check if branches exist in the current element (we're inside multi-branch controller)
    const branchesContainer = this.element.querySelector('[data-multi-branch-target="branchesContainer"]')
    if (!branchesContainer) return false
    
    const branchItems = branchesContainer.querySelectorAll('.branch-item')
    
    // Check if branches have actual content (condition or path set)
    let hasRealBranches = false
    branchItems.forEach(branchItem => {
      const conditionInput = branchItem.querySelector('input[name*="[branches][][condition]"]')
      const pathInput = branchItem.querySelector('input[name*="[branches][][path]"], select[name*="[branches][][path]"]')
      
      const hasCondition = conditionInput && conditionInput.value && conditionInput.value.trim() !== ''
      const hasPath = pathInput && pathInput.value && pathInput.value.trim() !== ''
      
      if (hasCondition || hasPath) {
        hasRealBranches = true
      }
    })
    
    return hasRealBranches
  }

  renderSuggestions() {
    if (!this.hasSuggestionsContainerTarget) return
    
    if (this.suggestions.length === 0) {
      this.suggestionsContainerTarget.innerHTML = ''
      return
    }
    
    const suggestionsHtml = this.suggestions.map((suggestion, index) => {
      return this.renderSuggestionCard(suggestion, index)
    }).join('')
    
    this.suggestionsContainerTarget.innerHTML = suggestionsHtml
  }

  renderSuggestionCard(suggestion, index) {
    const branchesCount = suggestion.branches ? suggestion.branches.length : 0
    const typeIcon = this.getTypeIcon(suggestion.type)
    const typeColor = this.getTypeColor(suggestion.type)
    
    return `
      <div class="border rounded-lg p-4 bg-gradient-to-br from-blue-50 to-purple-50 border-blue-200 hover:border-blue-300 transition-all">
        <div class="flex items-start justify-between mb-2">
          <div class="flex items-center gap-2">
            <span class="${typeColor} text-xl">${typeIcon}</span>
            <div>
              <h4 class="font-semibold text-gray-900">${this.escapeHtml(suggestion.title)}</h4>
              <p class="text-xs text-gray-600 mt-0.5">${this.escapeHtml(suggestion.description)}</p>
            </div>
          </div>
        </div>
        
        <div class="mt-3 space-y-1">
          ${suggestion.branches ? suggestion.branches.map((branch, branchIndex) => `
            <div class="text-xs font-mono bg-white/60 rounded px-2 py-1 text-gray-700">
              ${this.escapeHtml(branch.label)}: ${this.escapeHtml(branch.condition)}
            </div>
          `).join('') : ''}
        </div>
        
        <button type="button"
                class="mt-3 w-full bg-blue-600 hover:bg-blue-700 text-white text-sm font-medium py-2 px-4 rounded-lg transition-colors"
                data-action="click->branch-assistant#applySuggestion"
                data-suggestion-index="${index}">
          Apply This Suggestion
        </button>
      </div>
    `
  }

  applySuggestion(event) {
    const suggestionIndex = parseInt(event.currentTarget.dataset.suggestionIndex)
    const suggestion = this.suggestions[suggestionIndex]
    
    if (!suggestion || !suggestion.branches) return
    
    // Get multi-branch controller
    const multiBranchController = this.element.closest('[data-controller*="multi-branch"]')
    if (!multiBranchController) return
    
    const application = window.Stimulus
    if (!application) return
    
    const controller = application.getControllerForElementAndIdentifier(multiBranchController, "multi-branch")
    if (!controller) return
    
    // Clear existing branches first
    const branchesContainer = multiBranchController.querySelector('[data-multi-branch-target="branchesContainer"]')
    if (branchesContainer) {
      branchesContainer.innerHTML = ''
    }
    
    // Add branches from suggestion
    suggestion.branches.forEach((branch, index) => {
      if (controller.addBranchDirect) {
        controller.addBranchDirect(branch.condition, branch.path)
        // Wait for branch to be created and rule builder to initialize
        setTimeout(() => {
          this.updateBranchCondition(index, branch.condition)
        }, 300 * (index + 1)) // Staggered delay
      } else {
        // Fallback: trigger addBranch and then update condition
        controller.addBranch(event)
        setTimeout(() => {
          this.updateBranchCondition(index, branch.condition)
        }, 400)
      }
    })
    
    // Hide panel after applying (with delay to allow branches to be created)
    setTimeout(() => {
      this.hidePanel()
    }, 500)
    
    // Notify preview update
    if (controller.notifyPreviewUpdate) {
      setTimeout(() => {
        controller.notifyPreviewUpdate()
      }, 600)
    }
  }

  updateBranchCondition(branchIndex, condition) {
    const multiBranchController = this.element.closest('[data-controller*="multi-branch"]')
    if (!multiBranchController) return
    
    const branchesContainer = multiBranchController.querySelector('[data-multi-branch-target="branchesContainer"]')
    if (!branchesContainer) return
    
    const branchItems = branchesContainer.querySelectorAll('.branch-item')
    const branchItem = branchItems[branchIndex]
    
    if (!branchItem) return
    
    // Set condition in hidden input first
    const conditionInput = branchItem.querySelector('[data-rule-builder-target="conditionInput"]')
    if (conditionInput) {
      conditionInput.value = condition
      conditionInput.dispatchEvent(new Event("input", { bubbles: true }))
    }
    
    // Parse and populate condition fields in rule builder
    const ruleBuilder = branchItem.querySelector('[data-controller*="rule-builder"]')
    if (!ruleBuilder) return
    
    const application = window.Stimulus
    if (!application) return
    
    // Wait a bit more for rule builder to fully connect
    setTimeout(() => {
      try {
        const controller = application.getControllerForElementAndIdentifier(ruleBuilder, "rule-builder")
        if (controller) {
          // First, refresh variables to ensure dropdown is populated
          if (controller.refreshVariables) {
            controller.refreshVariables()
          }
          
          // Wait a bit for variables to load, then parse condition
          setTimeout(() => {
            // Parse condition to populate variable/operator/value fields
            if (controller.parseExistingCondition) {
              controller.parseExistingCondition()
            }
            
            // If parseExistingCondition didn't work (variable not in dropdown), manually set fields
            if (condition) {
              // Try to parse the condition - support both string and numeric patterns
              let match = condition.match(/^(\w+)\s*(==|!=)\s*['"]([^'"]*)['"]$/)  // variable == 'value'
              if (!match) {
                match = condition.match(/^(\w+)\s*(>|>=|<|<=)\s*(\d+)$/)  // variable > 10
              }
              
              if (match) {
                const varName = match[1]
                const operator = match[2]
                const value = match[3] || match[4] || ""
                
                // Manually set fields if targets exist
                if (controller.hasVariableSelectTarget && controller.variableSelectTarget) {
                  // Add variable to dropdown if not present
                  const optionExists = Array.from(controller.variableSelectTarget.options).some(opt => opt.value === varName)
                  if (!optionExists) {
                    const option = document.createElement('option')
                    option.value = varName
                    option.textContent = varName
                    controller.variableSelectTarget.appendChild(option)
                  }
                  controller.variableSelectTarget.value = varName
                }
                
                if (controller.hasOperatorSelectTarget && controller.operatorSelectTarget) {
                  controller.operatorSelectTarget.value = operator
                }
                
                if (controller.hasValueInputTarget && controller.valueInputTarget) {
                  controller.valueInputTarget.value = value
                }
                
                // Now build the condition
                if (controller.buildCondition) {
                  controller.buildCondition()
                }
              }
            }
          }, 200)
        }
      } catch (e) {
        // Silently handle errors
      }
    }, 100)
  }

  showPanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
    }
  }

  hidePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
    }
  }

  dismiss() {
    this.hidePanel()
  }

  getTypeIcon(type) {
    const icons = {
      'yes_no': '✅',
      'multiple_choice': '📋',
      'numeric': '🔢',
      'text': '📝'
    }
    return icons[type] || '💡'
  }

  getTypeColor(type) {
    const colors = {
      'yes_no': 'text-green-600',
      'multiple_choice': 'text-blue-600',
      'numeric': 'text-purple-600',
      'text': 'text-gray-600'
    }
    return colors[type] || 'text-gray-600'
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

