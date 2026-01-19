import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "error"]
  static values = { 
    stepType: String,
    stepIndex: Number
  }

  connect() {
    // Store field handlers for cleanup
    this.fieldHandlers = new Map()

    // Set up validation on all fields
    this.setupFieldValidation()

    // Validate on form submission
    this.formElement = this.element.closest("form")
    if (this.formElement) {
      this.boundValidateBeforeSubmit = (e) => this.validateBeforeSubmit(e)
      this.formElement.addEventListener("submit", this.boundValidateBeforeSubmit)
    }
  }

  disconnect() {
    if (this.formElement && this.boundValidateBeforeSubmit) {
      this.formElement.removeEventListener("submit", this.boundValidateBeforeSubmit)
    }
    // Clean up field listeners
    if (this.fieldHandlers) {
      this.fieldHandlers.forEach((handlers, field) => {
        field.removeEventListener("blur", handlers.blur)
        field.removeEventListener("input", handlers.input)
      })
      this.fieldHandlers.clear()
    }
  }

  setupFieldValidation() {
    // Validate on blur and input events
    this.fieldTargets.forEach(field => {
      if (!field.dataset.validationSetup) {
        const blurHandler = () => this.validateField(field)
        const inputHandler = () => this.clearFieldError(field)

        field.addEventListener("blur", blurHandler)
        field.addEventListener("input", inputHandler)
        field.dataset.validationSetup = "true"

        // Store handlers for cleanup
        this.fieldHandlers.set(field, { blur: blurHandler, input: inputHandler })
      }
    })
  }

  validateField(field) {
    const fieldName = field.name || field.id
    const value = field.value?.trim() || ""
    
    // Clear previous error
    this.clearFieldError(field)
    
    // Check if field is required
    if (field.hasAttribute("required") || field.hasAttribute("data-required")) {
      if (!value) {
        this.showFieldError(field, "This field is required")
        return false
      }
    }
    
    // Type-specific validation - only validate if field has a value or is required
    if (this.hasStepTypeValue && value) {
      if (this.stepTypeValue === "decision" && fieldName.includes("condition")) {
        // Only validate condition format if a value is provided
        return this.validateCondition(field, value)
      }
      
      if (this.stepTypeValue === "question" && fieldName.includes("answer_type")) {
        return this.validateAnswerType(field, value)
      }
    }
    
    return true
  }

  validateCondition(field, condition) {
    // Only validate if condition is provided (empty conditions are allowed for incomplete forms)
    if (!condition || !condition.trim()) {
      return true // Allow empty conditions - they'll be validated server-side if needed
    }
    
    // Basic condition syntax validation
    // Valid formats: "variable == 'value'", "variable != 'value'", etc.
    const validPatterns = [
      /^\w+\s*==\s*['"][^'"]*['"]/,  // variable == 'value'
      /^\w+\s*!=\s*['"][^'"]*['"]/,  // variable != 'value'
      /^\w+\s*>\s*\d+/,              // variable > 10
      /^\w+\s*<\s*\d+/,              // variable < 10
      /^\w+\s*>=\s*\d+/,             // variable >= 10
      /^\w+\s*<=\s*\d+/,             // variable <= 10
    ]
    
    const isValid = validPatterns.some(pattern => pattern.test(condition.trim()))
    
    if (!isValid) {
      this.showFieldError(field, "Invalid condition format. Use: variable == 'value' or variable != 'value'")
      return false
    }
    
    return true
  }

  validateAnswerType(field, answerType) {
    const validTypes = ["text", "yes_no", "multiple_choice", "dropdown", "date", "number", "file"]
    
    if (answerType && !validTypes.includes(answerType.toLowerCase())) {
      this.showFieldError(field, `Invalid answer type. Valid types: ${validTypes.join(", ")}`)
      return false
    }
    
    return true
  }

  validateBeforeSubmit(event) {
    console.log("Validating step:", this.stepTypeValue, this.stepIndexValue)
    
    // Check if this is a wizard form (step2) - be more lenient for drafts
    const form = this.formElement || this.element.closest("form")
    const isWizardForm = form && (form.action.includes("/step2") || form.action.includes("update_step2"))
    
    // Validate all fields in this step
    let isValid = true
    
    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })
    
    // Also validate the step as a whole
    if (!this.validateStep()) {
      isValid = false
    }
    
    if (!isValid) {
      console.warn("Validation failed for step:", this.stepTypeValue, this.stepIndexValue)
      
      // For wizard forms, only prevent if title is missing (required field)
      // Allow other validations to pass so users can save drafts
      if (isWizardForm) {
        const titleField = this.fieldTargets.find(f => f.name && f.name.includes("[title]"))
        if (titleField && titleField.value && titleField.value.trim()) {
          console.log("Wizard form: Title present, allowing submission despite other validation failures")
          return true // Allow submission if title is present
        }
      }
      
      event.preventDefault()
      event.stopPropagation()
      
      // Focus first invalid field
      const firstInvalidField = this.fieldTargets.find(field => {
        const errorContainer = this.getErrorContainer(field)
        return errorContainer && errorContainer.querySelector(".error-message")
      })
      
      if (firstInvalidField) {
        firstInvalidField.focus()
        firstInvalidField.scrollIntoView({ behavior: "smooth", block: "center" })
      }
      
      // Log validation failure for debugging
      console.warn("Form validation failed for step:", this.stepTypeValue, this.stepIndexValue)
    } else {
      console.log("Validation passed for step:", this.stepTypeValue, this.stepIndexValue)
    }
    
    return isValid
  }

  validateStep() {
    if (!this.hasStepTypeValue) return true
    
    const stepContainer = this.element.closest(".step-item")
    if (!stepContainer) return true
    
    // Get step fields
    const titleField = stepContainer.querySelector('input[name*="[title]"]')
    const stepType = this.stepTypeValue
    
    // Validate title
    if (titleField && !titleField.value?.trim()) {
      this.showFieldError(titleField, "Step title is required")
      return false
    }
    
    // Type-specific validation
    if (stepType === "question") {
      const questionField = stepContainer.querySelector('input[name*="[question]"]')
      if (!questionField?.value?.trim()) {
        this.showFieldError(questionField, "Question text is required")
        return false
      }
    }
    
    if (stepType === "decision") {
      // Check for multi-branch format (branches array)
      const branchItems = stepContainer.querySelectorAll('.branch-item')
      const hasBranches = branchItems.length > 0
      
      if (hasBranches) {
        // Multi-branch format: validate that branches with conditions have valid format
        // But don't require branches to be complete - allow saving incomplete forms
        for (const branchItem of branchItems) {
          const conditionInput = branchItem.querySelector('input[name*="[branches][][condition]"]')
          if (conditionInput && conditionInput.value.trim()) {
            // If condition is provided, validate its format
            if (!this.validateCondition(conditionInput, conditionInput.value)) {
              return false
            }
          }
        }
      } else {
        // Legacy format: check for single condition field
        const conditionField = stepContainer.querySelector('input[name*="[condition]"]')
        if (conditionField && conditionField.value.trim() && !this.validateCondition(conditionField, conditionField.value)) {
          return false
        }
      }
    }
    
    return true
  }

  showFieldError(field, message) {
    const errorContainer = this.getErrorContainer(field)
    if (!errorContainer) return
    
    // Remove existing error
    const existingError = errorContainer.querySelector(".error-message")
    if (existingError) {
      existingError.remove()
    }
    
    // Add error message
    const errorElement = document.createElement("div")
    errorElement.className = "error-message text-red-600 text-xs mt-1"
    errorElement.textContent = message
    errorContainer.appendChild(errorElement)
    
    // Add error styling to field
    field.classList.add("border-red-500")
    field.classList.remove("border-gray-300")
  }

  clearFieldError(field) {
    const errorContainer = this.getErrorContainer(field)
    if (errorContainer) {
      const errorMessage = errorContainer.querySelector(".error-message")
      if (errorMessage) {
        errorMessage.remove()
      }
    }
    
    // Remove error styling
    field.classList.remove("border-red-500")
    field.classList.add("border-gray-300")
  }

  getErrorContainer(field) {
    // Find the parent container (usually the field's parent div)
    let container = field.parentElement
    
    // Look for a container with specific class or create one
    while (container && !container.classList.contains("field-container") && container !== this.element) {
      container = container.parentElement
    }
    
    // If no container found, use the field's parent
    if (!container || container === this.element) {
      container = field.parentElement
    }
    
    return container
  }

  // Public method to trigger validation (can be called from outside)
  validate() {
    return this.validateStep()
  }
}

