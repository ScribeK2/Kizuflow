import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dark-mode"
export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    console.log("[DarkMode] Controller connected")
    console.log("[DarkMode] Sun icon target:", this.hasSunIconTarget ? "found" : "missing")
    console.log("[DarkMode] Moon icon target:", this.hasMoonIconTarget ? "found" : "missing")
    // Initialize theme immediately on page load to prevent flash
    this.initializeTheme()
  }

  initializeTheme() {
    // Check for saved theme preference or default to light mode
    const savedTheme = localStorage.getItem("theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    
    console.log("[DarkMode] Initializing theme:")
    console.log("  - Saved theme:", savedTheme)
    console.log("  - Prefers dark:", prefersDark)
    console.log("  - Current HTML class:", document.documentElement.classList.toString())
    
    if (savedTheme === "dark" || (!savedTheme && prefersDark)) {
      document.documentElement.classList.add("dark")
      this.updateIcons(true)
      console.log("[DarkMode] Enabled dark mode")
    } else {
      document.documentElement.classList.remove("dark")
      this.updateIcons(false)
      console.log("[DarkMode] Enabled light mode")
    }
  }

  toggle(event) {
    console.log("[DarkMode] Toggle clicked")
    console.log("  - Event:", event)
    console.log("  - Current HTML class:", document.documentElement.classList.toString())
    console.log("  - Has dark class:", document.documentElement.classList.contains("dark"))
    
    event.preventDefault()
    event.stopPropagation()
    
    if (document.documentElement.classList.contains("dark")) {
      console.log("[DarkMode] Switching to light mode")
      this.enableLightMode()
    } else {
      console.log("[DarkMode] Switching to dark mode")
      this.enableDarkMode()
    }
    
    console.log("[DarkMode] After toggle - HTML class:", document.documentElement.classList.toString())
  }

  enableDarkMode() {
    console.log("[DarkMode] Enabling dark mode")
    document.documentElement.classList.add("dark")
    localStorage.setItem("theme", "dark")
    this.updateIcons(true)
    console.log("[DarkMode] Dark mode enabled. HTML class:", document.documentElement.classList.toString())
  }

  enableLightMode() {
    console.log("[DarkMode] Enabling light mode")
    document.documentElement.classList.remove("dark")
    localStorage.setItem("theme", "light")
    this.updateIcons(false)
    console.log("[DarkMode] Light mode enabled. HTML class:", document.documentElement.classList.toString())
  }

  updateIcons(isDark) {
    console.log("[DarkMode] Updating icons. isDark:", isDark)
    console.log("  - Has sun icon target:", this.hasSunIconTarget)
    console.log("  - Has moon icon target:", this.hasMoonIconTarget)
    
    if (this.hasSunIconTarget && this.hasMoonIconTarget) {
      // When in dark mode, show sun icon (to switch to light)
      // When in light mode, show moon icon (to switch to dark)
      if (isDark) {
        this.sunIconTarget.classList.remove("hidden")
        this.moonIconTarget.classList.add("hidden")
        console.log("[DarkMode] Showing sun icon, hiding moon icon")
      } else {
        this.sunIconTarget.classList.add("hidden")
        this.moonIconTarget.classList.remove("hidden")
        console.log("[DarkMode] Showing moon icon, hiding sun icon")
      }
    } else {
      console.warn("[DarkMode] Icon targets not found!")
    }
  }
}

