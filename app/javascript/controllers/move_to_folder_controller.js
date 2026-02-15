import { Controller } from "@hotwired/stimulus"

// Submits the parent form when the select value changes
// Used for the "Move to folder" dropdown on workflow cards
export default class extends Controller {
  submit() {
    this.element.closest("form").requestSubmit()
  }
}
