import { Controller } from "@hotwired/stimulus"

// Filters admin/_group_picker by any part of each group's full path.
// data-path is lowercased server-side, so this only lowercases the term.
export default class extends Controller {
  static targets = ["filter", "option", "empty"]

  filter() {
    const term = this.filterTarget.value.trim().toLowerCase()
    let shown = 0

    this.optionTargets.forEach(option => {
      const match = term === "" || option.dataset.path.includes(term)
      option.classList.toggle("is-hidden", !match)
      if (match) shown++
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("is-hidden", shown > 0)
  }

  // Enter in the filter must not submit the form the picker sits in.
  ignoreEnter(event) {
    event.preventDefault()
  }
}
