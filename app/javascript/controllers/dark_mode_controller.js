import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dark-mode"
export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    this.initializeTheme()
  }

  initializeTheme() {
    const savedTheme = localStorage.getItem("theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches

    if (savedTheme === "dark" || (!savedTheme && prefersDark)) {
      document.documentElement.classList.add("dark")
      this.updateIcons(true)
    } else {
      document.documentElement.classList.remove("dark")
      this.updateIcons(false)
    }
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Suppress all CSS transitions for an instant theme switch
    this.disableTransitions()

    if (document.documentElement.classList.contains("dark")) {
      this.enableLightMode()
    } else {
      this.enableDarkMode()
    }

    // Re-enable transitions after the browser has painted the new theme
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.enableTransitions()
      })
    })
  }

  enableDarkMode() {
    document.documentElement.classList.add("dark")
    localStorage.setItem("theme", "dark")
    this.updateIcons(true)
  }

  enableLightMode() {
    document.documentElement.classList.remove("dark")
    localStorage.setItem("theme", "light")
    this.updateIcons(false)
  }

  updateIcons(isDark) {
    if (this.hasSunIconTarget && this.hasMoonIconTarget) {
      if (isDark) {
        this.sunIconTarget.classList.remove("hidden")
        this.moonIconTarget.classList.add("hidden")
      } else {
        this.sunIconTarget.classList.add("hidden")
        this.moonIconTarget.classList.remove("hidden")
      }
    }
  }

  disableTransitions() {
    if (!this.styleTag) {
      this.styleTag = document.createElement("style")
      this.styleTag.textContent = "*, *::before, *::after { transition: none !important; }"
    }
    document.head.appendChild(this.styleTag)
  }

  enableTransitions() {
    if (this.styleTag && this.styleTag.parentNode) {
      this.styleTag.parentNode.removeChild(this.styleTag)
    }
  }
}
