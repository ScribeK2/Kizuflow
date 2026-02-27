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

  switchToList() {
    // Check if visual editor has unsaved changes
    const visualEditor = this.getVisualEditorController()
    if (visualEditor && visualEditor.isDirty()) {
      if (!confirm("You have unsaved changes in the visual editor. Switch to list view anyway?")) {
        return
      }
    }

    // Sync visual editor state back to list form if available
    if (visualEditor) {
      visualEditor.syncToListForm()
    }

    this.modeValue = "list"
    this.applyMode()
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
      this.listContainer.classList.toggle("hidden", !isList)
    }
    if (this.visualContainer) {
      this.visualContainer.classList.toggle("hidden", isList)
    }

    // Update button styling
    if (this.hasListBtnTarget && this.hasVisualBtnTarget) {
      if (isList) {
        this.listBtnTarget.className = "px-4 py-1.5 text-sm font-medium rounded-md transition-colors bg-slate-600 text-white"
        this.visualBtnTarget.className = "px-4 py-1.5 text-sm font-medium rounded-md transition-colors text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
      } else {
        this.listBtnTarget.className = "px-4 py-1.5 text-sm font-medium rounded-md transition-colors text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
        this.visualBtnTarget.className = "px-4 py-1.5 text-sm font-medium rounded-md transition-colors bg-slate-600 text-white"
      }
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
