import { Controller } from "@hotwired/stimulus"

// Two-way sync between list editor and flow preview in Split mode.
// Listens for node clicks in preview and step expansions in list,
// scrolling and highlighting the corresponding element.
export default class extends Controller {
  connect() {
    this.boundNodeClicked = this.onNodeClicked.bind(this)
    this.boundStepSelected = this.onStepSelected.bind(this)

    document.addEventListener("flow-preview:node-clicked", this.boundNodeClicked)
    document.addEventListener("step:selected", this.boundStepSelected)
  }

  disconnect() {
    document.removeEventListener("flow-preview:node-clicked", this.boundNodeClicked)
    document.removeEventListener("step:selected", this.boundStepSelected)
  }

  // Preview -> List: click a node in preview, scroll to and highlight the list card
  onNodeClicked(event) {
    if (!this.isSplitMode()) return

    const stepId = event.detail?.stepId
    if (!stepId) return

    const stepItem = this.element.querySelector(`.step-item input[name*='[id]'][value='${CSS.escape(stepId)}']`)
    if (!stepItem) return

    const card = stepItem.closest(".step-item")
    if (!card) return

    // Expand the card
    const collapsible = window.Stimulus?.getControllerForElementAndIdentifier(
      card.querySelector("[data-controller*='collapsible-step']") || card,
      "collapsible-step"
    )
    if (collapsible) collapsible.expand()

    // Scroll into view
    card.scrollIntoView({ behavior: "smooth", block: "center" })

    // Highlight briefly
    card.classList.add("is-highlighted")
    setTimeout(() => card.classList.remove("is-highlighted"), 2000)
  }

  // List -> Preview: expand a list card, highlight the matching preview node
  onStepSelected(event) {
    if (!this.isSplitMode()) return

    const stepId = event.detail?.stepId
    if (!stepId) return

    const previewNode = this.element.querySelector(`.workflow-node[data-step-id='${CSS.escape(stepId)}']`)
    if (!previewNode) return

    previewNode.classList.add("is-sync-highlighted")
    previewNode.scrollIntoView({ behavior: "smooth", block: "center" })
    setTimeout(() => previewNode.classList.remove("is-sync-highlighted"), 2000)
  }

  isSplitMode() {
    return !!this.element.querySelector(".wf-editor-layout--split")
  }
}
