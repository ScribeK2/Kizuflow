import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search"]

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  search() {
    if (this.timeout) clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 300)
  }

  filter() {
    this.element.requestSubmit()
  }
}
