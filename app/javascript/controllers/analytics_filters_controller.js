import { Controller } from "@hotwired/stimulus"

// Handles analytics filter form: toggle buttons update hidden fields then submit.
export default class extends Controller {
  static targets = ["rangeField", "purposeField", "tabField"]

  selectRange(event) {
    this.rangeFieldTarget.value = event.currentTarget.dataset.value
    this.element.requestSubmit()
  }

  selectPurpose(event) {
    this.purposeFieldTarget.value = event.currentTarget.dataset.value
    this.element.requestSubmit()
  }

  updateTab(index) {
    this.tabFieldTarget.value = index
  }
}
