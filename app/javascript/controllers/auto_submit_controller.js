import { Controller } from "@hotwired/stimulus"

// Auto-submits a form when a select element changes
// Usage: data-controller="auto-submit" on the form
//        data-action="change->auto-submit#submit" on the select
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
