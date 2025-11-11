// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

// Import npm packages directly instead of CDN pins
import Trix from "trix"
import "@rails/actiontext"

// Ensure Trix works properly with Turbo
document.addEventListener("turbo:load", () => {
  // Wait a bit for Trix to fully initialize
  setTimeout(() => {
    const editors = document.querySelectorAll("trix-editor")
    editors.forEach(editor => {
      if (editor.editor) {
        const toolbar = editor.toolbarElement
        if (toolbar) {
          // Ensure editor gets focus when toolbar buttons are clicked
          // This allows commands to execute properly
          toolbar.addEventListener("mousedown", (e) => {
            const button = e.target.closest(".trix-button")
            if (button && !button.disabled) {
              // Focus editor before command executes
              if (!editor.matches(":focus-within")) {
                editor.focus()
              }
            }
          }, { passive: true })
        }
      }
    })
  }, 100)
})
