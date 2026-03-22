import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String, position: { type: String, default: "top" } }

  connect() {
    this.showDelay = 400
    this.hideDelay = 0
    this.tooltip = null
    this.showTimer = null

    this.element.addEventListener("mouseenter", this.scheduleShow)
    this.element.addEventListener("mouseleave", this.hide)
    this.element.addEventListener("focus", this.scheduleShow)
    this.element.addEventListener("blur", this.hide)
  }

  disconnect() {
    this.hide()
    this.element.removeEventListener("mouseenter", this.scheduleShow)
    this.element.removeEventListener("mouseleave", this.hide)
    this.element.removeEventListener("focus", this.scheduleShow)
    this.element.removeEventListener("blur", this.hide)
  }

  scheduleShow = () => {
    clearTimeout(this.showTimer)
    this.showTimer = setTimeout(() => this.show(), this.showDelay)
  }

  show = () => {
    if (this.tooltip) return

    this.tooltip = document.createElement("div")
    this.tooltip.className = `tooltip${this.positionValue === "bottom" ? " tooltip--bottom" : ""}`
    this.tooltip.textContent = this.textValue
    document.body.appendChild(this.tooltip)

    const rect = this.element.getBoundingClientRect()
    const tipRect = this.tooltip.getBoundingClientRect()

    if (this.positionValue === "bottom") {
      this.tooltip.style.top = `${rect.bottom + 6 + window.scrollY}px`
    } else {
      this.tooltip.style.top = `${rect.top - tipRect.height - 6 + window.scrollY}px`
    }
    this.tooltip.style.left = `${rect.left + (rect.width - tipRect.width) / 2 + window.scrollX}px`

    requestAnimationFrame(() => this.tooltip?.classList.add("is-visible"))
  }

  hide = () => {
    clearTimeout(this.showTimer)
    if (!this.tooltip) return

    this.tooltip.classList.remove("is-visible")
    const tip = this.tooltip
    this.tooltip = null
    setTimeout(() => tip.remove(), 150)
  }
}
