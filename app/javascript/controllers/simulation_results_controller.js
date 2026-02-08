import { Controller } from "@hotwired/stimulus"

// Handles expand/collapse of individual execution path items on the simulation results page.
//
// Usage:
//   <div data-controller="simulation-results">
//     <button data-action="click->simulation-results#expandAll">Expand All</button>
//     <button data-action="click->simulation-results#collapseAll">Collapse All</button>
//     <div data-simulation-results-target="item">
//       <button data-action="click->simulation-results#toggle">
//         <svg data-simulation-results-target="toggleIcon">...</svg>
//       </button>
//       <div data-simulation-results-target="details" class="hidden">...</div>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["details", "toggleIcon", "item"]

  toggle(event) {
    const item = event.currentTarget.closest("[data-simulation-results-target='item']")
    if (!item) return

    const index = this.itemTargets.indexOf(item)
    if (index === -1) return

    const details = this.detailsTargets[index]
    const icon = this.toggleIconTargets[index]
    if (!details) return

    const isHidden = details.classList.contains("hidden")
    details.classList.toggle("hidden")

    if (icon) {
      icon.style.transform = isHidden ? "rotate(90deg)" : ""
    }

    // Update aria-expanded on the toggle button
    event.currentTarget.setAttribute("aria-expanded", isHidden ? "true" : "false")
  }

  expandAll() {
    this.detailsTargets.forEach((details, index) => {
      details.classList.remove("hidden")
      const icon = this.toggleIconTargets[index]
      if (icon) icon.style.transform = "rotate(90deg)"
    })

    this.element.querySelectorAll("[aria-expanded]").forEach(el => {
      el.setAttribute("aria-expanded", "true")
    })
  }

  collapseAll() {
    this.detailsTargets.forEach((details, index) => {
      details.classList.add("hidden")
      const icon = this.toggleIconTargets[index]
      if (icon) icon.style.transform = ""
    })

    this.element.querySelectorAll("[aria-expanded]").forEach(el => {
      el.setAttribute("aria-expanded", "false")
    })
  }
}
