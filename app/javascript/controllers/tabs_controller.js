import { Controller } from "@hotwired/stimulus"

// General-purpose tab switching controller.
//
// Usage:
//   <div data-controller="tabs" data-tabs-active-value="0">
//     <button data-tabs-target="tab" data-action="click->tabs#switch">Tab 1</button>
//     <button data-tabs-target="tab" data-action="click->tabs#switch">Tab 2</button>
//     <div data-tabs-target="panel">Panel 1</div>
//     <div data-tabs-target="panel">Panel 2</div>
//   </div>
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: { type: Number, default: 0 } }

  connect() {
    this.showTab(this.activeValue)
  }

  switch(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    if (index === -1) return
    this.activeValue = index
    this.showTab(index)
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("border-slate-600", "text-slate-700", "dark:border-slate-400", "dark:text-slate-200")
        tab.classList.remove("border-transparent", "text-gray-500", "dark:text-gray-400")
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove("border-slate-600", "text-slate-700", "dark:border-slate-400", "dark:text-slate-200")
        tab.classList.add("border-transparent", "text-gray-500", "dark:text-gray-400")
        tab.setAttribute("aria-selected", "false")
      }
    })

    this.panelTargets.forEach((panel, i) => {
      if (i === index) {
        panel.classList.remove("hidden")
      } else {
        panel.classList.add("hidden")
      }
    })
  }
}
