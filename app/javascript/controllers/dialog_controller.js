import { Controller } from "@hotwired/stimulus"

// Simple controller for native <dialog> elements.
// Usage:
//   <div data-controller="dialog">
//     <button data-action="dialog#open">Open</button>
//     <dialog data-dialog-target="dialog">...</dialog>
//   </div>
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    // Close dialog on form submit so it doesn't persist across page loads
    // (bfcache can restore the page with the dialog still in modal state)
    const form = this.dialogTarget.querySelector("form")
    if (form) {
      this.boundCloseOnSubmit = () => this.dialogTarget.close()
      form.addEventListener("submit", this.boundCloseOnSubmit)
    }

    // Also close on pageshow (bfcache restoration)
    this.boundPageShow = (event) => {
      if (event.persisted && this.dialogTarget.open) {
        this.dialogTarget.close()
      }
    }
    window.addEventListener("pageshow", this.boundPageShow)
  }

  disconnect() {
    const form = this.dialogTarget.querySelector("form")
    if (form && this.boundCloseOnSubmit) {
      form.removeEventListener("submit", this.boundCloseOnSubmit)
    }
    if (this.boundPageShow) {
      window.removeEventListener("pageshow", this.boundPageShow)
    }
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
