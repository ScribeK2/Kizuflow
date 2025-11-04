import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    debounceMs: { type: Number, default: 500 }
  }

  connect() {
    // Find the form element
    this.formElement = this.element.tagName === "FORM" ? this.element : this.element.closest("form")
    
    if (!this.formElement) {
      console.error("Search controller: Form element not found")
      return
    }

    // Set up debounced search
    this.debouncedSearch = this.debounce(() => this.submitSearch(), this.debounceMsValue)
    
    // Listen for input changes
    this.inputElement = this.formElement.querySelector('input[name="search"]')
    if (this.inputElement) {
      this.inputHandler = () => {
        this.debouncedSearch()
      }
      this.inputElement.addEventListener("input", this.inputHandler)
    }
  }

  disconnect() {
    // Cleanup
    if (this.inputElement && this.inputHandler) {
      this.inputElement.removeEventListener("input", this.inputHandler)
    }
  }

  submitSearch() {
    // Submit the form normally - Turbo will handle it
    if (this.formElement) {
      this.formElement.requestSubmit()
    }
  }

  debounce(func, delay) {
    let timeout
    return function(...args) {
      const context = this
      clearTimeout(timeout)
      timeout = setTimeout(() => func.apply(context, args), delay)
    }
  }
}

