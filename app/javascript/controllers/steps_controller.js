import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step"]

  addStep(event) {
    event.preventDefault()
    const stepType = event.params.type || "action"
    const stepIndex = this.stepTargets.length
    
    const stepHtml = `
      <div class="step-item" data-step-target="step" data-step-index="${stepIndex}">
        <div class="step-item__header">
          <span class="drag-handle">☰</span>
          <button type="button" data-action="click->steps#removeStep" class="btn btn--negative btn--sm">Remove</button>
        </div>
        <input type="hidden" name="workflow[steps][][index]" value="${stepIndex}">
        <input type="hidden" name="workflow[steps][][type]" value="${stepType}">
        <div class="form-stack">
          <input type="text" name="workflow[steps][][title]" placeholder="Step title" class="form-input" required>
          <textarea name="workflow[steps][][description]" placeholder="Step description" class="form-textarea" rows="2"></textarea>
        </div>
      </div>
    `
    
    this.element.insertAdjacentHTML("beforeend", stepHtml)
    this.updateIndices()
  }

  removeStep(event) {
    event.preventDefault()
    const stepElement = event.target.closest("[data-step-target='step']")
    if (stepElement) {
      stepElement.remove()
      this.updateIndices()
    }
  }

  updateIndices() {
    this.stepTargets.forEach((step, index) => {
      const indexInput = step.querySelector("[name*='[index]']")
      if (indexInput) {
        indexInput.value = index
      }
    })
  }
}

