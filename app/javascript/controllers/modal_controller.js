import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["backdrop", "content"]

  connect() {
    // Close on Escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  show() {
    this.backdropTarget.style.display = "flex"
    document.body.style.overflow = "hidden"
  }

  close() {
    this.backdropTarget.style.display = "none"
    document.body.style.overflow = ""
  }

  toggle() {
    if (this.backdropTarget.style.display === "none" || !this.backdropTarget.style.display) {
      this.show()
    } else {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Stop event propagation when clicking inside modal content
  stop(event) {
    event.stopPropagation()
  }
}
