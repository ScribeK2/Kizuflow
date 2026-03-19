import { Controller } from "@hotwired/stimulus"

// Resizable split divider for Split editor mode.
// Allows dragging a divider to resize the list/preview columns.
// Persists ratio to localStorage.
export default class extends Controller {
  static targets = ["divider", "left", "right"]

  connect() {
    this.isDragging = false
    this.savedRatio = parseFloat(localStorage.getItem("turboflows:split-ratio")) || 0.6

    this.boundMouseMove = this.onMouseMove.bind(this)
    this.boundMouseUp = this.onMouseUp.bind(this)

    // Only apply saved ratio if already in split mode
    if (this.isSplitMode()) {
      this.applyRatio(this.savedRatio)
    }

    // Watch for split mode toggling to apply/remove the saved ratio
    this.observer = new MutationObserver(() => {
      if (this.isSplitMode()) {
        this.applyRatio(this.savedRatio)
      } else {
        this.element.style.gridTemplateColumns = ""
      }
    })
    this.observer.observe(this.element, { attributes: true, attributeFilter: ["class"] })
  }

  disconnect() {
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)
    this.observer?.disconnect()
  }

  startDrag(event) {
    if (!this.isSplitMode()) return
    event.preventDefault()
    this.isDragging = true
    document.addEventListener("mousemove", this.boundMouseMove)
    document.addEventListener("mouseup", this.boundMouseUp)
    document.body.style.cursor = "col-resize"
    document.body.style.userSelect = "none"
  }

  onMouseMove(event) {
    if (!this.isDragging) return

    const rect = this.element.getBoundingClientRect()
    const x = event.clientX - rect.left
    let ratio = x / rect.width

    // Clamp between 30% and 70%
    ratio = Math.max(0.3, Math.min(0.7, ratio))
    this.applyRatio(ratio)
  }

  onMouseUp() {
    if (!this.isDragging) return
    this.isDragging = false
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)
    document.body.style.cursor = ""
    document.body.style.userSelect = ""

    localStorage.setItem("turboflows:split-ratio", String(this.savedRatio))
  }

  applyRatio(ratio) {
    this.savedRatio = ratio
    // Use fr units that subtract the divider's auto column
    const left = ratio * 10
    const right = (1 - ratio) * 10
    this.element.style.gridTemplateColumns = `${left.toFixed(2)}fr 8px ${right.toFixed(2)}fr`
  }

  isSplitMode() {
    return this.element.classList.contains("wf-editor-layout--split")
  }
}
