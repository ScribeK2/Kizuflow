import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="password-toggle"
export default class extends Controller {
  static targets = ["input", "showIcon", "hideIcon"]

  toggle() {
    if (this.inputTarget.type === "password") {
      this.inputTarget.type = "text"
      this.showIconTarget.classList.add("is-hidden")
      this.hideIconTarget.classList.remove("is-hidden")
    } else {
      this.inputTarget.type = "password"
      this.showIconTarget.classList.remove("is-hidden")
      this.hideIconTarget.classList.add("is-hidden")
    }
  }
}
