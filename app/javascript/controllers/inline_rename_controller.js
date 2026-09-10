import { Controller } from "@hotwired/stimulus"

// Renames in place (admin/groups/_folders). Enter or leaving the field saves,
// Escape puts the name back. Enter is handled here rather than left to the
// form: a one-field form also submits natively on Enter, and the blur that
// follows would then save the same edit a second time.
export default class extends Controller {
  static targets = ["input"]

  commit(event) {
    const input = this.inputTarget
    if (event.type === "keydown") event.preventDefault()

    const value = input.value.trim()
    if (value === "" || value === input.defaultValue) {
      input.value = input.defaultValue
    } else {
      // The saved name becomes the baseline first, so the blur below is a no-op.
      input.defaultValue = value
      input.value = value
      this.element.requestSubmit()
    }

    if (event.type === "keydown") input.blur()
  }

  revert() {
    this.inputTarget.value = this.inputTarget.defaultValue
    this.inputTarget.blur()
  }
}
