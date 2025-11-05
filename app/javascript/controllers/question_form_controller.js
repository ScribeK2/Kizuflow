import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "answerType",
    "hiddenAnswerType",
    "optionsContainer",
    "optionsList"
  ]

  connect() {
    // Set initial state based on checked radio button
    const checked = this.answerTypeTargets.find(radio => radio.checked)
    if (checked) {
      this.handleAnswerTypeChange({ target: checked })
    }
    
    // Initialize Sortable for options list if visible
    if (this.hasOptionsListTarget && !this.optionsListTarget.classList.contains('hidden')) {
      this.initializeSortable()
    }
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  async initializeSortable() {
    if (!this.hasOptionsListTarget) return
    
    try {
      const Sortable = (await import("sortablejs")).default
      
      this.sortable = new Sortable(this.optionsListTarget, {
        handle: '.drag-handle',
        animation: 150,
        ghostClass: 'opacity-50',
        onEnd: () => this.handleReorder()
      })
    } catch (error) {
      console.error("Failed to load Sortable:", error)
    }
  }

  handleReorder() {
    // Trigger input event to update preview
    this.element.dispatchEvent(new CustomEvent('input', { bubbles: true }))
  }

  handleAnswerTypeChange(event) {
    const answerType = event.target.value
    
    // Update hidden input
    if (this.hasHiddenAnswerTypeTarget) {
      this.hiddenAnswerTypeTarget.value = answerType
    }
    
    // Show/hide options container based on answer type
    if (this.hasOptionsContainerTarget) {
      if (answerType === 'multiple_choice' || answerType === 'dropdown') {
        this.optionsContainerTarget.classList.remove('hidden')
        // Initialize Sortable if not already initialized
        if (!this.sortable && this.hasOptionsListTarget) {
          setTimeout(() => this.initializeSortable(), 100)
        }
      } else {
        this.optionsContainerTarget.classList.add('hidden')
        // Destroy Sortable when hidden
        if (this.sortable) {
          this.sortable.destroy()
          this.sortable = null
        }
      }
    }
    
    // Dispatch event for preview updater
    this.element.dispatchEvent(new CustomEvent('answer-type-changed', {
      detail: { answerType },
      bubbles: true
    }))
  }

  addOption(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (!this.hasOptionsListTarget) return
    
    const optionHtml = `
      <div class="flex gap-2 items-center option-item">
        <span class="drag-handle cursor-move text-gray-500 text-lg flex-shrink-0" title="Drag to reorder">☰</span>
        <input type="text" 
               name="workflow[steps][][options][][label]" 
               placeholder="Option label" 
               class="flex-1 border rounded px-2 py-1 text-sm min-w-0"
               data-step-form-target="field">
        <input type="text" 
               name="workflow[steps][][options][][value]" 
               placeholder="Option value" 
               class="flex-1 border rounded px-2 py-1 text-sm min-w-0"
               data-step-form-target="field">
        <button type="button" 
                class="text-red-500 hover:text-red-700 text-sm px-2 flex-shrink-0"
                data-action="click->question-form#removeOption">
          Remove
        </button>
      </div>
    `
    
    this.optionsListTarget.insertAdjacentHTML('beforeend', optionHtml)
    
    // Reinitialize Sortable after adding new element
    if (this.sortable) {
      this.sortable.destroy()
    }
    this.initializeSortable()
  }

  removeOption(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const optionDiv = event.target.closest('.option-item')
    if (optionDiv) {
      optionDiv.remove()
      
      // Reinitialize Sortable after removing element
      if (this.sortable) {
        this.sortable.destroy()
      }
      this.initializeSortable()
    }
  }
}

