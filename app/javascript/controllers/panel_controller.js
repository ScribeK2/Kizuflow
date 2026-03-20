import { Controller } from "@hotwired/stimulus"

// Lightweight panel controller. Most logic lives in builder_controller.
export default class extends Controller {
  close() {
    this.dispatch("close", { bubbles: true })
  }
}
