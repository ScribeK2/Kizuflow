import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "variableSelect",
    "operatorSelect",
    "valueInput",
    "conditionInput",
    "conditionDisplay"
  ]
  static values = {
    workflowId: Number,
    variablesUrl: String
  }

  connect() {
    console.log("Rule builder connecting", this.element)
    
    // Parse existing condition if present
    this.parseExistingCondition()
    
    // Build condition when any field changes
    this.setupListeners()
    
    // Load variables from form and API
    // Use a small delay to ensure DOM is ready
    setTimeout(() => {
      this.refreshVariables()
    }, 100)
    
    // Listen for workflow changes to update variables
    this.setupWorkflowChangeListener()
    
    // Also listen for custom event to refresh variables
    this.element.addEventListener('refresh-variables', () => {
      this.refreshVariables()
    })
  }

  disconnect() {
    // Cleanup listeners
    this.removeListeners()
    this.removeWorkflowChangeListener()
  }

  setupWorkflowChangeListener() {
    // Listen for changes in question steps that might affect variables
    const form = this.element.closest("form")
    if (form) {
      this.workflowChangeHandler = () => {
        setTimeout(() => this.refreshVariables(), 100)
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

  refreshVariables() {
    console.log("Rule builder: refreshVariables called", {
      hasVariablesUrl: this.hasVariablesUrlValue,
      variablesUrl: this.variablesUrlValue
    })
    
    // Extract variables from form first (includes unsaved steps)
    const formVariables = this.extractVariablesFromForm()
    console.log("Rule builder: Form variables:", formVariables)
    
    // Also try to load from API if available
    if (this.hasVariablesUrlValue && this.variablesUrlValue) {
      console.log("Rule builder: Loading variables from API:", this.variablesUrlValue)
      this.loadVariables().then(apiVariables => {
        console.log("Rule builder: API variables:", apiVariables)
        // Merge form variables with API variables (form takes precedence)
        const allVariables = [...new Set([...formVariables, ...apiVariables])]
        console.log("Rule builder: All variables (merged):", allVariables)
        this.populateVariableDropdown(allVariables)
      }).catch(error => {
        console.error("Rule builder: Error loading variables from API:", error)
        // Fallback to form variables only
        this.populateVariableDropdown(formVariables)
      })
    } else {
      console.log("Rule builder: No API URL, using form variables only")
      // Just use form variables
      this.populateVariableDropdown(formVariables)
    }
  }

  extractVariablesFromForm() {
    const variables = []
    const form = this.element.closest("form")
    if (!form) {
      console.warn("Rule builder: Form not found")
      return variables
    }
    
    // Find all question step items
    const stepItems = form.querySelectorAll(".step-item")
    console.log(`Rule builder: Found ${stepItems.length} step items`)
    
    stepItems.forEach((stepItem, index) => {
      // Check if this is a question step
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      if (!typeInput || typeInput.value !== "question") return
      
      // Find variable name input
      const variableInput = stepItem.querySelector("input[name*='[variable_name]']")
      if (variableInput && variableInput.value.trim()) {
        const variableName = variableInput.value.trim()
        if (variableName && !variables.includes(variableName)) {
          variables.push(variableName)
          console.log(`Rule builder: Found variable: ${variableName}`)
        }
      } else {
        const titleInput = stepItem.querySelector("input[name*='[title]']")
        const title = titleInput ? titleInput.value : `Step ${index + 1}`
        console.log(`Rule builder: Question step "${title}" has no variable_name set`)
      }
    })
    
    console.log(`Rule builder: Extracted ${variables.length} variables:`, variables)
    return variables.sort()
  }

  populateVariableDropdown(variables) {
    if (!this.hasVariableSelectTarget) {
      console.warn("Rule builder: Variable select target not found")
      return
    }
    
    console.log(`Rule builder: Populating dropdown with ${variables.length} variables`)
    
    // Store current selection
    const currentValue = this.variableSelectTarget.value
    
    // Get existing options (server-rendered ones)
    const existingOptions = Array.from(this.variableSelectTarget.options)
      .map(opt => ({ value: opt.value, text: opt.text }))
      .filter(opt => opt.value !== "") // Exclude placeholder
    
    // Merge with new variables (avoid duplicates)
    const allVariableValues = [...new Set([...existingOptions.map(o => o.value), ...variables])]
    
    // Only update if we have new variables or if existing options are empty
    if (variables.length > 0 || existingOptions.length === 0) {
      // Clear existing options (except the first placeholder)
      const placeholder = this.variableSelectTarget.querySelector('option[value=""]')
      this.variableSelectTarget.innerHTML = ""
      if (placeholder) {
        this.variableSelectTarget.appendChild(placeholder)
      }
      
      // Add all variables (from both server-rendered and dynamically found)
      allVariableValues.forEach(variable => {
        const option = document.createElement('option')
        option.value = variable
        option.textContent = variable
        this.variableSelectTarget.appendChild(option)
      })
      
      console.log(`Rule builder: Added ${allVariableValues.length} options to dropdown`)
    } else {
      console.log(`Rule builder: Keeping existing ${existingOptions.length} options, no new variables found`)
    }
    
    // Restore selection if still valid
    if (currentValue && allVariableValues.includes(currentValue)) {
      this.variableSelectTarget.value = currentValue
    } else if (allVariableValues.length > 0) {
      // If we have variables but no selection, try to parse condition
      this.parseExistingCondition()
    }
  }

  setupListeners() {
    this.variableSelectTarget?.addEventListener("change", () => this.buildCondition())
    this.operatorSelectTarget?.addEventListener("change", () => this.buildCondition())
    this.valueInputTarget?.addEventListener("input", () => this.buildCondition())
  }

  removeListeners() {
    this.variableSelectTarget?.removeEventListener("change", () => this.buildCondition())
    this.operatorSelectTarget?.removeEventListener("change", () => this.buildCondition())
    this.valueInputTarget?.removeEventListener("input", () => this.buildCondition())
  }

  parseExistingCondition() {
    if (!this.hasConditionInputTarget) return
    
    const condition = this.conditionInputTarget.value
    if (!condition || condition.trim() === "") return
    
    // Parse condition like "variable == 'value'" or "variable != 'value'"
    // Support: ==, !=, >, <, >=, <=
    const patterns = [
      /^(\w+)\s*(==|!=)\s*['"]([^'"]*)['"]$/,  // variable == 'value'
      /^(\w+)\s*(>|>=|<|<=)\s*(\d+)$/          // variable > 10
    ]
    
    for (const pattern of patterns) {
      const match = condition.match(pattern)
      if (match) {
        const variable = match[1]
        const operator = match[2]
        const value = match[3] || ""
        
        // Set dropdowns/input
        if (this.hasVariableSelectTarget) {
          this.variableSelectTarget.value = variable
        }
        if (this.hasOperatorSelectTarget) {
          this.operatorSelectTarget.value = operator
        }
        if (this.hasValueInputTarget) {
          this.valueInputTarget.value = value
        }
        
        return
      }
    }
  }

  buildCondition() {
    if (!this.hasConditionInputTarget) return
    
    const variable = this.variableSelectTarget?.value || ""
    const operator = this.operatorSelectTarget?.value || ""
    const value = this.valueInputTarget?.value || ""
    
    if (!variable || !operator) {
      this.conditionInputTarget.value = ""
      if (this.hasConditionDisplayTarget) {
        this.conditionDisplayTarget.textContent = "Not set"
      }
      return
    }
    
    // Build condition string based on operator type
    let condition = ""
    
    if (operator === "==" || operator === "!=") {
      // String operators need quotes
      condition = `${variable} ${operator} '${value}'`
    } else {
      // Numeric operators (>, <, >=, <=)
      condition = `${variable} ${operator} ${value}`
    }
    
    this.conditionInputTarget.value = condition
    
    // Update display
    if (this.hasConditionDisplayTarget) {
      this.conditionDisplayTarget.textContent = condition
    }
    
    // Trigger input event for preview updater
    this.conditionInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  async loadVariables() {
    if (!this.hasVariablesUrlValue || !this.variablesUrlValue) return []
    
    try {
      const response = await fetch(this.variablesUrlValue)
      if (!response.ok) return []
      
      const data = await response.json()
      return data.variables || []
    } catch (error) {
      console.error("Failed to load variables:", error)
      return []
    }
  }
}

