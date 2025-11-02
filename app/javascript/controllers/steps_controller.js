import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step"]

  addStep(event) {
    event.preventDefault()
    const stepType = event.params.type || "action"
    const stepIndex = this.stepTargets.length
    
    const stepHtml = `
      <div class="step-item border rounded p-4 mb-4" data-step-target="step" data-step-index="${stepIndex}">
        <div class="flex items-center justify-between mb-2">
          <span class="drag-handle cursor-move text-gray-500">☰</span>
          <button type="button" data-action="click->steps#removeStep" class="text-red-500 hover:text-red-700">Remove</button>
        </div>
        <input type="hidden" name="workflow[steps][][index]" value="${stepIndex}">
        <input type="hidden" name="workflow[steps][][type]" value="${stepType}">
        <div class="space-y-2">
          <input type="text" name="workflow[steps][][title]" placeholder="Step title" class="w-full border rounded px-3 py-2" required>
          <textarea name="workflow[steps][][description]" placeholder="Step description" class="w-full border rounded px-3 py-2" rows="2"></textarea>
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

