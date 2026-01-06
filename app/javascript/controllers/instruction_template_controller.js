import { Controller } from "@hotwired/stimulus"

/**
 * Instruction Template Controller
 * 
 * Sprint 2: Action Step Simplification
 * Provides pre-written instruction snippets for common CSR tasks.
 * Templates can be inserted into the instructions textarea with one click.
 */
export default class extends Controller {
  static targets = [
    "instructionsField",
    "templatePanel",
    "categoryTabs",
    "templateList",
    "searchInput",
    "previewPanel"
  ]

  static values = {
    insertMode: { type: String, default: "append" } // "append" | "replace"
  }

  // Pre-defined instruction templates organized by category
  templates = {
    greeting: [
      {
        id: "greet-standard",
        name: "Standard Greeting",
        icon: "👋",
        content: "Thank the customer for calling and introduce yourself by name. Verify you're speaking with the account holder."
      },
      {
        id: "greet-callback",
        name: "Callback Greeting", 
        icon: "📞",
        content: "Thank the customer for returning the call. Reference the previous ticket/issue and confirm they're ready to continue troubleshooting."
      },
      {
        id: "greet-escalation",
        name: "Escalation Introduction",
        icon: "⬆️",
        content: "Introduce yourself as a senior support representative. Acknowledge the customer's previous experience and assure them you'll work to resolve the issue."
      }
    ],
    verification: [
      {
        id: "verify-account",
        name: "Account Verification",
        icon: "🔐",
        content: "Ask the customer to verify their account by providing:\n- Full name on the account\n- Email address associated with the account\n- Last 4 digits of payment method (if applicable)"
      },
      {
        id: "verify-domain",
        name: "Domain Ownership",
        icon: "🌐",
        content: "Verify domain ownership by asking the customer to confirm:\n- Domain name\n- Registrant email address\n- Date of registration (approximate)"
      },
      {
        id: "verify-2fa",
        name: "Two-Factor Auth",
        icon: "📱",
        content: "Inform the customer a verification code has been sent to their registered phone/email. Ask them to provide the code to proceed."
      }
    ],
    troubleshooting: [
      {
        id: "ts-clear-cache",
        name: "Clear Browser Cache",
        icon: "🗑️",
        content: "Ask the customer to clear their browser cache and cookies:\n1. Press Ctrl+Shift+Delete (Windows) or Cmd+Shift+Delete (Mac)\n2. Select 'All time' for the time range\n3. Check 'Cached images and files' and 'Cookies'\n4. Click 'Clear data'\n5. Restart the browser and try again"
      },
      {
        id: "ts-different-browser",
        name: "Try Different Browser",
        icon: "🌐",
        content: "Ask the customer to try accessing the service using a different browser (Chrome, Firefox, Safari, or Edge) to rule out browser-specific issues."
      },
      {
        id: "ts-incognito",
        name: "Try Incognito Mode",
        icon: "🕵️",
        content: "Ask the customer to open an incognito/private browsing window:\n- Chrome: Ctrl+Shift+N (Windows) or Cmd+Shift+N (Mac)\n- Firefox: Ctrl+Shift+P (Windows) or Cmd+Shift+P (Mac)\n- Then navigate to the page and try again"
      },
      {
        id: "ts-restart-device",
        name: "Restart Device",
        icon: "🔄",
        content: "Ask the customer to restart their device (computer/phone) and try the operation again after it fully reboots."
      }
    ],
    email: [
      {
        id: "email-check-spam",
        name: "Check Spam Folder",
        icon: "📧",
        content: "Ask the customer to check their spam/junk folder for the expected email. If found, mark it as 'Not Spam' to ensure future emails arrive in the inbox."
      },
      {
        id: "email-whitelist",
        name: "Whitelist Our Domain",
        icon: "✅",
        content: "Ask the customer to add our email domain to their contacts or safe senders list to prevent future emails from being filtered."
      },
      {
        id: "email-resend",
        name: "Resend Verification Email",
        icon: "📤",
        content: "Inform the customer you're resending the verification email. Ask them to wait 5-10 minutes and check both inbox and spam folders."
      }
    ],
    dns: [
      {
        id: "dns-propagation",
        name: "DNS Propagation Wait",
        icon: "⏳",
        content: "Explain to the customer that DNS changes can take up to 24-48 hours to propagate globally. Recommend checking back in 24 hours if changes are not yet visible."
      },
      {
        id: "dns-flush-cache",
        name: "Flush DNS Cache",
        icon: "🔄",
        content: "Guide the customer to flush their local DNS cache:\n\nWindows:\n1. Open Command Prompt as Administrator\n2. Type: ipconfig /flushdns\n3. Press Enter\n\nMac:\n1. Open Terminal\n2. Type: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder\n3. Press Enter and provide password if prompted"
      },
      {
        id: "dns-check-records",
        name: "Verify DNS Records",
        icon: "🔍",
        content: "Use a DNS lookup tool to verify the customer's DNS records are correctly configured. Check A records, CNAME records, MX records, and TXT records as applicable."
      }
    ],
    closing: [
      {
        id: "close-resolved",
        name: "Issue Resolved",
        icon: "✅",
        content: "Confirm with the customer that the issue has been resolved. Ask if there's anything else you can help with today. Thank them for their patience and for choosing our service."
      },
      {
        id: "close-followup",
        name: "Follow-up Required",
        icon: "📅",
        content: "Explain that the issue requires further investigation. Provide a ticket number and expected follow-up timeframe. Assure the customer they'll receive an update via email."
      },
      {
        id: "close-escalation",
        name: "Escalation Handoff",
        icon: "⬆️",
        content: "Explain that you're escalating the issue to a specialist team. Provide the escalation ticket number and expected response time. Thank the customer for their patience."
      }
    ]
  }

  connect() {
    this.currentCategory = "greeting"
    this.filteredTemplates = []
    
    // Render initial templates
    this.renderTemplates()
  }

  /**
   * Toggle the template panel visibility
   */
  togglePanel() {
    if (this.hasTemplatePanelTarget) {
      this.templatePanelTarget.classList.toggle("hidden")
      
      // Focus search input when opening
      if (!this.templatePanelTarget.classList.contains("hidden") && this.hasSearchInputTarget) {
        setTimeout(() => this.searchInputTarget.focus(), 100)
      }
    }
  }

  /**
   * Close the template panel
   */
  closePanel() {
    if (this.hasTemplatePanelTarget) {
      this.templatePanelTarget.classList.add("hidden")
    }
  }

  /**
   * Switch category tab
   */
  selectCategory(event) {
    const category = event.currentTarget.dataset.category
    this.currentCategory = category
    
    // Update tab styles
    if (this.hasCategoryTabsTarget) {
      this.categoryTabsTarget.querySelectorAll("button").forEach(btn => {
        const isActive = btn.dataset.category === category
        btn.classList.toggle("bg-blue-100", isActive)
        btn.classList.toggle("text-blue-700", isActive)
        btn.classList.toggle("dark:bg-blue-900/30", isActive)
        btn.classList.toggle("dark:text-blue-300", isActive)
        btn.classList.toggle("bg-transparent", !isActive)
        btn.classList.toggle("text-gray-600", !isActive)
        btn.classList.toggle("dark:text-gray-400", !isActive)
      })
    }
    
    // Clear search and render templates
    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }
    this.renderTemplates()
  }

  /**
   * Search templates
   */
  searchTemplates() {
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value.toLowerCase().trim() : ""
    this.renderTemplates(query)
  }

  /**
   * Render templates for current category (optionally filtered)
   */
  renderTemplates(searchQuery = "") {
    if (!this.hasTemplateListTarget) return
    
    let templates = this.templates[this.currentCategory] || []
    
    // Filter by search query if provided
    if (searchQuery) {
      // Search across all categories
      templates = Object.values(this.templates).flat().filter(t =>
        t.name.toLowerCase().includes(searchQuery) ||
        t.content.toLowerCase().includes(searchQuery)
      )
    }
    
    // Render template items
    this.templateListTarget.innerHTML = templates.map(template => `
      <button type="button"
              class="w-full text-left p-3 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-300 dark:hover:border-blue-600 transition-all duration-200 group"
              data-action="click->instruction-template#insertTemplate"
              data-template-id="${template.id}"
              data-template-content="${this.escapeHtml(template.content)}">
        <div class="flex items-start gap-3">
          <span class="text-xl">${template.icon}</span>
          <div class="flex-1 min-w-0">
            <div class="font-medium text-gray-900 dark:text-gray-100 text-sm group-hover:text-blue-600 dark:group-hover:text-blue-400">
              ${template.name}
            </div>
            <div class="text-xs text-gray-500 dark:text-gray-400 mt-1 line-clamp-2">
              ${this.escapeHtml(template.content.substring(0, 80))}${template.content.length > 80 ? '...' : ''}
            </div>
          </div>
          <svg class="w-4 h-4 text-gray-400 group-hover:text-blue-500 flex-shrink-0 mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
        </div>
      </button>
    `).join("")
    
    // Show empty state if no templates
    if (templates.length === 0) {
      this.templateListTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500 dark:text-gray-400">
          <svg class="mx-auto h-10 w-10 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="text-sm">No templates found</p>
        </div>
      `
    }
  }

  /**
   * Insert a template into the instructions field
   */
  insertTemplate(event) {
    const content = event.currentTarget.dataset.templateContent
    if (!content || !this.hasInstructionsFieldTarget) return
    
    const textarea = this.instructionsFieldTarget
    const currentValue = textarea.value
    
    if (this.insertModeValue === "replace" || currentValue.trim() === "") {
      // Replace mode or empty field
      textarea.value = content
    } else {
      // Append mode - add to existing content
      textarea.value = currentValue + (currentValue.endsWith("\n") ? "" : "\n\n") + content
    }
    
    // Trigger input event for autosave and preview
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
    
    // Close panel
    this.closePanel()
    
    // Focus textarea
    textarea.focus()
    
    // Scroll textarea to show new content
    textarea.scrollTop = textarea.scrollHeight
  }

  /**
   * Preview a template (on hover)
   */
  previewTemplate(event) {
    if (!this.hasPreviewPanelTarget) return
    
    const content = event.currentTarget.dataset.templateContent
    if (!content) return
    
    this.previewPanelTarget.textContent = content
    this.previewPanelTarget.classList.remove("hidden")
  }

  /**
   * Hide preview panel
   */
  hidePreview() {
    if (this.hasPreviewPanelTarget) {
      this.previewPanelTarget.classList.add("hidden")
    }
  }

  /**
   * Toggle insert mode between append and replace
   */
  toggleInsertMode(event) {
    this.insertModeValue = event.currentTarget.checked ? "replace" : "append"
  }

  /**
   * Get all templates as flat array (for external use)
   */
  getAllTemplates() {
    return Object.entries(this.templates).flatMap(([category, templates]) =>
      templates.map(t => ({ ...t, category }))
    )
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

