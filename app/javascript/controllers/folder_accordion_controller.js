import { Controller } from "@hotwired/stimulus"

// Handles chevron rotation when <details> opens/closes
// Connects to data-controller="folder-accordion"
export default class extends Controller {
  static targets = ["chevron"]

  toggle(event) {
    const details = event.currentTarget.closest("details")
    // The toggle event fires after the state changes
    const isOpen = details.open
    this.chevronTarget.classList.toggle("rotate-90", isOpen)
  }
}
