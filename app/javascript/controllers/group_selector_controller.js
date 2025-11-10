import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "dropdown", "tree", "selected", "checkbox", "buttonText"]

  connect() {
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)
    
    // Update button text based on selected groups
    this.updateButtonText()
    
    // Initialize expand/collapse icons for parent groups
    this.initializeExpandIcons()
  }
  
  initializeExpandIcons() {
    // Set initial icon state for all expand buttons
    const expandButtons = this.treeTarget.querySelectorAll('[data-action*="toggleExpand"]')
    expandButtons.forEach(button => {
      const groupOption = button.closest(".group-option")
      const childrenContainer = groupOption.querySelector(".children")
      if (childrenContainer) {
        const isExpanded = !childrenContainer.classList.contains("hidden")
        const icon = button.querySelector("svg")
        if (icon) {
          if (isExpanded) {
            // Expanded: show chevron-down
            icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />'
          } else {
            // Collapsed: show chevron-right
            icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />'
          }
        }
      }
    })
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase().trim()
    const options = this.treeTarget.querySelectorAll(".group-option")
    
    if (searchTerm === "") {
      // Show all options when search is cleared
      options.forEach(option => {
        option.classList.remove("hidden")
        // Expand all when search is cleared (optional - you might want to keep collapsed state)
        const childrenContainer = option.querySelector(".children")
        if (childrenContainer) {
          childrenContainer.classList.remove("hidden")
        }
      })
      return
    }
    
    // Recursive search: check if option or any descendant matches
    options.forEach(option => {
      const matches = this.matchesSearch(option, searchTerm)
      if (matches) {
        option.classList.remove("hidden")
        // Expand parent containers to show matching children
        this.expandToShow(option)
      } else {
        option.classList.add("hidden")
      }
    })
  }
  
  // Recursively check if option or any descendant matches search term
  matchesSearch(option, searchTerm) {
    const groupName = (option.dataset.groupName || "").toLowerCase()
    const matches = groupName.includes(searchTerm)
    
    // Check all descendants recursively
    const children = option.querySelectorAll(".group-option")
    let hasMatchingDescendant = false
    
    children.forEach(child => {
      if (this.matchesSearch(child, searchTerm)) {
        hasMatchingDescendant = true
      }
    })
    
    return matches || hasMatchingDescendant
  }
  
  // Expand parent containers to show matching children
  expandToShow(option) {
    let current = option.parentElement
    while (current && current !== this.treeTarget) {
      if (current.classList.contains("children")) {
        current.classList.remove("hidden")
        // Also show the parent group-option
        const parentOption = current.closest(".group-option")
        if (parentOption) {
          parentOption.classList.remove("hidden")
        }
      }
      current = current.parentElement
    }
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
    // Check if already selected (both badge and hidden field)
    if (this.selectedTarget.querySelector(`[data-selected-id="${groupId}"]`)) {
      return
    }
    
    // Also check if hidden field already exists in the form
    const form = this.element.closest('form')
    if (form) {
      const existingHiddenField = form.querySelector(`input[name="workflow[group_ids][]"][value="${groupId}"]`)
      if (existingHiddenField) {
        // Hidden field exists but badge doesn't - create badge only
        const badge = document.createElement("span")
        badge.className = "inline-flex items-center px-3 py-1.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 border border-blue-200 dark:border-blue-800 transition-all duration-200"
        badge.dataset.selectedId = groupId
        
        badge.innerHTML = `
          ${groupName}
          <button type="button" 
                  data-action="click->group-selector#remove"
                  data-group-id="${groupId}"
                  class="ml-2 text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 rounded">
            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        `
        this.selectedTarget.appendChild(badge)
        return
      }
    }
    
    // Neither badge nor hidden field exists - create both
    const badge = document.createElement("span")
    badge.className = "inline-flex items-center px-3 py-1.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 border border-blue-200 dark:border-blue-800 transition-all duration-200"
    badge.dataset.selectedId = groupId
    
    badge.innerHTML = `
      ${groupName}
      <button type="button" 
              data-action="click->group-selector#remove"
              data-group-id="${groupId}"
              class="ml-2 text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 rounded">
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
      // Also remove the hidden field if it exists within the badge
      const hiddenField = badge.querySelector(`input[name="workflow[group_ids][]"][value="${groupId}"]`)
      if (hiddenField) {
        hiddenField.remove()
      }
      badge.remove()
    }
    
    // Also check for hidden fields outside the badge (from server-side rendering)
    const form = this.element.closest('form')
    if (form) {
      const hiddenField = form.querySelector(`input[name="workflow[group_ids][]"][value="${groupId}"]`)
      if (hiddenField) {
        hiddenField.remove()
      }
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
  
  // Toggle expand/collapse for parent groups
  toggleExpand(event) {
    event.stopPropagation()
    const button = event.currentTarget
    const groupOption = button.closest(".group-option")
    const childrenContainer = groupOption.querySelector(".children")
    
    if (childrenContainer) {
      const isExpanded = !childrenContainer.classList.contains("hidden")
      childrenContainer.classList.toggle("hidden")
      
      // Update icon
      const icon = button.querySelector("svg")
      if (icon) {
        if (isExpanded) {
          // Collapse: show chevron-right
          icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />'
        } else {
          // Expand: show chevron-down
          icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />'
        }
      }
    }
  }
}

