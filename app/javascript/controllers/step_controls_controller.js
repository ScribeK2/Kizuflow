import { Controller } from "@hotwired/stimulus"

/**
 * Step Controls Controller
 *
 * Provides expand/collapse all functionality for collapsible steps.
 * This controller is CSP-compliant, replacing inline onclick handlers.
 */
export default class extends Controller {
  /**
   * Expand all collapsible steps in the document
   */
  expandAll() {
    document.querySelectorAll('[data-controller*="collapsible-step"]').forEach(element => {
      const controller = this.application.getControllerForElementAndIdentifier(element, "collapsible-step")
      if (controller) {
        controller.expand()
      }
    })
  }

  /**
   * Collapse all collapsible steps in the document
   */
  collapseAll() {
    document.querySelectorAll('[data-controller*="collapsible-step"]').forEach(element => {
      const controller = this.application.getControllerForElementAndIdentifier(element, "collapsible-step")
      if (controller) {
        controller.collapse()
      }
    })
  }
}
