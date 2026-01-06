import { Controller } from "@hotwired/stimulus"
import Fuse from "fuse.js"

export default class extends Controller {
  static targets = ["button", "dropdown", "search", "options", "hiddenInput"]
  static values = {
    selectedValue: String,
    placeholder: String,
    name: String
  }

  connect() {
    this.isOpen = false
    this.steps = []
    this.filteredSteps = []
    
    // Close dropdown when clicking outside
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.boundHandleClickOutside)
    
    // Load steps and render
    this.loadSteps()
    this.render()
    
    // Listen for workflow changes to refresh steps
    this.setupWorkflowChangeListener()
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
    this.removeWorkflowChangeListener()
  }

  setupWorkflowChangeListener() {
    const form = this.element.closest("form")
    if (form) {
      this.workflowChangeHandler = () => {
        setTimeout(() => {
          this.loadSteps()
          this.render()
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

  handleClickOutside(event) {
    if (!this.isOpen) return
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  loadSteps() {
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    const stepItems = workflowBuilder 
      ? workflowBuilder.querySelectorAll(".step-item")
      : document.querySelectorAll(".step-item")
    
    const currentStepItem = this.element.closest('.step-item')
    
    this.steps = []
    
    stepItems.forEach((stepItem, index) => {
      // Skip current step (can't branch to itself)
      if (stepItem === currentStepItem) return
      
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      
      if (!typeInput || !titleInput) return
      
      const type = typeInput.value
      const title = titleInput.value.trim()
      
      if (!type || !title) return
      
      // Extract step details based on type
      const step = {
        index: index,
        type: type,
        title: title,
        description: "",
        preview: ""
      }
      
      // Get type-specific preview
      if (type === "question") {
        const questionInput = stepItem.querySelector("input[name*='[question]']")
        step.preview = questionInput ? questionInput.value : ""
        step.description = step.preview
      } else if (type === "action") {
        const instructionsInput = stepItem.querySelector("textarea[name*='[instructions]']")
        step.preview = instructionsInput ? instructionsInput.value.substring(0, 50) : ""
        const actionTypeInput = stepItem.querySelector("input[name*='[action_type]']")
        step.description = actionTypeInput ? actionTypeInput.value : "Action"
      } else if (type === "decision") {
        step.description = "Decision Point"
        const branchItems = stepItem.querySelectorAll('.branch-item')
        step.preview = `${branchItems.length} branch${branchItems.length !== 1 ? 'es' : ''}`
      } else if (type === "checkpoint") {
        step.description = "Checkpoint"
        step.preview = "Review point"
      }
      
      this.steps.push(step)
    })
    
    this.filteredSteps = [...this.steps]
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (!this.hasDropdownTarget) return
    
    this.isOpen = true
    this.dropdownTarget.classList.remove("hidden")
    this.buttonTarget.classList.add("ring-2", "ring-blue-500")
    
    // Focus search if available
    if (this.hasSearchTarget) {
      setTimeout(() => {
        this.searchTarget.focus()
      }, 50)
    }
  }

  close() {
    if (!this.hasDropdownTarget) return
    
    this.isOpen = false
    this.dropdownTarget.classList.add("hidden")
    this.buttonTarget.classList.remove("ring-2", "ring-blue-500")
    
    // Clear search
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.filteredSteps = [...this.steps]
      this.renderOptions()
    }
  }

  search(event) {
    const query = event.target.value.trim()
    
    if (!query) {
      this.filteredSteps = [...this.steps]
    } else {
      // Use Fuse.js for fuzzy search
      const fuse = new Fuse(this.steps, {
        keys: ['title', 'preview', 'description'],
        threshold: 0.3,
        includeScore: true
      })
      
      const results = fuse.search(query)
      this.filteredSteps = results.map(result => result.item)
    }
    
    this.renderOptions()
  }

  selectStep(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const stepIndex = event.currentTarget.dataset.stepIndex
    const step = this.steps.find(s => s.index.toString() === stepIndex)
    
    if (!step) return
    
    // Update hidden input
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = step.title
      this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
    
    // Update button text
    if (this.hasButtonTarget) {
      this.updateButtonText(step)
    }
    
    // Close dropdown
    this.close()
    
    // Notify parent controllers
    this.element.dispatchEvent(new CustomEvent("step-selected", {
      detail: { step: step },
      bubbles: true
    }))
  }

  updateButtonText(step) {
    if (!step) {
      const placeholder = this.hasPlaceholderValue ? this.placeholderValue : "-- Select step --"
      this.buttonTarget.innerHTML = `<span class="text-gray-500">${placeholder}</span>`
      return
    }
    
    const typeIcon = this.getTypeIcon(step.type)
    const typeColor = this.getTypeColor(step.type)
    
    this.buttonTarget.innerHTML = `
      <div class="flex items-center gap-2">
        <span class="${typeColor}">${typeIcon}</span>
        <span class="font-medium">${this.escapeHtml(step.title)}</span>
        <span class="text-xs text-gray-500">${this.escapeHtml(step.type)}</span>
      </div>
    `
  }

  render() {
    this.renderButton()
    this.renderOptions()
  }

  renderButton() {
    if (!this.hasButtonTarget) return
    
    const selectedStep = this.steps.find(s => s.title === this.selectedValueValue)
    
    if (selectedStep) {
      this.updateButtonText(selectedStep)
    } else {
      const placeholder = this.hasPlaceholderValue ? this.placeholderValue : "-- Select step --"
      this.buttonTarget.innerHTML = `<span class="text-gray-500">${placeholder}</span>`
    }
  }

  renderOptions() {
    if (!this.hasOptionsTarget) return
    
    if (this.filteredSteps.length === 0) {
      this.optionsTarget.innerHTML = `
        <div class="p-4 text-center text-gray-500 text-sm">
          No steps available
        </div>
      `
      return
    }
    
    const optionsHtml = this.filteredSteps.map(step => {
      const typeIcon = this.getTypeIcon(step.type)
      const typeColor = this.getTypeColor(step.type)
      const isSelected = step.title === this.selectedValueValue
      
      return `
        <button type="button"
                class="w-full text-left p-3 hover:bg-gray-50 border-b border-gray-100 last:border-b-0 transition-colors ${isSelected ? 'bg-blue-50 border-blue-200' : ''}"
                data-action="click->step-selector#selectStep"
                data-step-index="${step.index}"
                data-step-selector-target="option">
          <div class="flex items-start gap-3">
            <div class="flex-shrink-0 mt-0.5">
              <span class="${typeColor} text-lg">${typeIcon}</span>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 mb-1">
                <span class="font-medium text-gray-900">${this.escapeHtml(step.title)}</span>
                <span class="text-xs px-2 py-0.5 rounded ${this.getTypeBadgeColor(step.type)}">${this.escapeHtml(step.type)}</span>
              </div>
              ${step.preview ? `<p class="text-xs text-gray-600 truncate">${this.escapeHtml(step.preview)}</p>` : ''}
            </div>
            ${isSelected ? '<span class="text-blue-600">✓</span>' : ''}
          </div>
        </button>
      `
    }).join('')
    
    this.optionsTarget.innerHTML = optionsHtml
  }

  getTypeIcon(type) {
    const icons = {
      question: "❓",
      decision: "🔀",
      action: "⚡",
      checkpoint: "✓"
    }
    return icons[type] || "📋"
  }

  getTypeColor(type) {
    const colors = {
      question: "text-blue-600",
      decision: "text-green-600",
      action: "text-purple-600",
      checkpoint: "text-yellow-600"
    }
    return colors[type] || "text-gray-600"
  }

  getTypeBadgeColor(type) {
    const colors = {
      question: "bg-blue-100 text-blue-700",
      decision: "bg-green-100 text-green-700",
      action: "bg-purple-100 text-purple-700",
      checkpoint: "bg-yellow-100 text-yellow-700"
    }
    return colors[type] || "bg-gray-100 text-gray-700"
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // Public method to refresh steps (called by parent controllers)
  refresh() {
    this.loadSteps()
    this.render()
  }
}

