import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "input"]
  static classes = ["active", "inactive"]

  select(event) {
    const value = event.currentTarget.dataset.selectionGroupValueParam
    this.inputTarget.value = value

    this.buttonTargets.forEach(btn => {
      const isSelected = btn.dataset.selectionGroupValueParam === value
      this.activeClasses.forEach(cls => btn.classList.toggle(cls, isSelected))
      this.inactiveClasses.forEach(cls => btn.classList.toggle(cls, !isSelected))
    })

    // Trigger change event so autosave picks up the change
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
