import { Controller } from "@hotwired/stimulus"

// Wizard navigation controller
// Handles step navigation and validation for the workflow creation wizard
export default class extends Controller {
  connect() {
    // Controller is connected - can add validation logic here if needed
  }

  // Validate current step before proceeding
  validateStep(event) {
    // Basic validation - can be extended
    const form = event.target.closest('form')
    if (form && !form.checkValidity()) {
      event.preventDefault()
      form.reportValidity()
      return false
    }
    return true
  }

  // Handle step navigation
  navigateToStep(event) {
    const step = event.params.step
    // Navigation is handled by Rails routes, this is just for any client-side logic
  }
}

