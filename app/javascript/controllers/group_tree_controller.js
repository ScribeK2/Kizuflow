import { Controller } from "@hotwired/stimulus"

// The admin groups tree (admin/groups/index). Rows render flat and depth-first,
// each carrying the ids of the groups above it, so showing and hiding is a set
// lookup rather than a walk of nested lists. It starts collapsed to the roots
// and remembers nothing between visits (spec Q35).
export default class extends Controller {
  static targets = ["row", "filter", "empty"]

  connect() {
    this.expanded = new Set()
  }

  toggle(event) {
    const id = event.currentTarget.closest("[data-group-tree-target=row]").dataset.id
    if (this.expanded.has(id)) {
      this.expanded.delete(id)
    } else {
      this.expanded.add(id)
    }
    this.render()
  }

  expandAll() {
    this.rowTargets.forEach(row => this.expanded.add(row.dataset.id))
    this.render()
  }

  collapseAll() {
    this.expanded.clear()
    this.render()
  }

  filter() {
    this.render()
  }

  // Enter in the filter must not submit anything or reload the page.
  ignoreEnter(event) {
    event.preventDefault()
  }

  // While filtering, a match at any depth shows with its full path, and the
  // groups above it show too, opened, so it sits where it lives. Clearing the
  // filter keeps what the filter opened: the match stays in view.
  render() {
    const term = this.hasFilterTarget ? this.filterTarget.value.trim().toLowerCase() : ""
    const filtering = term !== ""
    const context = new Set()

    if (filtering) {
      this.rowTargets.forEach(row => {
        if (!row.dataset.path.includes(term)) return
        this.ancestorsOf(row).forEach(id => {
          this.expanded.add(id)
          context.add(id)
        })
      })
    }

    let shown = 0
    this.rowTargets.forEach(row => {
      const match = filtering && row.dataset.path.includes(term)
      const visible = filtering
        ? match || context.has(row.dataset.id)
        : this.ancestorsOf(row).every(id => this.expanded.has(id))

      row.classList.toggle("is-hidden", !visible)
      row.querySelector(".group-tree__path")?.classList.toggle("is-hidden", !match)
      row.querySelector(".group-tree__toggle")?.setAttribute("aria-expanded", this.expanded.has(row.dataset.id))
      if (visible) shown++
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("is-hidden", shown > 0)
  }

  ancestorsOf(row) {
    return row.dataset.ancestors.split(" ").filter(Boolean)
  }
}
