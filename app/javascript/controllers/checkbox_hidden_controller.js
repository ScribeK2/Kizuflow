import { Controller } from "@hotwired/stimulus"

// Generic controller for boolean checkboxes inside array-nested forms.
// Solves the Rack duplicate-key bug where hidden+checkbox pairs with
// workflow[steps][][field] syntax create phantom array entries.
//
// Usage:
//   <div data-controller="checkbox-hidden">
//     <input type="hidden" name="workflow[steps][][can_resolve]" value="false"
//            data-checkbox-hidden-target="hidden">
//     <input type="checkbox" data-checkbox-hidden-target="checkbox"
//            data-action="change->checkbox-hidden#toggle">
//   </div>
export default class extends Controller {
  static targets = ["hidden", "checkbox"]

  connect() {
    this.checkboxTarget.checked = this.hiddenTarget.value === "true"
  }

  toggle() {
    this.hiddenTarget.value = this.checkboxTarget.checked ? "true" : "false"
  }
}
