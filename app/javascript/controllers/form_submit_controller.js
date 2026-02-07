import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submit() {
    this.submitTarget.disabled = true
    this.submitTarget.value = "Starting..."
    this.submitTarget.classList.add("opacity-75", "cursor-wait")
  }
}
