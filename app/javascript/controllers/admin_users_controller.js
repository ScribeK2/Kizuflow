import { Controller } from "@hotwired/stimulus"

// The users table: bulk mode, selection, and the bulk dialogs. Per-user actions
// (groups, password reset, deactivation) live on the user page.
export default class extends Controller {
  static targets = [
    "bulkToggleBtn", "selectAll", "userCheckbox", "selectedCount",
    "bulkModal", "bulkForm", "bulkBar", "bulkCount", "roleModal", "roleForm",
    "deactivateForm", "table"
  ]

  static values = { totalCount: Number }

  connect() {
    this.bulkMode = false
  }

  // --- Bulk Mode ---

  toggleBulk() {
    if (this.bulkMode && this.selectedUserIds.length > 0) {
      this.openBulkModal()
      return
    }

    this.bulkMode = !this.bulkMode
    // One class; admin.css decides the display value per element type. Setting
    // it here meant the <col> got `table-cell` like its cells, which drops it
    // from the table's column list and shifts every fixed-layout width one
    // column left. See the .bulk-select-column rules in admin.css.
    if (this.hasTableTarget) this.tableTarget.classList.toggle("is-bulk-mode", this.bulkMode)

    if (this.bulkMode) {
      this.bulkToggleBtnTarget.textContent = "Cancel Bulk Mode"
      this.bulkToggleBtnTarget.classList.add("btn--negative")
    } else {
      this.bulkToggleBtnTarget.textContent = "Bulk Assign Groups"
      this.bulkToggleBtnTarget.classList.remove("btn--negative")
      this.userCheckboxTargets.forEach(cb => { cb.checked = false })
      if (this.hasSelectAllTarget) this.selectAllTarget.checked = false
      this.updateSelectedCount()
    }
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.userCheckboxTargets.forEach(cb => { cb.checked = checked })
    this.updateSelectedCount()
  }

  updateSelectedCount() {
    const count = this.selectedUserIds.length
    const label = count > 0 ? `${count} user${count > 1 ? "s" : ""} selected` : "No users selected"

    if (this.hasSelectedCountTarget) this.selectedCountTarget.textContent = label

    if (this.hasBulkBarTarget) {
      this.bulkBarTarget.classList.toggle("is-hidden", count === 0)
      if (count > 0 && this.hasBulkCountTarget) this.bulkCountTarget.textContent = label
    }
  }

  get selectedUserIds() {
    return this.userCheckboxTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  // --- Inject user_ids[] into a form before submission ---

  _injectUserIds(form) {
    form.querySelectorAll('input[name="user_ids[]"]').forEach(input => input.remove())
    this.selectedUserIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "user_ids[]"
      input.value = id
      form.appendChild(input)
    })
  }

  // --- Bulk dialogs ---

  openBulkModal() {
    this._injectUserIds(this.bulkFormTarget)
    this.bulkModalTarget.classList.remove("is-hidden")
  }

  closeBulkModal() {
    this.bulkModalTarget.classList.add("is-hidden")
  }

  openRoleModal() {
    if (this.selectedUserIds.length === 0) return
    this._injectUserIds(this.roleFormTarget)
    this.roleModalTarget.classList.remove("is-hidden")
  }

  closeRoleModal() {
    this.roleModalTarget.classList.add("is-hidden")
  }

  // --- Bulk Deactivate ---

  bulkDeactivate() {
    const count = this.selectedUserIds.length
    if (count === 0) return

    // Turbo asks, using the app's own dialog. This used to call the browser's
    // confirm() — the only control on this screen that did, and it said "They
    // will not be able to sign in", which was untrue until deactivation stopped
    // expiring after an hour.
    const plural = count === 1 ? "" : "s"
    this.deactivateFormTarget.dataset.turboConfirm =
      `Deactivate ${count} user${plural}? They will not be able to sign in until an administrator reactivates them.`

    this._injectUserIds(this.deactivateFormTarget)
    this.deactivateFormTarget.requestSubmit()
  }
}
