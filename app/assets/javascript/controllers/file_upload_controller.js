import { Controller } from "@hotwired/stimulus"

// File upload controller to handle file selection feedback
export default class extends Controller {
  static targets = ["fileInput", "dropZone", "emptyState", "fileSelected", "fileName", "fileSize"]

  connect() {
    // Check if file is already selected (on page reload)
    if (this.fileInputTarget.files.length > 0) {
      this.showFileSelected(this.fileInputTarget.files[0])
    }
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.showFileSelected(file)
    }
  }

  dragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add("border-blue-500", "bg-blue-50", "dark:bg-blue-900/20")
    this.dropZoneTarget.classList.remove("border-gray-300", "dark:border-gray-600")
  }

  dragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove("border-blue-500", "bg-blue-50", "dark:bg-blue-900/20")
    this.dropZoneTarget.classList.add("border-gray-300", "dark:border-gray-600")
  }

  drop(event) {
    event.preventDefault()
    this.dragLeave(event)
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]
      // Check file extension
      const fileName = file.name.toLowerCase()
      if (fileName.endsWith('.json') || fileName.endsWith('.csv') || 
          fileName.endsWith('.yaml') || fileName.endsWith('.yml') || 
          fileName.endsWith('.md') || fileName.endsWith('.markdown')) {
        // Create a data transfer object to set files
        const dataTransfer = new DataTransfer()
        dataTransfer.items.add(file)
        this.fileInputTarget.files = dataTransfer.files
        this.showFileSelected(file)
      } else {
        alert("Please select a JSON, CSV, YAML, or Markdown file.")
      }
    }
  }

  clearFile() {
    this.fileInputTarget.value = ""
    this.emptyStateTarget.classList.remove("hidden")
    this.fileSelectedTarget.classList.add("hidden")
  }

  showFileSelected(file) {
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    this.emptyStateTarget.classList.add("hidden")
    this.fileSelectedTarget.classList.remove("hidden")
  }

  formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes"
    const k = 1024
    const sizes = ["Bytes", "KB", "MB", "GB"]
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + " " + sizes[i]
  }
}

