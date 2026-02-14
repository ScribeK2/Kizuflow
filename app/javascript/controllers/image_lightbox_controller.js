import { Controller } from "@hotwired/stimulus"

// Provides click-to-enlarge functionality for images within step markdown content.
// Attach to any container with data-controller="image-lightbox".
// Automatically finds all img.step-markdown-image elements within and makes them clickable.
export default class extends Controller {
  connect() {
    this.boundHandleClick = this.handleClick.bind(this)
    this.element.addEventListener("click", this.boundHandleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.boundHandleClick)
    this.closeLightbox()
  }

  handleClick(event) {
    const img = event.target.closest("img.step-markdown-image")
    if (!img) return

    event.preventDefault()
    event.stopPropagation()
    this.openLightbox(img.src, img.alt)
  }

  openLightbox(src, alt) {
    // Prevent duplicate overlays
    this.closeLightbox()

    const overlay = document.createElement("div")
    overlay.className = "image-lightbox-overlay"
    overlay.setAttribute("data-lightbox-overlay", "true")

    const closeBtn = document.createElement("button")
    closeBtn.className = "image-lightbox-close"
    closeBtn.textContent = "\u2715"
    closeBtn.setAttribute("aria-label", "Close image viewer")
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation()
      this.closeLightbox()
    })

    const fullImg = document.createElement("img")
    fullImg.src = src
    fullImg.alt = alt || "Full size image"

    overlay.appendChild(closeBtn)
    overlay.appendChild(fullImg)

    // Close on overlay background click
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) {
        this.closeLightbox()
      }
    })

    // Close on Escape
    this.boundEscape = (e) => {
      if (e.key === "Escape") this.closeLightbox()
    }
    document.addEventListener("keydown", this.boundEscape)

    document.body.appendChild(overlay)
    document.body.style.overflow = "hidden"
  }

  closeLightbox() {
    const overlay = document.querySelector("[data-lightbox-overlay]")
    if (overlay) {
      overlay.remove()
      document.body.style.overflow = ""
    }
    if (this.boundEscape) {
      document.removeEventListener("keydown", this.boundEscape)
      this.boundEscape = null
    }
  }
}
