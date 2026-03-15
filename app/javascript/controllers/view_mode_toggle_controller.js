import { Controller } from "@hotwired/stimulus"

// Toggles between List and Visual editor views on step2.
// Manages visibility of #list-editor-container and #visual-editor-container,
// and syncs state between the two editors when switching modes.
export default class extends Controller {
  static targets = ["listBtn", "visualBtn", "modeInput"]
  static values = { mode: { type: String, default: "list" } }

  connect() {
    this.listContainer = document.getElementById("list-editor-container")
    this.visualContainer = document.getElementById("visual-editor-container")
    this.applyMode()
  }

  async switchToList() {
    const visualEditor = this.getVisualEditorController()

    // If visual editor has unsaved changes, save them first via sync_steps API
    if (visualEditor && visualEditor.isDirty()) {
      const shouldSave = confirm("Save visual editor changes before switching to list view?")
      if (shouldSave) {
        await visualEditor.saveToServer()
      }
    }

    // Reload the page in list mode so the list editor has fresh server data.
    // The visual editor saves steps via a separate API (sync_steps), so the
    // list editor DOM is always stale — a reload is the reliable way to sync.
    window.location.reload()
  }

  switchToVisual() {
    this.modeValue = "visual"
    this.applyMode()

    // Load current list form state into visual editor
    const visualEditor = this.getVisualEditorController()
    if (visualEditor) {
      visualEditor.loadFromListForm()
    }
  }

  applyMode() {
    const isList = this.modeValue === "list"

    if (this.listContainer) {
      this.listContainer.classList.toggle("is-hidden", !isList)
    }
    if (this.visualContainer) {
      this.visualContainer.classList.toggle("is-hidden", isList)
    }

    // In visual mode, the list editor's required fields are hidden and can't be
    // focused by the browser — this blocks form submission with validation errors.
    // Disable HTML validation when visual mode is active (visual editor saves via API).
    const form = this.listContainer?.closest("form")
    if (form) {
      if (isList) {
        form.removeAttribute("novalidate")
      } else {
        form.setAttribute("novalidate", "")
      }
    }

    // Update button styling
    if (this.hasListBtnTarget && this.hasVisualBtnTarget) {
      this.listBtnTarget.classList.toggle("is-active", isList)
      this.visualBtnTarget.classList.toggle("is-active", !isList)
    }

    // Update hidden mode input
    if (this.hasModeInputTarget) {
      this.modeInputTarget.value = this.modeValue
    }
  }

  getVisualEditorController() {
    const el = document.getElementById("visual-editor-container")
    if (!el) return null
    return this.application.getControllerForElementAndIdentifier(el, "visual-editor")
  }
}
