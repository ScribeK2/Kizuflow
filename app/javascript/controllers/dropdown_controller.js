import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    // Trigger animation: remove scale-95/opacity-0, add scale-100/opacity-100
    requestAnimationFrame(() => {
      this.menuTarget.classList.remove("opacity-0", "scale-95")
      this.menuTarget.classList.add("opacity-100", "scale-100")
    })
    // Update aria
    this.element.querySelector("[aria-expanded]").setAttribute("aria-expanded", "true")
    // Listen for outside clicks and escape
    document.addEventListener("click", this.closeOnOutsideClick)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  close() {
    this.menuTarget.classList.remove("opacity-100", "scale-100")
    this.menuTarget.classList.add("opacity-0", "scale-95")
    // Wait for animation to finish before hiding
    setTimeout(() => {
      this.menuTarget.classList.add("hidden")
    }, 150)
    // Update aria
    this.element.querySelector("[aria-expanded]").setAttribute("aria-expanded", "false")
    // Remove listeners
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }
}
