import { Controller } from "@hotwired/stimulus"

// Mini-map controller for the visual editor.
// Renders a small SVG overview of all node positions.
// Shows a viewport rectangle for the currently visible area.
// Click on the mini-map to navigate the canvas scroll position.
//
// XSS Safety: All SVG content is built using safe DOM methods
// (createElementNS, setAttribute). No innerHTML with user data.
export default class extends Controller {
  static targets = ["minimap", "canvas"]

  connect() {
    this.scale = 0.08
    this.minimapWidth = 160
    this.minimapHeight = 112

    this.boundRender = () => this.renderMinimap()
    this.boundScroll = () => this.updateViewport()

    this.element.addEventListener("visual-editor:rendered", this.boundRender)
  }

  disconnect() {
    this.element.removeEventListener("visual-editor:rendered", this.boundRender)
    if (this._canvasEl) {
      this._canvasEl.removeEventListener("scroll", this.boundScroll)
    }
  }

  renderMinimap() {
    if (!this.hasMinimapTarget) return

    const canvasContent = this.element.querySelector("[data-visual-editor-target='canvasContent']")
    const canvasEl = this.element.querySelector("[data-visual-editor-target='canvas']")
    if (!canvasContent || !canvasEl) return

    // Attach scroll listener if not already
    if (this._canvasEl !== canvasEl) {
      if (this._canvasEl) this._canvasEl.removeEventListener("scroll", this.boundScroll)
      canvasEl.addEventListener("scroll", this.boundScroll)
      this._canvasEl = canvasEl
    }

    const nodes = canvasContent.querySelectorAll(".workflow-node")
    if (nodes.length === 0) {
      this.minimapTarget.classList.add("is-hidden")
      return
    }
    this.minimapTarget.classList.remove("is-hidden")

    // Collect node positions and find bounds
    const rects = []
    let maxX = 0, maxY = 0
    nodes.forEach(node => {
      const x = parseFloat(node.style.left) || 0
      const y = parseFloat(node.style.top) || 0
      const w = node.offsetWidth || 200
      const h = node.offsetHeight || 120
      rects.push({ x, y, w, h, type: node.dataset.stepType || "action" })
      if (x + w > maxX) maxX = x + w
      if (y + h > maxY) maxY = y + h
    })

    // Calculate scale to fit into minimap
    const padding = 20
    maxX += padding
    maxY += padding
    this.contentWidth = maxX
    this.contentHeight = maxY
    const scaleX = this.minimapWidth / maxX
    const scaleY = this.minimapHeight / maxY
    this.scale = Math.min(scaleX, scaleY, 0.12)

    const svgW = maxX * this.scale
    const svgH = maxY * this.scale

    // Build SVG using safe DOM methods
    const svgContainer = this.minimapTarget.querySelector(".minimap-svg")
    svgContainer.replaceChildren()

    const NS = "http://www.w3.org/2000/svg"
    const svg = document.createElementNS(NS, "svg")
    svg.setAttribute("width", svgW)
    svg.setAttribute("height", svgH)
    svg.setAttribute("viewBox", `0 0 ${svgW} ${svgH}`)

    // Node rectangles
    const colors = {
      question: "#6366f1", action: "#10b981", sub_flow: "#8b5cf6",
      message: "#06b6d4", escalate: "#f97316", resolve: "#22c55e"
    }
    rects.forEach(r => {
      const rect = document.createElementNS(NS, "rect")
      rect.setAttribute("x", r.x * this.scale)
      rect.setAttribute("y", r.y * this.scale)
      rect.setAttribute("width", r.w * this.scale)
      rect.setAttribute("height", r.h * this.scale)
      rect.setAttribute("rx", "2")
      rect.setAttribute("fill", colors[r.type] || "#6b7280")
      rect.setAttribute("opacity", "0.7")
      svg.appendChild(rect)
    })

    // Viewport rectangle
    const vRect = document.createElementNS(NS, "rect")
    vRect.classList.add("minimap-viewport")
    vRect.setAttribute("x", canvasEl.scrollLeft * this.scale)
    vRect.setAttribute("y", canvasEl.scrollTop * this.scale)
    vRect.setAttribute("width", canvasEl.clientWidth * this.scale)
    vRect.setAttribute("height", canvasEl.clientHeight * this.scale)
    vRect.setAttribute("fill", "none")
    vRect.setAttribute("stroke", "currentColor")
    vRect.setAttribute("stroke-width", "1.5")
    vRect.setAttribute("opacity", "0.5")
    vRect.setAttribute("rx", "1")
    svg.appendChild(vRect)

    svgContainer.appendChild(svg)
  }

  updateViewport() {
    if (!this.hasMinimapTarget || !this._canvasEl) return

    const viewport = this.minimapTarget.querySelector(".minimap-viewport")
    if (!viewport) return

    viewport.setAttribute("x", this._canvasEl.scrollLeft * this.scale)
    viewport.setAttribute("y", this._canvasEl.scrollTop * this.scale)
    viewport.setAttribute("width", this._canvasEl.clientWidth * this.scale)
    viewport.setAttribute("height", this._canvasEl.clientHeight * this.scale)
  }

  handleMinimapClick(e) {
    if (!this._canvasEl || !this.hasMinimapTarget) return

    const svgEl = this.minimapTarget.querySelector(".minimap-svg")
    if (!svgEl) return
    const rect = svgEl.getBoundingClientRect()
    const clickX = (e.clientX - rect.left) / this.scale
    const clickY = (e.clientY - rect.top) / this.scale

    // Center viewport on click point
    this._canvasEl.scrollLeft = clickX - this._canvasEl.clientWidth / 2
    this._canvasEl.scrollTop = clickY - this._canvasEl.clientHeight / 2
  }
}
