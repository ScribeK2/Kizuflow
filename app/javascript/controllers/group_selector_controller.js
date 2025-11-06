import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "dropdown", "tree", "selected", "checkbox", "buttonText"]

  connect() {
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
    
    // Update button text based on selected groups
    this.updateButtonText()
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase()
    const options = this.treeTarget.querySelectorAll(".group-option")
    
    options.forEach(option => {
      const groupName = option.dataset.groupName || ""
      const matches = groupName.includes(searchTerm)
      
      // Show if matches or has matching children
      const hasMatchingChildren = option.querySelector(`.group-option[data-group-name*="${searchTerm}"]`)
      
      if (matches || hasMatchingChildren) {
        option.classList.remove("hidden")
      } else {
        option.classList.add("hidden")
      }
    })
  }

  select(event) {
    const checkbox = event.target
    const groupId = checkbox.value
    const groupOption = checkbox.closest(".group-option")
    const groupName = groupOption.querySelector("span").textContent.trim().split(" - ")[0]
    
    if (checkbox.checked) {
      this.addSelected(groupId, groupName)
    } else {
      this.removeSelected(groupId)
    }
    
    this.updateButtonText()
  }

  remove(event) {
    event.stopPropagation()
    const groupId = event.currentTarget.dataset.groupId
    this.removeSelected(groupId)
    
    // Uncheck the checkbox
    const checkbox = this.treeTarget.querySelector(`input[value="${groupId}"]`)
    if (checkbox) {
      checkbox.checked = false
    }
    
    this.updateButtonText()
  }

  addSelected(groupId, groupName) {
    // Check if already selected
    if (this.selectedTarget.querySelector(`[data-selected-id="${groupId}"]`)) {
      return
    }
    
    const badge = document.createElement("span")
    badge.className = "inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300"
    badge.dataset.selectedId = groupId
    
    badge.innerHTML = `
      ${groupName}
      <button type="button" 
              data-action="click->group-selector#remove"
              data-group-id="${groupId}"
              class="ml-2 text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200">
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
      <input type="hidden" name="workflow[group_ids][]" value="${groupId}">
    `
    
    this.selectedTarget.appendChild(badge)
  }

  removeSelected(groupId) {
    const badge = this.selectedTarget.querySelector(`[data-selected-id="${groupId}"]`)
    if (badge) {
      badge.remove()
    }
  }

  updateButtonText() {
    const selectedCount = this.selectedTarget.querySelectorAll("[data-selected-id]").length
    if (this.hasButtonTextTarget) {
      if (selectedCount > 0) {
        this.buttonTextTarget.textContent = `${selectedCount} group${selectedCount > 1 ? 's' : ''} selected`
      } else {
        this.buttonTextTarget.textContent = "Select groups..."
      }
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target) && !this.dropdownTarget.classList.contains("hidden")) {
      this.dropdownTarget.classList.add("hidden")
    }
  }
}

