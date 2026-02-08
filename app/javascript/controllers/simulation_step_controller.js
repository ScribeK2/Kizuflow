import { Controller } from "@hotwired/stimulus"

// Handles simulation step interactivity:
// - Auto-advance on radio selection (yes/no, multiple choice)
// - Auto-focus first input on connect
// - Keyboard shortcuts (Enter = submit, Esc = cancel)
// - Continue button disabled until input provided
// - Spinner + "Processing..." on submit (prevents double-submit)
// - ARIA live region announcements
//
// Usage:
//   data-controller="simulation-step"
//   data-simulation-step-auto-advance-value="true"
//   data-simulation-step-step-info-value="Step 3: Ask customer name"
//   data-simulation-step-cancel-url-value="/workflows/1"
export default class extends Controller {
  static targets = ["form", "submit", "cancel", "input", "announce"]
  static values = {
    autoAdvance: { type: Boolean, default: false },
    stepInfo: { type: String, default: "" },
    cancelUrl: { type: String, default: "" }
  }

  connect() {
    this.autoAdvanceTimer = null
    this.submitted = false

    // Auto-focus first input
    if (this.hasInputTarget) {
      // Use requestAnimationFrame to ensure DOM is ready
      requestAnimationFrame(() => {
        this.inputTarget.focus()
      })
    }

    // ARIA announcement
    if (this.hasAnnounceTarget && this.stepInfoValue) {
      this.announceTarget.textContent = this.stepInfoValue
    }

    // Keyboard shortcuts
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    if (this.autoAdvanceTimer) {
      clearTimeout(this.autoAdvanceTimer)
    }
  }

  handleKeydown(event) {
    // Don't intercept when typing in inputs (except radio/checkbox)
    const tag = event.target.tagName
    const type = event.target.type
    if (tag === "TEXTAREA" || tag === "SELECT") return
    if (tag === "INPUT" && type !== "radio" && type !== "checkbox") return

    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submitForm()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancelSimulation()
    }
  }

  // Called when any input value changes (radio, text, select, textarea)
  inputChanged() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }

    // Auto-advance for radio buttons (yes/no, multiple choice)
    if (this.autoAdvanceValue) {
      if (this.autoAdvanceTimer) {
        clearTimeout(this.autoAdvanceTimer)
      }
      this.autoAdvanceTimer = setTimeout(() => {
        this.submitForm()
      }, 300)
    }
  }

  submitForm() {
    if (this.submitted) return
    if (!this.hasFormTarget) return

    // Check if submit button is disabled (no input yet)
    if (this.hasSubmitTarget && this.submitTarget.disabled) return

    this.submitted = true

    // Show spinner on submit button
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Processing...
      `
      this.submitTarget.classList.add("opacity-75", "cursor-not-allowed")
    }

    this.formTarget.requestSubmit()
  }

  cancelSimulation() {
    if (!this.cancelUrlValue) return

    // Trigger Turbo confirmation if the cancel link has one
    if (this.hasCancelTarget) {
      this.cancelTarget.click()
    } else {
      if (confirm("Are you sure you want to cancel? Your simulation progress will be lost.")) {
        window.location.href = this.cancelUrlValue
      }
    }
  }
}
