import { Controller } from "@hotwired/stimulus"

// Submits the form it sits on once typing pauses: a search that answers as you
// type without a request per keystroke. A newer frame visit cancels the older
// one, so a slow answer never lands over a newer one.
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
