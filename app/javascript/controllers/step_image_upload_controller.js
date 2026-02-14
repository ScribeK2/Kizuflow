import { Controller } from "@hotwired/stimulus"
import SparkMD5 from "spark-md5"

// Provides image upload + markdown insertion for step textareas.
// Usage: Wrap a textarea with data-controller="step-image-upload"
//        Add data-step-image-upload-target="textarea" to the textarea
//        Add a button with data-action="click->step-image-upload#pickImage"
export default class extends Controller {
  static targets = ["textarea", "fileInput", "status"]

  connect() {
    // Create hidden file input
    if (!this.hasFileInputTarget) {
      const input = document.createElement("input")
      input.type = "file"
      input.accept = "image/*"
      input.className = "hidden"
      input.setAttribute("data-step-image-upload-target", "fileInput")
      input.setAttribute("data-action", "change->step-image-upload#handleFileSelected")
      this.element.appendChild(input)
    }
  }

  pickImage() {
    this.fileInputTarget.click()
  }

  async handleFileSelected(event) {
    const file = event.target.files[0]
    if (!file) return

    // Validate file type
    if (!file.type.startsWith("image/")) {
      alert("Please select an image file.")
      return
    }

    // Validate file size (max 10MB)
    const maxSize = 10 * 1024 * 1024
    if (file.size > maxSize) {
      alert("Image must be smaller than 10MB.")
      return
    }

    this.setStatus("Uploading...")

    try {
      const url = await this.uploadToActiveStorage(file)
      this.insertMarkdownImage(file.name, url)
      this.setStatus("")
    } catch (error) {
      console.error("Image upload failed:", error)
      alert("Failed to upload image: " + error.message)
      this.setStatus("")
    }

    // Reset file input
    event.target.value = ""
  }

  async uploadToActiveStorage(file) {
    const checksum = await this.calculateChecksum(file)

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null
    if (!csrfToken) throw new Error("CSRF token not found. Please refresh the page.")

    // Step 1: Create blob record
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

    // Step 2: Upload file to storage
    const uploadResponse = await fetch(data.direct_upload.url, {
      method: "PUT",
      credentials: "same-origin",
      headers: data.direct_upload.headers || {},
      body: file
    })

    if (!uploadResponse.ok) {
      throw new Error("Upload failed: " + uploadResponse.status)
    }

    // Step 3: Return the serving URL using the signed_id
    // Use the redirect URL pattern so it works regardless of storage backend
    return "/rails/active_storage/blobs/redirect/" + data.signed_id + "/" + encodeURIComponent(file.name)
  }

  insertMarkdownImage(filename, url) {
    const textarea = this.textareaTarget
    const markdownImage = "![" + filename + "](" + url + ")"

    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const text = textarea.value

    // Insert at cursor position (or append with newline)
    const before = text.substring(0, start)
    const after = text.substring(end)

    // Add newlines around image if not at start/end of line
    const needsNewlineBefore = before.length > 0 && !before.endsWith("\n")
    const needsNewlineAfter = after.length > 0 && !after.startsWith("\n")

    const insertion = (needsNewlineBefore ? "\n" : "") + markdownImage + (needsNewlineAfter ? "\n" : "")

    textarea.value = before + insertion + after

    // Move cursor after insertion
    const newPos = start + insertion.length
    textarea.selectionStart = newPos
    textarea.selectionEnd = newPos
    textarea.focus()

    // Trigger input event for autosave and preview update
    textarea.dispatchEvent(new Event("input", { bubbles: true }))
  }

  async calculateChecksum(file) {
    return new Promise(function(resolve, reject) {
      var chunkSize = 2097152
      var chunks = Math.ceil(file.size / chunkSize)
      var currentChunk = 0
      var spark = new SparkMD5.ArrayBuffer()
      var fileReader = new FileReader()

      fileReader.onload = function(e) {
        spark.append(e.target.result)
        currentChunk++
        if (currentChunk < chunks) {
          loadNext()
        } else {
          var hexHash = spark.end()
          var binaryHash = []
          for (var i = 0; i < hexHash.length; i += 2) {
            binaryHash.push(parseInt(hexHash.substr(i, 2), 16))
          }
          resolve(btoa(String.fromCharCode.apply(null, binaryHash)))
        }
      }

      fileReader.onerror = function() {
        reject(new Error("Failed to read file"))
      }

      function loadNext() {
        var start = currentChunk * chunkSize
        var end = Math.min(start + chunkSize, file.size)
        fileReader.readAsArrayBuffer(file.slice(start, end))
      }

      loadNext()
    })
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      if (message) {
        this.statusTarget.classList.remove("hidden")
      } else {
        this.statusTarget.classList.add("hidden")
      }
    }
  }
}
