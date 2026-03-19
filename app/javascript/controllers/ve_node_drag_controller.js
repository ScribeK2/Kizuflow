import { Controller } from "@hotwired/stimulus"

// Handles node dragging in the visual editor.
// Reads zoom level from canvas-zoom controller for coordinate compensation.
// Snaps to 20px grid on release. Dispatches visual-editor:node-moved on dragend.
export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    this.isDragging = false
    this.dragNode = null
    this.dragStepId = null
    this.startMouseX = 0
    this.startMouseY = 0
    this.startNodeX = 0
    this.startNodeY = 0
    this.dragThreshold = 5
    this.gridSize = 20
    this.zoomLevel = 1.0
    this.didDrag = false

    this.boundUpdateZoom = () => this.readZoomLevel()
    this.element.addEventListener("visual-editor:rendered", this.boundUpdateZoom)
  }

  disconnect() {
    this.element.removeEventListener("visual-editor:rendered", this.boundUpdateZoom)
  }

  readZoomLevel() {
    const zoomEl = this.element.querySelector("[data-canvas-zoom-target='zoomLevel']")
    if (zoomEl) {
      this.zoomLevel = parseInt(zoomEl.textContent, 10) / 100 || 1.0
    }
  }

  handleCanvasMouseDown(e) {
    // Only start drag on workflow-node (not ports)
    if (e.target.closest(".output-port") || e.target.closest(".input-port")) return
    // Skip if alt-panning or middle-click
    if (e.altKey || e.button === 1) return

    const node = e.target.closest(".workflow-node")
    if (!node) return

    const stepId = node.dataset.stepId
    if (!stepId) return

    this.isDragging = false
    this.didDrag = false
    this.dragNode = node
    this.dragStepId = stepId
    this.startMouseX = e.clientX
    this.startMouseY = e.clientY
    this.startNodeX = parseFloat(node.style.left) || 0
    this.startNodeY = parseFloat(node.style.top) || 0
  }

  handleCanvasMouseMove(e) {
    if (!this.dragNode) return

    const dx = (e.clientX - this.startMouseX) / this.zoomLevel
    const dy = (e.clientY - this.startMouseY) / this.zoomLevel

    // Check threshold before starting drag
    if (!this.isDragging) {
      if (Math.abs(dx) < this.dragThreshold && Math.abs(dy) < this.dragThreshold) return
      this.isDragging = true
      this.didDrag = true
      this.dragNode.classList.add("is-dragging-node")
    }

    const newX = this.startNodeX + dx
    const newY = this.startNodeY + dy
    this.dragNode.style.left = `${newX}px`
    this.dragNode.style.top = `${newY}px`
  }

  handleCanvasMouseUp(e) {
    if (!this.dragNode) return

    if (this.isDragging) {
      // Snap to grid
      const rawX = parseFloat(this.dragNode.style.left) || 0
      const rawY = parseFloat(this.dragNode.style.top) || 0
      const snappedX = Math.round(rawX / this.gridSize) * this.gridSize
      const snappedY = Math.round(rawY / this.gridSize) * this.gridSize

      this.dragNode.style.left = `${snappedX}px`
      this.dragNode.style.top = `${snappedY}px`
      this.dragNode.classList.remove("is-dragging-node")

      this.element.dispatchEvent(new CustomEvent("visual-editor:node-moved", {
        bubbles: false,
        detail: { stepId: this.dragStepId, x: snappedX, y: snappedY }
      }))
    }

    this.isDragging = false
    this.dragNode = null
    this.dragStepId = null
  }

  // Expose whether a drag just occurred (for click suppression)
  get dragged() {
    return this.didDrag
  }

  resetDragFlag() {
    this.didDrag = false
  }
}
