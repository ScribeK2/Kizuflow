import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "bulkToggleBtn", "selectAll", "userCheckbox", "selectedCount",
    "bulkModal", "bulkForm", "resetModal", "resetEmail",
    "tempPasswordDisplay", "copyBtn", "doneBtn", "closeResetBtn"
  ]

  connect() {
    this.bulkMode = false
    this.currentTempPassword = ""
  }

  // --- Bulk Mode ---

  toggleBulk() {
    if (this.bulkMode && this.selectedUserIds.length > 0) {
      this.openBulkModal()
      return
    }

    this.bulkMode = !this.bulkMode
    const columns = this.element.querySelectorAll(".bulk-select-column")
    columns.forEach(col => {
      col.style.display = this.bulkMode ? "table-cell" : "none"
    })

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
    if (!this.hasSelectedCountTarget) return
    const count = this.selectedUserIds.length
    this.selectedCountTarget.textContent = count > 0
      ? `${count} user${count > 1 ? "s" : ""} selected`
      : "No users selected"
  }

  get selectedUserIds() {
    return this.userCheckboxTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  openBulkModal() {
    const form = this.bulkFormTarget
    form.querySelectorAll('input[name="user_ids[]"]').forEach(input => input.remove())
    this.selectedUserIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "user_ids[]"
      input.value = id
      form.appendChild(input)
    })
    this.bulkModalTarget.classList.remove("is-hidden")
  }

  closeBulkModal() {
    this.bulkModalTarget.classList.add("is-hidden")
  }

  // --- Group Modals ---

  openGroupModal(event) {
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)
    if (modal) modal.classList.remove("is-hidden")
  }

  closeGroupModal(event) {
    const modalId = event.currentTarget.dataset.modalId
    const modal = document.getElementById(modalId)
    if (modal) modal.classList.add("is-hidden")
  }

  // --- Password Reset ---

  async resetPassword(event) {
    const btn = event.currentTarget
    const userId = btn.dataset.userId
    const userEmail = btn.dataset.userEmail

    if (!confirm(`Are you sure you want to generate a temporary password for ${userEmail}? They will be able to log in immediately with this password.`)) {
      return
    }

    // Store original button content safely
    const originalBtnChildren = Array.from(btn.childNodes).map(n => n.cloneNode(true))
    btn.disabled = true
    btn.textContent = "Generating..."

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      if (!csrfToken) throw new Error("CSRF token not found. Please refresh the page.")

      const response = await fetch(`/admin/users/${userId}/reset_password`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        credentials: "same-origin"
      })

      const data = await response.json()
      if (!response.ok) throw new Error(data.error || `Server error: ${response.status}`)

      if (data?.success && data.password) {
        this.currentTempPassword = data.password
        this.resetEmailTarget.textContent = data.email || userEmail
        this.tempPasswordDisplayTarget.textContent = data.password
        this.resetModalTarget.classList.remove("is-hidden")
      } else {
        alert("Failed to generate temporary password. Please try again.")
      }
    } catch (error) {
      console.error("Password reset error:", error)
      alert("An error occurred while generating the temporary password. Please try again.")
    } finally {
      btn.disabled = false
      btn.textContent = ""
      originalBtnChildren.forEach(child => btn.appendChild(child))
    }
  }

  copyPassword(event) {
    const btn = event.currentTarget
    if (!this.currentTempPassword) return

    navigator.clipboard.writeText(this.currentTempPassword).then(() => {
      const originalText = btn.textContent
      btn.textContent = "Copied!"
      setTimeout(() => { btn.textContent = originalText }, 2000)
    }).catch(() => {
      alert("Failed to copy password. Please copy it manually.")
    })
  }

  closeResetModal() {
    this.resetModalTarget.classList.add("is-hidden")
  }
}
