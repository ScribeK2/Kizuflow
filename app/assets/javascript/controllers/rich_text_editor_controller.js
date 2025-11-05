import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Ensure Trix editor is properly initialized
    // Listen for Trix changes to trigger preview updates
    this.element.addEventListener("trix-change", () => {
      this.dispatch("changed", { detail: { content: this.element.value } })
    })
    
    // Also trigger on input for compatibility with preview updater
    this.element.addEventListener("trix-input", () => {
      // Dispatch event that preview-updater can listen to
      const event = new CustomEvent("input", { bubbles: true })
      this.element.dispatchEvent(event)
    })
  }
  
  disconnect() {
    // Cleanup if needed
  }
}

