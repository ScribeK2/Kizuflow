import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Enables drag-and-drop reordering of folders in admin view
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: ".cursor-move",
      ghostClass: "opacity-50",
      onEnd: this.reorder.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  reorder() {
    const folderIds = Array.from(this.element.children).map(
      (li) => li.dataset.folderId
    )

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({ folder_ids: folderIds })
    })
  }
}
