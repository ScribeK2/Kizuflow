import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "toggleIcon"]

  connect() {
    // Auto-expand groups that contain the selected group
    this.expandSelectedPath()
    
    // Initialize tooltips
    this.initializeTooltips()
  }

  toggle(event) {
    event.stopPropagation()
    this.sidebarTarget.classList.toggle("hidden")
    
    // Rotate icon (if it's a hamburger menu icon)
    if (this.hasToggleIconTarget) {
      // Toggle between hamburger and X icon
      const isHidden = this.sidebarTarget.classList.contains("hidden")
      if (isHidden) {
        this.toggleIconTarget.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />'
      } else {
        this.toggleIconTarget.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />'
      }
    }
  }

  toggleGroup(event) {
    event.stopPropagation()
    const button = event.currentTarget
    const groupId = button.dataset.groupId
    const childrenList = this.element.querySelector(`[data-children][data-group-id="${groupId}"]`)
    const icon = button.querySelector('[data-icon]')
    
    if (!childrenList) return
    
    // Smooth toggle with animation
    const isHidden = childrenList.classList.contains('hidden')
    
    if (isHidden) {
      // Expand
      childrenList.style.maxHeight = '0'
      childrenList.classList.remove('hidden')
      // Force reflow
      childrenList.offsetHeight
      childrenList.style.maxHeight = childrenList.scrollHeight + 'px'
      
      // Update aria-expanded
      button.setAttribute('aria-expanded', 'true')
      
      // Rotate icon
      if (icon) {
        icon.classList.add('rotate-90')
      }
      
      // Reset max-height after animation
      setTimeout(() => {
        childrenList.style.maxHeight = 'none'
      }, 300)
    } else {
      // Collapse
      childrenList.style.maxHeight = childrenList.scrollHeight + 'px'
      // Force reflow
      childrenList.offsetHeight
      childrenList.style.maxHeight = '0'
      
      // Update aria-expanded
      button.setAttribute('aria-expanded', 'false')
      
      // Rotate icon
      if (icon) {
        icon.classList.remove('rotate-90')
      }
      
      // Hide after animation
      setTimeout(() => {
        childrenList.classList.add('hidden')
        childrenList.style.maxHeight = ''
      }, 300)
    }
  }

  expandSelectedPath() {
    // Find all groups that should be expanded (ancestors of selected group)
    const selectedGroupItem = this.element.querySelector('.group-sidebar-item a[class*="bg-blue-100"]')
    if (!selectedGroupItem) return
    
    // Walk up the tree and expand all parent groups
    let current = selectedGroupItem.closest('.group-sidebar-item')
    while (current) {
      const groupId = current.dataset.groupId
      if (groupId) {
        const childrenList = this.element.querySelector(`[data-children][data-group-id="${groupId}"]`)
        const toggleButton = current.querySelector(`[data-group-id="${groupId}"].group-toggle`)
        
        if (childrenList && childrenList.classList.contains('hidden')) {
          // Expand without animation for initial load
          childrenList.classList.remove('hidden')
          childrenList.style.maxHeight = 'none'
          const icon = toggleButton?.querySelector('[data-icon]')
          if (icon) {
            icon.classList.add('rotate-90')
          }
          if (toggleButton) {
            toggleButton.setAttribute('aria-expanded', 'true')
          }
        }
      }
      
      // Move to parent
      current = current.parentElement?.closest('.group-sidebar-item')
    }
  }

  handleKeydown(event) {
    const item = event.currentTarget
    const groupId = item.dataset.groupId
    const toggleButton = item.querySelector(`[data-group-id="${groupId}"].group-toggle`)
    const link = item.querySelector('a')
    
    switch(event.key) {
      case 'ArrowRight':
        if (toggleButton && item.querySelector('[data-children]')) {
          event.preventDefault()
          const childrenList = item.querySelector(`[data-children][data-group-id="${groupId}"]`)
          if (childrenList && childrenList.classList.contains('hidden')) {
            toggleButton.click()
          }
        }
        break
      case 'ArrowLeft':
        if (toggleButton && item.querySelector('[data-children]')) {
          event.preventDefault()
          const childrenList = item.querySelector(`[data-children][data-group-id="${groupId}"]`)
          if (childrenList && !childrenList.classList.contains('hidden')) {
            toggleButton.click()
          }
        }
        break
      case 'Enter':
      case ' ':
        if (link && document.activeElement === item) {
          event.preventDefault()
          link.click()
        }
        break
    }
  }

  initializeTooltips() {
    // Simple tooltip implementation for group descriptions
    const items = this.element.querySelectorAll('[data-tooltip]')
    items.forEach(item => {
      const tooltip = item.dataset.tooltip
      if (!tooltip || tooltip.trim() === '') return
      
      let tooltipEl = null
      let showTimeout = null
      let hideTimeout = null
      
      const showTooltip = (e) => {
        // Clear any pending hide
        if (hideTimeout) {
          clearTimeout(hideTimeout)
          hideTimeout = null
        }
        
        // Don't show if already visible
        if (tooltipEl && document.body.contains(tooltipEl)) return
        
        // Clear any existing tooltip
        const existing = document.getElementById('group-tooltip')
        if (existing) existing.remove()
        
        // Create tooltip element
        tooltipEl = document.createElement('div')
        tooltipEl.id = 'group-tooltip'
        tooltipEl.className = 'fixed z-[9999] px-3 py-1.5 text-xs font-medium text-gray-900 dark:text-white bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-lg shadow-xl pointer-events-none whitespace-nowrap max-w-xs'
        tooltipEl.textContent = tooltip.trim()
        document.body.appendChild(tooltipEl)
        
        // Position tooltip above the element, centered
        const rect = item.getBoundingClientRect()
        const tooltipRect = tooltipEl.getBoundingClientRect()
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop
        const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft
        
        // Center horizontally above the element
        let left = rect.left + scrollLeft + (rect.width / 2) - (tooltipRect.width / 2)
        let top = rect.top + scrollTop - tooltipRect.height - 10
        
        // Ensure tooltip stays within viewport
        const padding = 12
        if (left < padding) left = padding
        if (left + tooltipRect.width > window.innerWidth - padding) {
          left = window.innerWidth - tooltipRect.width - padding
        }
        if (top < padding) {
          // If not enough space above, show below
          top = rect.bottom + scrollTop + 10
        }
        
        tooltipEl.style.left = left + 'px'
        tooltipEl.style.top = top + 'px'
      }
      
      const hideTooltip = () => {
        if (hideTimeout) return
        
        hideTimeout = setTimeout(() => {
          if (tooltipEl && document.body.contains(tooltipEl)) {
            tooltipEl.remove()
            tooltipEl = null
          }
          hideTimeout = null
        }, 100)
      }
      
      item.addEventListener('mouseenter', (e) => {
        showTimeout = setTimeout(() => showTooltip(e), 300) // Small delay before showing
      })
      
      item.addEventListener('mouseleave', () => {
        if (showTimeout) {
          clearTimeout(showTimeout)
          showTimeout = null
        }
        hideTooltip()
      })
      
      item.addEventListener('mousemove', (e) => {
        // Update position on mouse move
        if (tooltipEl && document.body.contains(tooltipEl)) {
          const rect = item.getBoundingClientRect()
          const tooltipRect = tooltipEl.getBoundingClientRect()
          const scrollTop = window.pageYOffset || document.documentElement.scrollTop
          const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft
          
          let left = rect.left + scrollLeft + (rect.width / 2) - (tooltipRect.width / 2)
          let top = rect.top + scrollTop - tooltipRect.height - 10
          
          const padding = 12
          if (left < padding) left = padding
          if (left + tooltipRect.width > window.innerWidth - padding) {
            left = window.innerWidth - tooltipRect.width - padding
          }
          if (top < padding) {
            top = rect.bottom + scrollTop + 10
          }
          
          tooltipEl.style.left = left + 'px'
          tooltipEl.style.top = top + 'px'
        }
      })
    })
  }
}

