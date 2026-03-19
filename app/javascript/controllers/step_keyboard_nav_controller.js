import { Controller } from "@hotwired/stimulus"

// Keyboard navigation for step cards in list view.
// Arrow Up/Down to move focus, Enter to expand, Escape to collapse.
export default class extends Controller {
  connect() {
    this.focusedIndex = -1
  }

  handleKeydown(event) {
    const cards = this.getStepCards()
    if (cards.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.moveFocus(cards, 1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.moveFocus(cards, -1)
        break
      case "Enter":
        event.preventDefault()
        this.expandFocused(cards)
        break
      case "Escape":
        event.preventDefault()
        this.collapseFocused(cards)
        break
    }
  }

  moveFocus(cards, direction) {
    // Find currently focused card index
    const current = Array.from(cards).findIndex(c => c === document.activeElement || c.contains(document.activeElement))
    let nextIndex

    if (current === -1) {
      nextIndex = direction > 0 ? 0 : cards.length - 1
    } else {
      nextIndex = current + direction
    }

    // Clamp
    nextIndex = Math.max(0, Math.min(cards.length - 1, nextIndex))

    cards[nextIndex].focus()
    this.focusedIndex = nextIndex

    // Dispatch step:selected for split sync
    const idInput = cards[nextIndex].querySelector("input[name*='[id]']")
    if (idInput?.value) {
      document.dispatchEvent(new CustomEvent("step:selected", {
        detail: { stepId: idInput.value }
      }))
    }
  }

  expandFocused(cards) {
    const focused = this.getFocusedCard(cards)
    if (!focused) return

    const collapsible = window.Stimulus?.getControllerForElementAndIdentifier(
      focused.querySelector("[data-controller*='collapsible-step']") || focused,
      "collapsible-step"
    )
    if (collapsible) collapsible.expand()
  }

  collapseFocused(cards) {
    const focused = this.getFocusedCard(cards)
    if (!focused) return

    const collapsible = window.Stimulus?.getControllerForElementAndIdentifier(
      focused.querySelector("[data-controller*='collapsible-step']") || focused,
      "collapsible-step"
    )
    if (collapsible) collapsible.collapse()
  }

  getFocusedCard(cards) {
    return Array.from(cards).find(c => c === document.activeElement || c.contains(document.activeElement))
  }

  getStepCards() {
    return this.element.querySelectorAll(".step-item")
  }
}
