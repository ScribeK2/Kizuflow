import { Controller } from "@hotwired/stimulus"
import { buildDepthMap, findOrphans } from "services/graph_utils"

// Status bar showing workflow health metrics for graph-mode workflows.
// Displays step count, orphan count, terminal count, and cycle warnings.
export default class extends Controller {
  static targets = ["content"]
  static values = {
    startUuid: String
  }

  connect() {
    this.update()
    this.boundUpdate = this.debounce(() => this.update(), 500)
    document.addEventListener("workflow:updated", this.boundUpdate)
    document.addEventListener("workflow-steps-changed", this.boundUpdate)

    // Also listen for form changes
    const form = document.querySelector("form")
    if (form) {
      this.form = form
      this.boundFormUpdate = this.debounce(() => this.update(), 800)
      form.addEventListener("input", this.boundFormUpdate)
      form.addEventListener("change", this.boundFormUpdate)
    }
  }

  disconnect() {
    document.removeEventListener("workflow:updated", this.boundUpdate)
    document.removeEventListener("workflow-steps-changed", this.boundUpdate)
    if (this.form) {
      this.form.removeEventListener("input", this.boundFormUpdate)
      this.form.removeEventListener("change", this.boundFormUpdate)
    }
  }

  update() {
    if (!this.hasContentTarget) return

    const steps = this.parseSteps()
    const container = this.contentTarget

    // Clear existing content
    while (container.firstChild) container.removeChild(container.firstChild)

    if (steps.length === 0) {
      container.appendChild(this.createItem("No steps"))
      return
    }

    const orphans = findOrphans(steps, this.startUuidValue)
    const terminalCount = steps.filter(s => !s.transitions || s.transitions.length === 0).length
    const depthMap = buildDepthMap(steps, this.startUuidValue)
    const reachable = depthMap.size

    // Step count
    container.appendChild(this.createItem(`${steps.length} step${steps.length !== 1 ? "s" : ""}`))

    // Orphan count
    if (orphans.size > 0) {
      container.appendChild(this.createSep())
      container.appendChild(this.createItem(
        `${orphans.size} orphan${orphans.size !== 1 ? "s" : ""}`,
        "wf-status-bar__item--warning"
      ))
    }

    // Terminal count
    container.appendChild(this.createSep())
    container.appendChild(this.createItem(`${terminalCount} terminal`))

    // Reachable count
    container.appendChild(this.createSep())
    if (reachable < steps.length) {
      container.appendChild(this.createItem(
        `${reachable}/${steps.length} reachable`,
        "wf-status-bar__item--warning"
      ))
    } else {
      container.appendChild(this.createItem("All reachable", "wf-status-bar__item--ok"))
    }
  }

  createItem(text, modifier) {
    const span = document.createElement("span")
    span.className = "wf-status-bar__item"
    if (modifier) span.classList.add(modifier)
    span.textContent = text
    return span
  }

  createSep() {
    const span = document.createElement("span")
    span.className = "wf-status-bar__sep"
    span.textContent = "\u00b7"
    return span
  }

  parseSteps() {
    const stepItems = document.querySelectorAll(".step-item")
    const steps = []

    stepItems.forEach(item => {
      const idInput = item.querySelector("input[name*='[id]']")
      const transitionsInput = item.querySelector("input[name*='transitions_json']")

      let transitions = []
      if (transitionsInput?.value) {
        try { transitions = JSON.parse(transitionsInput.value) } catch (e) { /* ignore */ }
      }

      steps.push({
        id: idInput?.value || "",
        transitions
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
