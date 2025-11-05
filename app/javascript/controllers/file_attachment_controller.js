import { Controller } from "@hotwired/stimulus"
import SparkMD5 from "spark-md5"

export default class extends Controller {
  static targets = ["fileInput", "attachmentsInput", "attachmentsList", "fileName"]
  static values = {
    stepIndex: String
  }

  connect() {
    // Load existing attachments on connect
    this.loadExistingAttachments()
  }

  async handleFileSelect(event) {
    const files = Array.from(event.target.files)
    if (files.length === 0) return
    
    // Upload files to Active Storage
    for (const file of files) {
      await this.uploadFile(file)
    }
    
    // Reset file input
    event.target.value = ""
  }

  async uploadFile(file) {
    try {
      console.log('Starting file upload for:', file.name)
      
      // Get direct upload URL from Rails
      // Rails 8 requires checksum for direct uploads
      const checksum = await this.calculateChecksum(file)
      
      const blobData = {
        filename: file.name,
        byte_size: file.size,
        content_type: file.type || 'application/octet-stream',
        checksum: checksum
      }
      
      console.log('Blob data:', blobData)
      
      const csrfToken = this.getCSRFToken()
      if (!csrfToken) {
        throw new Error('CSRF token not found. Please refresh the page.')
      }
      
      console.log('CSRF token found:', csrfToken.substring(0, 10) + '...')
      
      console.log('Sending POST request to /rails/active_storage/direct_uploads')
      const response = await fetch('/rails/active_storage/direct_uploads', {
        method: 'POST',
        credentials: 'same-origin', // Include cookies for authentication
        headers: {
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ blob: blobData })
      })
      
      console.log('Response status:', response.status, response.statusText)
      
      if (!response.ok) {
        const errorText = await response.text()
        // Try to extract error message from HTML error page
        const errorMatch = errorText.match(/<div class="exception_message">(.+?)<\/div>/s) || 
                          errorText.match(/<pre[^>]*>(.+?)<\/pre>/s) ||
                          errorText.match(/<h1[^>]*>(.+?)<\/h1>/s)
        const errorMessage = errorMatch ? errorMatch[1].replace(/<[^>]*>/g, '').trim() : errorText.substring(0, 200)
        
        console.error('Direct upload request failed:', {
          status: response.status,
          statusText: response.statusText,
          headers: Object.fromEntries(response.headers.entries()),
          errorMessage: errorMessage,
          fullBody: errorText.substring(0, 1000) // First 1000 chars for debugging
        })
        throw new Error(`Failed to get upload URL: ${response.status} ${response.statusText}. ${errorMessage}`)
      }
      
      const data = await response.json()
      
      if (!data.direct_upload || !data.direct_upload.url) {
        console.error('Invalid response:', data)
        throw new Error('Invalid response from server')
      }
      
      const uploadUrl = data.direct_upload.url
      const signedId = data.signed_id
      const uploadHeaders = data.direct_upload.headers || {}
      
      // Upload file to storage service
      // Use headers from Active Storage, but ensure Content-Type is set
      // Note: Active Storage provides the correct headers, so use them as-is
      const uploadResponse = await fetch(uploadUrl, {
        method: 'PUT',
        credentials: 'same-origin', // Include cookies for authentication
        headers: uploadHeaders,
        body: file
      })
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text()
        console.error('File upload failed:', uploadResponse.status, errorText)
        throw new Error(`Failed to upload file: ${uploadResponse.status} ${uploadResponse.statusText}`)
      }
      
      // Add signed ID to attachments list
      this.addAttachment(signedId, file.name)
      
    } catch (error) {
      console.error('File upload failed:', error)
      alert(`Failed to upload ${file.name}: ${error.message}`)
    }
  }

  async calculateChecksum(file) {
    // Calculate MD5 checksum in base64 format for Active Storage
    // Active Storage expects MD5 checksum as base64 string
    return new Promise((resolve, reject) => {
      const blobSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice
      const chunkSize = 2097152 // Read in chunks of 2MB
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
          // Convert hex MD5 to base64 (Rails expects base64)
          const hexHash = spark.end()
          // Convert hex string to binary, then to base64
          // MD5 produces 32 hex characters = 16 bytes
          const binaryHash = []
          for (let i = 0; i < hexHash.length; i += 2) {
            binaryHash.push(parseInt(hexHash.substr(i, 2), 16))
          }
          const base64Hash = btoa(String.fromCharCode(...binaryHash))
          resolve(base64Hash)
        }
      }
      
      fileReader.onerror = () => {
        reject(new Error('Failed to read file for checksum calculation'))
      }
      
      function loadNext() {
        const start = currentChunk * chunkSize
        const end = start + chunkSize >= file.size ? file.size : start + chunkSize
        fileReader.readAsArrayBuffer(blobSlice.call(file, start, end))
      }
      
      loadNext()
    })
  }

  addAttachment(signedId, fileName) {
    const attachments = this.getAttachments()
    attachments.push(signedId)
    this.updateAttachmentsInput(attachments)
    this.renderAttachmentItem(signedId, fileName)
    this.notifyPreviewUpdate()
  }

  removeAttachment(event) {
    const attachmentId = event.currentTarget.dataset.attachmentId
    const attachments = this.getAttachments()
    const index = attachments.indexOf(attachmentId)
    
    if (index > -1) {
      attachments.splice(index, 1)
      this.updateAttachmentsInput(attachments)
      
      // Remove from DOM
      const attachmentElement = this.attachmentsListTarget.querySelector(`[data-attachment-id="${attachmentId}"]`)
      if (attachmentElement) {
        attachmentElement.remove()
      }
      
      this.notifyPreviewUpdate()
    }
  }

  getAttachments() {
    const inputValue = this.attachmentsInputTarget.value
    if (!inputValue || inputValue === '[]') return []
    
    try {
      return JSON.parse(inputValue)
    } catch (e) {
      console.error('Failed to parse attachments:', e)
      return []
    }
  }

  updateAttachmentsInput(attachments) {
    this.attachmentsInputTarget.value = JSON.stringify(attachments)
    // Trigger input event for form tracking
    this.attachmentsInputTarget.dispatchEvent(new Event('input', { bubbles: true }))
  }

  renderAttachmentItem(signedId, fileName) {
    const itemHtml = `
      <div class="flex items-center justify-between p-2 bg-gray-50 rounded border" data-attachment-id="${signedId}">
        <div class="flex items-center gap-2">
          <span class="text-sm text-gray-700" data-file-name="${signedId}">${this.escapeHtml(fileName)}</span>
        </div>
        <button type="button" 
                class="text-red-500 hover:text-red-700 text-sm"
                data-action="click->file-attachment#removeAttachment"
                data-attachment-id="${signedId}">
          Remove
        </button>
      </div>
    `
    this.attachmentsListTarget.insertAdjacentHTML('beforeend', itemHtml)
  }

  async loadExistingAttachments() {
    const attachments = this.getAttachments()
    
    // Load file names for existing attachments
    for (const signedId of attachments) {
      const existingItem = this.attachmentsListTarget.querySelector(`[data-attachment-id="${signedId}"]`)
      if (existingItem) {
        const nameSpan = existingItem.querySelector(`[data-file-name="${signedId}"]`)
        if (nameSpan && nameSpan.textContent === 'Loading...') {
          // Try to get filename from server
          const fileName = await this.getFileName(signedId)
          nameSpan.textContent = fileName
        }
      } else {
        // Render new item
        const fileName = await this.getFileName(signedId)
        this.renderAttachmentItem(signedId, fileName)
      }
    }
  }

  async getFileName(signedId) {
    // Try to get file name from blob
    try {
      const blob = await fetch(`/rails/active_storage/blobs/${signedId}`).then(r => r.json())
      return blob.filename || 'File'
    } catch (error) {
      console.error('Failed to get filename:', error)
      return 'File'
    }
  }

  notifyPreviewUpdate() {
    // Dispatch event for preview updater
    this.element.dispatchEvent(new CustomEvent("workflow-steps-changed", { bubbles: true }))
    
    // Also trigger workflow builder update
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    if (workflowBuilder) {
      workflowBuilder.dispatchEvent(new CustomEvent("workflow:updated"))
    }
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

