import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 }
  }

  connect() {
    this.dismissTimer = setTimeout(() => {
      this.fadeOut()
    }, this.durationValue)
  }

  disconnect() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }
  }

  dismiss() {
    if (this.dismissTimer) {
      clearTimeout(this.dismissTimer)
    }
    this.fadeOut()
  }

  fadeOut() {
    const animation = this.element.animate(
      [
        { opacity: 1, transform: "translateY(0)" },
        { opacity: 0, transform: "translateY(-10px)" }
      ],
      { duration: 400, easing: "ease-in", fill: "forwards" }
    )
    animation.onfinish = () => this.element.remove()
  }
}
