import { Controller } from "@hotwired/stimulus"
import { stepTextLabel } from "../services/icon_service"

/**
 * Yes/No Branch Controller
 * 
 * Provides one-click branch setup for decision steps that follow Yes/No questions.
 * Automatically detects preceding Yes/No questions and offers quick branch configuration.
 */
export default class extends Controller {
  static targets = [
    "suggestionPanel",
    "questionTitle",
    "variableName", 
    "yesPathSelect",
    "noPathSelect",
    "noPrecedingQuestions"
  ]
  
  static values = {
    stepIndex: Number,
    workflowId: Number
  }

  connect() {
    // Find preceding Yes/No questions
    this.precedingYesNoQuestions = this.findPrecedingYesNoQuestions()
    
    // Show or hide the suggestion panel
    if (this.precedingYesNoQuestions.length > 0) {
      this.showSuggestions()
    } else {
      this.hideSuggestions()
    }
    
    // Listen for form changes (new questions added)
    this.setupFormChangeListener()
    
    // Populate step dropdowns
    this.populateStepDropdowns()
  }

  disconnect() {
    this.removeFormChangeListener()
  }

  /**
   * Find all Yes/No question steps before the current decision step
   */
  findPrecedingYesNoQuestions() {
    const questions = []
    const form = this.element.closest("form")
    if (!form) return questions
    
    const stepItems = form.querySelectorAll(".step-item")
    const currentStepIndex = this.stepIndexValue
    
    stepItems.forEach((stepItem, index) => {
      // Only look at steps before the current one
      if (index >= currentStepIndex) return
      
      // Check if it's a question step
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      if (!typeInput || typeInput.value !== "question") return
      
      // Check if it's a Yes/No question
      let answerType = ''
      const hiddenAnswerType = stepItem.querySelector("input[name*='[answer_type]'][type='hidden']")
      const checkedAnswerType = stepItem.querySelector("input[name*='[answer_type]']:checked")
      answerType = hiddenAnswerType?.value || checkedAnswerType?.value || ''
      
      if (answerType !== 'yes_no') return
      
      // Get the variable name and title
      const variableInput = stepItem.querySelector("input[name*='[variable_name]']")
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      
      const variableName = variableInput?.value?.trim()
      const title = titleInput?.value?.trim() || `Question ${index + 1}`
      
      if (variableName) {
        questions.push({
          index: index,
          title: title,
          variableName: variableName,
          stepNumber: index + 1
        })
      }
    })
    
    // Return most recent first
    return questions.reverse()
  }

  /**
   * Get all available steps for the path dropdowns
   */
  getAvailableSteps() {
    const steps = []
    const form = this.element.closest("form")
    if (!form) return steps
    
    const stepItems = form.querySelectorAll(".step-item")
    
    stepItems.forEach((stepItem, index) => {
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      const idInput = stepItem.querySelector("input[name*='[id]']")
      
      const title = titleInput?.value?.trim()
      const type = typeInput?.value
      const id = idInput?.value
      
      if (title) {
        steps.push({
          index: index,
          title: title,
          type: type,
          id: id,
          stepNumber: index + 1
        })
      }
    })
    
    return steps
  }

  /**
   * Populate the step selection dropdowns
   */
  populateStepDropdowns() {
    const steps = this.getAvailableSteps()
    
    const dropdowns = [
      this.hasYesPathSelectTarget ? this.yesPathSelectTarget : null,
      this.hasNoPathSelectTarget ? this.noPathSelectTarget : null
    ].filter(Boolean)
    
    dropdowns.forEach(dropdown => {
      const currentValue = dropdown.value
      
      // Clear and rebuild
      dropdown.innerHTML = '<option value="">-- Select step --</option>'
      
      steps.forEach(step => {
        const option = document.createElement('option')
        option.value = step.title // Use title for now (will be updated to ID later)
        option.dataset.stepId = step.id
        option.textContent = `${step.stepNumber}. ${step.title}`
        
        // Add type indicator (plain text symbols for <option> tags)
        option.textContent = `${stepTextLabel(step.type)} ${step.stepNumber}. ${step.title}`
        
        dropdown.appendChild(option)
      })
      
      // Restore selection if valid
      if (currentValue) {
        dropdown.value = currentValue
      }
    })
  }

  /**
   * Show the suggestion panel with the most recent Yes/No question
   */
  showSuggestions() {
    if (!this.hasSuggestionPanelTarget) return
    
    const mostRecent = this.precedingYesNoQuestions[0]
    if (!mostRecent) return
    
    // Update the display
    if (this.hasQuestionTitleTarget) {
      this.questionTitleTarget.textContent = mostRecent.title
    }
    if (this.hasVariableNameTarget) {
      this.variableNameTarget.textContent = mostRecent.variableName
    }
    
    // Store the selected question data
    this.selectedQuestion = mostRecent
    
    // Show panel
    this.suggestionPanelTarget.classList.remove('hidden')
    
    // Hide "no questions" message
    if (this.hasNoPrecedingQuestionsTarget) {
      this.noPrecedingQuestionsTarget.classList.add('hidden')
    }
  }

  /**
   * Hide the suggestion panel
   */
  hideSuggestions() {
    if (this.hasSuggestionPanelTarget) {
      this.suggestionPanelTarget.classList.add('hidden')
    }
    
    // Show "no questions" message
    if (this.hasNoPrecedingQuestionsTarget) {
      this.noPrecedingQuestionsTarget.classList.remove('hidden')
    }
  }

  /**
   * Select a different Yes/No question from the list
   */
  selectQuestion(event) {
    const index = parseInt(event.currentTarget.dataset.questionIndex)
    const question = this.precedingYesNoQuestions.find(q => q.index === index)
    
    if (question) {
      this.selectedQuestion = question
      
      if (this.hasQuestionTitleTarget) {
        this.questionTitleTarget.textContent = question.title
      }
      if (this.hasVariableNameTarget) {
        this.variableNameTarget.textContent = question.variableName
      }
    }
  }

  /**
   * Apply the suggested Yes/No branches
   */
  apply(event) {
    event.preventDefault()
    
    if (!this.selectedQuestion) return
    
    const yesPath = this.hasYesPathSelectTarget ? this.yesPathSelectTarget.value : ''
    const noPath = this.hasNoPathSelectTarget ? this.noPathSelectTarget.value : ''
    
    // Build the branches
    const branches = [
      {
        condition: `${this.selectedQuestion.variableName} == 'yes'`,
        path: yesPath
      },
      {
        condition: `${this.selectedQuestion.variableName} == 'no'`,
        path: noPath
      }
    ]
    
    // Dispatch event for the multi-branch controller to handle
    const applyEvent = new CustomEvent('yes-no-branch:apply', {
      detail: { branches },
      bubbles: true
    })
    this.element.dispatchEvent(applyEvent)
    
    // Also try to directly update the branch fields if they exist
    this.applyBranchesToForm(branches)
    
    // Hide the suggestion panel after applying
    this.dismiss()
  }

  /**
   * Apply branches directly to the form (fallback if event isn't handled)
   */
  applyBranchesToForm(branches) {
    const form = this.element.closest("form")
    if (!form) return
    
    // Find the branches container for this decision step
    const stepItem = this.element.closest(".step-item") || this.element.closest("[data-controller*='multi-branch']")
    if (!stepItem) return
    
    const branchesContainer = stepItem.querySelector("[data-multi-branch-target='branchesContainer']")
    if (!branchesContainer) return
    
    // Get the multi-branch controller
    const multiBranchElement = stepItem.querySelector("[data-controller*='multi-branch']") || stepItem
    if (!multiBranchElement) return
    
    // Dispatch to multi-branch controller
    const event = new CustomEvent('add-branches', {
      detail: { branches },
      bubbles: true
    })
    multiBranchElement.dispatchEvent(event)
  }

  /**
   * Dismiss/hide the suggestion panel
   */
  dismiss() {
    if (this.hasSuggestionPanelTarget) {
      this.suggestionPanelTarget.classList.add('hidden')
    }
  }

  /**
   * Manual configure - hide suggestions and show regular form
   */
  manualConfigure() {
    this.dismiss()
  }

  /**
   * Setup listener for form changes
   */
  setupFormChangeListener() {
    const form = this.element.closest("form")
    if (!form) return
    
    this.formChangeHandler = (event) => {
      // Refresh if answer type or variable name changes
      if (event.target.matches && (
        event.target.matches("input[name*='[answer_type]']") ||
        event.target.matches("input[name*='[variable_name]']") ||
        event.target.matches("input[name*='[title]']")
      )) {
        setTimeout(() => {
          this.precedingYesNoQuestions = this.findPrecedingYesNoQuestions()
          if (this.precedingYesNoQuestions.length > 0) {
            this.showSuggestions()
          }
          this.populateStepDropdowns()
        }, 100)
      }
    }
    
    form.addEventListener("change", this.formChangeHandler)
    form.addEventListener("input", this.formChangeHandler)
  }

  removeFormChangeListener() {
    const form = this.element.closest("form")
    if (form && this.formChangeHandler) {
      form.removeEventListener("change", this.formChangeHandler)
      form.removeEventListener("input", this.formChangeHandler)
    }
  }
}

