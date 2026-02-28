import { Controller } from "@hotwired/stimulus"
import SparkMD5 from "spark-md5"

// Provides markdown formatting toolbar actions for a <textarea>.
// Supports: formatting buttons, image upload/URL insertion, and preview toggle.
//
// Targets:
//   input     - the textarea
//   preview   - div where rendered HTML preview is shown
//   fileInput - hidden file input for image uploads
//   status    - upload status text element
//   imageMenu - dropdown for image insertion options
//   toolbar   - the toolbar buttons container (for disabling in preview mode)
//
// Values:
//   previewUrl - the URL to POST markdown for server-side rendering
export default class extends Controller {
  static targets = ["input", "preview", "fileInput", "status", "imageMenu", "toolbar"]
  static values = { previewUrl: String }

  connect() {
    this.previewing = false
  }

  // -- Formatting actions -----------------------------------------------------

  bold()          { this.#wrap("**", "**") }
  italic()        { this.#wrap("_", "_") }
  strikethrough() { this.#wrap("~~", "~~") }
  code()          { this.#wrap("`", "`") }
  heading()       { this.#prefixLine("## ") }
  quote()         { this.#prefixLine("> ") }
  bulletList()    { this.#prefixLine("- ") }
  numberedList()  { this.#prefixLine("1. ") }

  link() {
    const textarea = this.inputTarget
    const { selectionStart, selectionEnd } = textarea
    const selected = textarea.value.substring(selectionStart, selectionEnd)
    const url = selected.match(/^https?:\/\//) ? selected : "url"
    const text = url === selected ? "link text" : (selected || "link text")

    const before = textarea.value.substring(0, selectionStart)
    const after = textarea.value.substring(selectionEnd)
    const insertion = `[${text}](${url})`

    textarea.value = before + insertion + after

    // Select the url part so user can type the URL
    const urlStart = selectionStart + text.length + 3 // [text](
    textarea.selectionStart = urlStart
    textarea.selectionEnd = urlStart + url.length

    this.#afterInsert(textarea)
  }

  // -- Image actions ----------------------------------------------------------

  toggleImageMenu() {
    if (this.hasImageMenuTarget) {
      this.imageMenuTarget.classList.toggle("hidden")
    }
  }

  hideImageMenu() {
    if (this.hasImageMenuTarget) {
      this.imageMenuTarget.classList.add("hidden")
    }
  }

  pickImage() {
    this.hideImageMenu()
    this.fileInputTarget.click()
  }

  insertImageUrl() {
    this.hideImageMenu()
    const url = prompt("Enter image URL:")
    if (!url) return

    const textarea = this.inputTarget
    const { selectionStart, selectionEnd } = textarea
    const selected = textarea.value.substring(selectionStart, selectionEnd)
    const alt = selected || "image"

    const before = textarea.value.substring(0, selectionStart)
    const after = textarea.value.substring(selectionEnd)

    const needsNewlineBefore = before.length > 0 && !before.endsWith("\n")
    const needsNewlineAfter = after.length > 0 && !after.startsWith("\n")
    const insertion = (needsNewlineBefore ? "\n" : "") + `![${alt}](${url})` + (needsNewlineAfter ? "\n" : "")

    textarea.value = before + insertion + after

    const newPos = selectionStart + insertion.length
    textarea.selectionStart = newPos
    textarea.selectionEnd = newPos

    this.#afterInsert(textarea)
  }

  async handleFileSelected(event) {
    const file = event.target.files[0]
    if (!file) return

    if (!file.type.startsWith("image/")) {
      alert("Please select an image file.")
      return
    }

    const maxSize = 10 * 1024 * 1024
    if (file.size > maxSize) {
      alert("Image must be smaller than 10MB.")
      return
    }

    this.#setStatus("Uploading...")

    try {
      const url = await this.#uploadToActiveStorage(file)
      this.#insertMarkdownImage(file.name, url)
      this.#setStatus("")
    } catch (error) {
      console.error("Image upload failed:", error)
      alert("Failed to upload image: " + error.message)
      this.#setStatus("")
    }

    event.target.value = ""
  }

  // -- Preview toggle ---------------------------------------------------------

  async togglePreview() {
    if (this.previewing) {
      this.#showEditor()
    } else {
      await this.#showPreview()
    }
  }

  // -- Private helpers --------------------------------------------------------

  #wrap(before, after) {
    const textarea = this.inputTarget
    const { selectionStart, selectionEnd } = textarea
    const selected = textarea.value.substring(selectionStart, selectionEnd)
    const placeholder = selected || "text"

    const prefix = textarea.value.substring(0, selectionStart)
    const suffix = textarea.value.substring(selectionEnd)

    textarea.value = prefix + before + placeholder + after + suffix

    textarea.selectionStart = selectionStart + before.length
    textarea.selectionEnd = selectionStart + before.length + placeholder.length

    this.#afterInsert(textarea)
  }

  #prefixLine(prefix) {
    const textarea = this.inputTarget
    const { selectionStart, selectionEnd } = textarea
    const value = textarea.value

    const lineStart = value.lastIndexOf("\n", selectionStart - 1) + 1
    let lineEnd = value.indexOf("\n", selectionEnd)
    if (lineEnd === -1) lineEnd = value.length

    const selectedLines = value.substring(lineStart, lineEnd)
    const prefixed = selectedLines
      .split("\n")
      .map(line => prefix + line)
      .join("\n")

    textarea.value = value.substring(0, lineStart) + prefixed + value.substring(lineEnd)

    const newEnd = lineStart + prefixed.length
    textarea.selectionStart = newEnd
    textarea.selectionEnd = newEnd

    this.#afterInsert(textarea)
  }

  #afterInsert(textarea) {
    textarea.focus()
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }

  #setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.classList.toggle("hidden", !message)
    }
  }

  #insertMarkdownImage(filename, url) {
    const textarea = this.inputTarget
    const markdownImage = `![${filename}](${url})`

    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const text = textarea.value

    const before = text.substring(0, start)
    const after = text.substring(end)

    const needsNewlineBefore = before.length > 0 && !before.endsWith("\n")
    const needsNewlineAfter = after.length > 0 && !after.startsWith("\n")
    const insertion = (needsNewlineBefore ? "\n" : "") + markdownImage + (needsNewlineAfter ? "\n" : "")

    textarea.value = before + insertion + after

    const newPos = start + insertion.length
    textarea.selectionStart = newPos
    textarea.selectionEnd = newPos
    textarea.focus()
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }

  async #uploadToActiveStorage(file) {
    const checksum = await this.#calculateChecksum(file)

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null
    if (!csrfToken) throw new Error("CSRF token not found. Please refresh the page.")

    const response = await fetch("/rails/active_storage/direct_uploads", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({
        blob: {
          filename: file.name,
          byte_size: file.size,
          content_type: file.type || "application/octet-stream",
          checksum: checksum
        }
      })
    })

    if (!response.ok) {
      throw new Error("Server error: " + response.status + " " + response.statusText)
    }

    const data = await response.json()
    if (!data.direct_upload || !data.direct_upload.url) {
      throw new Error("Invalid response from server")
    }

    const uploadResponse = await fetch(data.direct_upload.url, {
      method: "PUT",
      credentials: "same-origin",
      headers: data.direct_upload.headers || {},
      body: file
    })

    if (!uploadResponse.ok) {
      throw new Error("Upload failed: " + uploadResponse.status)
    }

    return "/rails/active_storage/blobs/redirect/" + data.signed_id + "/" + encodeURIComponent(file.name)
  }

  #calculateChecksum(file) {
    return new Promise((resolve, reject) => {
      const chunkSize = 2097152
      const chunks = Math.ceil(file.size / chunkSize)
      let currentChunk = 0
      const spark = new SparkMD5.ArrayBuffer()
      const fileReader = new FileReader()

      fileReader.onload = (e) => {
        spark.append(e.target.result)
        currentChunk++
        if (currentChunk < chunks) {
          loadNext()
        } else {
          const hexHash = spark.end()
          const binaryHash = []
          for (let i = 0; i < hexHash.length; i += 2) {
            binaryHash.push(parseInt(hexHash.substr(i, 2), 16))
          }
          resolve(btoa(String.fromCharCode.apply(null, binaryHash)))
        }
      }

      fileReader.onerror = () => {
        reject(new Error("Failed to read file"))
      }

      function loadNext() {
        const start = currentChunk * chunkSize
        const end = Math.min(start + chunkSize, file.size)
        fileReader.readAsArrayBuffer(file.slice(start, end))
      }

      loadNext()
    })
  }

  async #showPreview() {
    const text = this.inputTarget.value
    const url = this.previewUrlValue

    try {
      const csrfMeta = document.querySelector('meta[name="csrf-token"]')
      const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : ""

      const response = await fetch(url, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "text/html"
        },
        body: "text=" + encodeURIComponent(text)
      })

      if (!response.ok) throw new Error("Preview failed")

      const html = await response.text()
      // Safe: HTML is sanitized server-side by render_step_markdown (Rails sanitize + allowlist)
      this.previewTarget.innerHTML = html
    } catch (error) {
      this.previewTarget.textContent = "Failed to load preview."
    }

    this.inputTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")
    this.previewing = true
    this.#setToolbarDisabled(true)
  }

  #showEditor() {
    this.previewTarget.classList.add("hidden")
    this.inputTarget.classList.remove("hidden")
    this.previewing = false
    this.#setToolbarDisabled(false)
    this.inputTarget.focus()
  }

  #setToolbarDisabled(disabled) {
    if (!this.hasToolbarTarget) return
    const buttons = this.toolbarTarget.querySelectorAll("button:not([data-preview-toggle])")
    buttons.forEach(btn => {
      btn.disabled = disabled
      btn.classList.toggle("opacity-40", disabled)
      btn.classList.toggle("pointer-events-none", disabled)
    })
  }
}
