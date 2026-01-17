import { Controller } from "@hotwired/stimulus"

// Manages dynamic output fields for action steps
// Allows adding/removing output variable definitions with name and value pairs
export default class extends Controller {
  static targets = ["fieldsList", "outputFieldsInput"]
  static values = { fields: Array }

  connect() {
    // Initialize with existing fields if any
    if (this.fieldsValue.length > 0) {
      this.fieldsValue.forEach((field, index) => {
        this.addFieldToDOM(field, index)
      })
    }
  }

  addField(event) {
    event.preventDefault()
    const newField = { name: "", value: "" }
    const index = this.fieldsListTarget.children.length
    this.addFieldToDOM(newField, index)
    this.updateHiddenInput()
  }

  removeField(event) {
    event.preventDefault()
    const fieldElement = event.currentTarget.closest("[data-field-index]")
    if (fieldElement) {
      fieldElement.remove()
      // Re-index remaining fields
      this.fieldsListTarget.querySelectorAll("[data-field-index]").forEach((el, index) => {
        el.setAttribute("data-field-index", index)
      })
      this.updateHiddenInput()
    }
  }

  updateField(event) {
    this.updateHiddenInput()
  }

  addFieldToDOM(field, index) {
    const fieldDiv = document.createElement("div")
    fieldDiv.className = "flex gap-2 items-start"
    fieldDiv.setAttribute("data-field-index", index)
    
    fieldDiv.innerHTML = `
      <div class="flex-1 grid grid-cols-2 gap-2">
        <input type="text" 
               placeholder="Variable name (e.g., status)"
               value="${this.escapeHtml(field.name || "")}"
               class="border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
               data-action="input->output-fields#updateField"
               data-field-attr="name">
        <input type="text" 
               placeholder="Value (e.g., completed or {{other_var}})"
               value="${this.escapeHtml(field.value || "")}"
               class="border border-gray-300 dark:border-gray-600 rounded-lg px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 text-sm"
               data-action="input->output-fields#updateField"
               data-field-attr="value">
      </div>
      <button type="button" 
              class="px-3 py-2 text-sm text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300"
              data-action="click->output-fields#removeField">
        Remove
      </button>
    `
    
    this.fieldsListTarget.appendChild(fieldDiv)
  }

  updateHiddenInput() {
    const fields = []
    this.fieldsListTarget.querySelectorAll("[data-field-index]").forEach((fieldElement) => {
      const nameInput = fieldElement.querySelector('[data-field-attr="name"]')
      const valueInput = fieldElement.querySelector('[data-field-attr="value"]')
      
      if (nameInput && nameInput.value.trim()) {
        fields.push({
          name: nameInput.value.trim(),
          value: valueInput ? valueInput.value : ""
        })
      }
    })
    
    this.outputFieldsInputTarget.value = JSON.stringify(fields)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
