import { Controller } from "@hotwired/stimulus"
import { buildDepthMap } from "services/graph_utils"

/**
 * Step Tree Controller
 *
 * Applies tree/outline indentation to step items in the list view
 * for graph-mode workflows. Computes BFS depth from the start node
 * and adds CSS classes for visual indentation.
 */
export default class extends Controller {
  static values = {
    startUuid: String,
    graphMode: { type: Boolean, default: false }
  }

  connect() {
    if (!this.graphModeValue) return
    this.applyTreeIndentation()
    this.boundUpdate = this.debounce(() => this.applyTreeIndentation(), 300)
    document.addEventListener("workflow:updated", this.boundUpdate)
    document.addEventListener("workflow-steps-changed", this.boundUpdate)
  }

  disconnect() {
    if (this.boundUpdate) {
      document.removeEventListener("workflow:updated", this.boundUpdate)
      document.removeEventListener("workflow-steps-changed", this.boundUpdate)
    }
  }

  applyTreeIndentation() {
    if (!this.graphModeValue) return

    const stepItems = this.element.querySelectorAll(".step-item")
    const steps = this.parseStepsFromDOM(stepItems)
    const depthMap = buildDepthMap(steps, this.startUuidValue)

    stepItems.forEach(item => {
      const idInput = item.querySelector("input[name*='[id]']")
      const stepId = idInput?.value

      // Remove existing depth classes
      for (let i = 0; i <= 5; i++) {
        item.classList.remove(`step-item--depth-${i}`)
      }

      if (stepId && depthMap.has(stepId)) {
        const depth = Math.min(depthMap.get(stepId), 5)
        if (depth > 0) {
          item.classList.add(`step-item--depth-${depth}`)
        }
      }
    })
  }

  parseStepsFromDOM(stepItems) {
    const steps = []
    stepItems.forEach(item => {
      const idInput = item.querySelector("input[name*='[id]']")
      const transitionsInput = item.querySelector("input[name*='transitions_json']")

      let transitions = []
      if (transitionsInput?.value) {
        try { transitions = JSON.parse(transitionsInput.value) } catch (e) { /* ignore */ }
      }

      steps.push({
        id: idInput?.value || '',
        transitions: transitions
      })
    })
    return steps
  }

  debounce(fn, delay) {
    let timer
    return (...args) => {
      clearTimeout(timer)
      timer = setTimeout(() => fn.apply(this, args), delay)
    }
  }
}
