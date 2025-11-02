import { Controller } from "@hotwired/stimulus"

// Controller for rendering flow previews from template data
// Similar to flow_preview_controller but works with JSON data instead of form inputs
export default class extends Controller {
  static targets = ["canvas", "zoomLevel"]
  static values = {
    compact: Boolean
  }

  connect() {
    // Initialize zoom level
    this.zoomLevel = 1.0 // 100%
    this.canvasWidth = 0
    this.canvasHeight = 0
    
    // Load steps from script tag
    this.loadStepsFromScript()
    
    // Listen for render-preview event (triggered when modal opens)
    this.element.addEventListener('render-preview', () => {
      setTimeout(() => {
        this.render()
      }, 50)
    })
    
    // Keyboard shortcuts for zoom (only when modal is visible)
    this.boundKeyDown = this.handleKeyDown.bind(this)
    document.addEventListener('keydown', this.boundKeyDown)
    
    // Delay initial render to ensure DOM is ready
    // For modals, we'll render when modal opens (via event)
    // For inline previews, render immediately
    if (!this.element.closest('[id^="template-preview-modal-"]')) {
      setTimeout(() => {
        this.render()
      }, 100)
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundKeyDown)
  }

  handleKeyDown(event) {
    // Only handle keyboard shortcuts when this controller's modal is visible
    const modal = this.element.closest('[id^="template-preview-modal-"]')
    if (!modal || modal.classList.contains('hidden')) return
    
    // Check for Ctrl/Cmd + Plus (zoom in)
    if ((event.ctrlKey || event.metaKey) && (event.key === '+' || event.key === '=')) {
      event.preventDefault()
      this.zoomIn()
    }
    
    // Check for Ctrl/Cmd + Minus (zoom out)
    if ((event.ctrlKey || event.metaKey) && event.key === '-') {
      event.preventDefault()
      this.zoomOut()
    }
    
    // Check for Ctrl/Cmd + 0 (fit to screen)
    if ((event.ctrlKey || event.metaKey) && event.key === '0') {
      event.preventDefault()
      this.fitToScreen()
    }
  }


  // Load steps from script tag (safer than HTML attributes for complex JSON)
  loadStepsFromScript() {
    const scriptTag = this.element.querySelector('script[type="application/json"]')
    if (scriptTag) {
      try {
        const stepsJson = scriptTag.textContent.trim()
        this.stepsData = JSON.parse(stepsJson)
      } catch (e) {
        console.error('Error parsing template steps JSON:', e)
        this.stepsData = []
      }
    } else {
      this.stepsData = []
    }
  }

  // Parse steps from the loaded data
  parseSteps() {
    const stepsData = this.stepsData || []
    
    console.log('Parsing steps:', stepsData.length, 'steps found')
    
    return stepsData.map((step, index) => {
      return {
        type: step.type || step['type'] || '',
        title: step.title || step['title'] || `Step ${index + 1}`,
        index: index,
        condition: step.condition || step['condition'] || '',
        true_path: step.true_path || step['true_path'] || '',
        false_path: step.false_path || step['false_path'] || '',
        else_path: step.else_path || step['else_path'] || '',
        branches: step.branches || step['branches'] || []
      }
    }).filter(step => step.type) // Filter out steps without type
  }

  // Find step by title
  findStepByTitle(steps, title) {
    return steps.find(s => s.title === title)
  }

  // Build a map of connections (same logic as flow_preview_controller)
  buildConnections(steps) {
    const connections = []
    const decisionSteps = new Set()
    const branchTargets = new Set()
    
    // First, collect all decision branches
    steps.forEach((step) => {
      if (step.type === "decision") {
        decisionSteps.add(step.index)
        
        // Handle multi-branch format (new)
        if (step.branches && Array.isArray(step.branches) && step.branches.length > 0) {
          step.branches.forEach((branch, branchIndex) => {
            const branchPath = branch.path || branch['path']
            if (branchPath) {
              const targetStep = this.findStepByTitle(steps, branchPath)
              if (targetStep) {
                const branchColors = ["#10b981", "#3b82f6", "#f59e0b", "#8b5cf6", "#ec4899"]
                const color = branchColors[branchIndex % branchColors.length]
                const branchType = `branch_${branchIndex}`
                
                let label = branch.condition || branch['condition'] || `Branch ${branchIndex + 1}`
                if (label.length > 20) {
                  const match = label.match(/^(\w+)\s*(==|!=|>|<|>=|<=)/)
                  if (match) {
                    label = `${match[1]} ${match[2]}`
                  } else {
                    label = label.substring(0, 17) + "..."
                  }
                }
                
                connections.push({
                  from: step.index,
                  to: targetStep.index,
                  type: branchType,
                  label: label,
                  color: color
                })
                branchTargets.add(targetStep.index)
              }
            }
          })
          
          // Add else_path if present
          if (step.else_path) {
            const targetStep = this.findStepByTitle(steps, step.else_path)
            if (targetStep) {
              connections.push({
                from: step.index,
                to: targetStep.index,
                type: "else",
                label: "Else",
                color: "#6b7280"
              })
              branchTargets.add(targetStep.index)
            }
          }
        } else {
          // Legacy format (true_path/false_path)
          if (step.true_path) {
            const targetStep = this.findStepByTitle(steps, step.true_path)
            if (targetStep) {
              connections.push({
                from: step.index,
                to: targetStep.index,
                type: "true",
                label: "Yes"
              })
              branchTargets.add(targetStep.index)
            }
          }
          
          if (step.false_path) {
            const targetStep = this.findStepByTitle(steps, step.false_path)
            if (targetStep) {
              connections.push({
                from: step.index,
                to: targetStep.index,
                type: "false",
                label: "No"
              })
              branchTargets.add(targetStep.index)
            }
          }
        }
      }
    })
    
    // Then add default linear connections
    steps.forEach((step, index) => {
      if (index < steps.length - 1) {
        const nextStep = steps[index + 1]
        const isDecisionWithBranches = decisionSteps.has(step.index) && (
          (step.branches && step.branches.length > 0) || 
          step.true_path || 
          step.false_path || 
          step.else_path
        )
        const isBranchTarget = branchTargets.has(nextStep.index)
        
        if (!isDecisionWithBranches) {
          const isTargetFromOtherStep = isBranchTarget && nextStep.index !== index + 1
          if (!isTargetFromOtherStep) {
            connections.push({
              from: step.index,
              to: nextStep.index,
              type: "default",
              label: ""
            })
          }
        } else if (!(step.branches && step.branches.length > 0) && !step.true_path && !step.false_path && !step.else_path) {
          connections.push({
            from: step.index,
            to: nextStep.index,
            type: "default",
            label: ""
          })
        }
      }
    })
    
    return connections
  }

  // Render the flowchart
  render() {
    if (!this.hasCanvasTarget) return
    
    const steps = this.parseSteps()
    
    if (steps.length === 0) {
      this.canvasTarget.innerHTML = '<p class="text-gray-500 text-center py-4 text-sm">No steps in template</p>'
      return
    }
    
    // Get container width - wait longer for modal to be fully visible
    // Use requestAnimationFrame to ensure layout is complete
    requestAnimationFrame(() => {
      setTimeout(() => {
        const containerWidth = this.canvasTarget.offsetWidth || this.canvasTarget.parentElement?.offsetWidth || 800
        const connections = this.buildConnections(steps)
        const html = this.buildFlowchartHtml(steps, connections, containerWidth)
        this.canvasTarget.innerHTML = html
        
        // Store canvas dimensions for fit-to-screen calculation
        // Use setTimeout to ensure dimensions are measured after render
        setTimeout(() => {
          const canvasContent = this.canvasTarget.querySelector('.relative')
          if (canvasContent) {
            this.canvasWidth = canvasContent.offsetWidth || canvasContent.scrollWidth
            this.canvasHeight = canvasContent.offsetHeight || canvasContent.scrollHeight
            
            // Apply current zoom level
            this.applyZoom()
          }
        }, 10)
      }, 50)
    })
  }

  // Zoom in
  zoomIn() {
    this.zoomLevel = Math.min(this.zoomLevel + 0.1, 2.0) // Max 200%
    this.applyZoom()
  }

  // Zoom out
  zoomOut() {
    this.zoomLevel = Math.max(this.zoomLevel - 0.1, 0.25) // Min 25%
    this.applyZoom()
  }

  // Fit to screen
  fitToScreen() {
    if (!this.hasCanvasTarget || this.canvasWidth === 0 || this.canvasHeight === 0) {
      // If dimensions aren't available yet, try to get them
      const canvasContent = this.canvasTarget.querySelector('.relative')
      if (canvasContent) {
        this.canvasWidth = canvasContent.offsetWidth || canvasContent.scrollWidth
        this.canvasHeight = canvasContent.offsetHeight || canvasContent.scrollHeight
      }
    }
    
    if (this.canvasWidth === 0 || this.canvasHeight === 0) return
    
    const containerWidth = this.canvasTarget.offsetWidth - 40 // Account for padding
    const containerHeight = this.canvasTarget.offsetHeight - 40
    
    const widthZoom = containerWidth / this.canvasWidth
    const heightZoom = containerHeight / this.canvasHeight
    
    // Use the smaller zoom to fit both dimensions
    // Add a small margin (0.95) to ensure content isn't touching edges
    this.zoomLevel = Math.min(widthZoom, heightZoom, 1.0) * 0.95
    this.applyZoom()
  }

  // Apply zoom transform to canvas content
  applyZoom() {
    if (!this.hasCanvasTarget) return
    
    const canvasContent = this.canvasTarget.querySelector('.relative')
    if (canvasContent) {
      // Store original dimensions if not already stored
      if (!this.canvasWidth || !this.canvasHeight) {
        this.canvasWidth = canvasContent.offsetWidth || canvasContent.scrollWidth
        this.canvasHeight = canvasContent.offsetHeight || canvasContent.scrollHeight
      }
      
      // Apply zoom transform
      canvasContent.style.transform = `scale(${this.zoomLevel})`
      canvasContent.style.transformOrigin = 'top left'
      
      // Adjust container size to accommodate scaled content
      // This ensures scrolling works correctly
      const scaledWidth = this.canvasWidth * this.zoomLevel
      const scaledHeight = this.canvasHeight * this.zoomLevel
      
      // Update zoom level display
      if (this.hasZoomLevelTarget) {
        this.zoomLevelTarget.textContent = `${Math.round(this.zoomLevel * 100)}%`
      }
    }
  }

  // Build HTML for flowchart (compact or full version)
  buildFlowchartHtml(steps, connections, containerWidth = null) {
    const nodeWidth = this.compactValue ? 120 : 200
    const nodeHeight = this.compactValue ? 80 : 120
    const nodeMargin = this.compactValue ? 20 : 40
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    const positions = this.calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin)
    
    if (Object.keys(positions).length === 0) {
      return '<p class="text-gray-500 text-center py-4 text-sm">Unable to render flow preview</p>'
    }
    
    const positionValues = Object.values(positions)
    const maxX = Math.max(...positionValues.map(p => p.x + nodeWidth)) + nodeMargin
    const maxY = Math.max(...positionValues.map(p => p.y + nodeHeight)) + nodeMargin
    
    // Calculate canvas dimensions
    // For compact mode, constrain width to prevent overflow
    // For full-size modal preview, use full width
    const availableWidth = containerWidth || (this.compactValue && this.hasCanvasTarget 
      ? this.canvasTarget.offsetWidth || this.canvasTarget.parentElement?.offsetWidth || 400
      : maxX)
    const finalMaxX = this.compactValue ? Math.min(maxX, availableWidth - 20) : maxX
    
    // Build SVG for connections - use full width for modal, constrained for compact
    let svgHtml = `<svg class="absolute inset-0 pointer-events-none" style="width: ${finalMaxX}px; height: ${maxY}px; z-index: 0;">`
    
    connections.forEach(conn => {
      const fromPos = positions[conn.from]
      const toPos = positions[conn.to]
      
      if (!fromPos || !toPos) return
      
      const fromX = fromPos.x + nodeWidth
      const fromY = fromPos.y + nodeHeight / 2
      const toX = toPos.x
      const toY = toPos.y + nodeHeight / 2
      
      const dx = toX - fromX
      const dy = toY - fromY
      
      let path = ""
      let color = conn.color || "#6b7280"
      
      if (conn.type === "true") {
        color = "#10b981"
        const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = Math.max(fromY, toY) + controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type === "false") {
        color = "#ef4444"
        const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = Math.min(fromY, toY) - controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type.startsWith("branch_")) {
        const branchIndex = parseInt(conn.type.replace("branch_", "")) || 0
        const controlOffset = Math.min(60, Math.abs(dy) * 0.5) + (branchIndex * 30)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = branchIndex % 2 === 0 
          ? Math.max(fromY, toY) + controlOffset
          : Math.min(fromY, toY) - controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type === "else") {
        path = `M ${fromX} ${fromY} L ${toX} ${toY}`
      } else {
        path = `M ${fromX} ${fromY} L ${toX} ${toY}`
      }
      
      const colorName = color === "#10b981" ? "green" : color === "#ef4444" ? "red" : color.replace("#", "col")
      const arrowId = `arrowhead-${conn.type === "true" ? "green" : conn.type === "false" ? "red" : conn.type.startsWith("branch_") ? colorName : conn.type === "else" ? "gray" : "gray"}`
      
      const strokeDasharray = conn.type === "else" ? "5,5" : "none"
      svgHtml += `<path d="${path}" stroke="${color}" stroke-width="${this.compactValue ? 1.5 : 2}" fill="none" stroke-dasharray="${strokeDasharray}" marker-end="url(#${arrowId})"/>`
      
      if (conn.label && (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else")) {
        const labelX = (fromX + toX) / 2
        const labelY = (fromY + toY) / 2 - 5
        const labelText = this.escapeHtml(conn.label)
        const textLength = labelText.length * (this.compactValue ? 4 : 6)
        svgHtml += `
          <rect x="${labelX - textLength/2 - 4}" y="${labelY - 8}" width="${textLength + 8}" height="14" fill="white" opacity="0.8" rx="2"/>
          <text x="${labelX}" y="${labelY}" text-anchor="middle" fill="${color}" font-size="${this.compactValue ? 9 : 11}" font-weight="600">${labelText}</text>
        `
      }
    })
    
    svgHtml += `
      <defs>
        <marker id="arrowhead-gray" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#6b7280" />
        </marker>
        <marker id="arrowhead-green" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#10b981" />
        </marker>
        <marker id="arrowhead-red" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#ef4444" />
        </marker>
      </defs>
    </svg>`
    
    let nodesHtml = `<div class="relative" style="min-height: ${maxY}px; width: ${finalMaxX}px;">`
    nodesHtml += svgHtml
    
    steps.forEach((step, arrayIndex) => {
      const pos = positions[arrayIndex] || positions[step.index]
      if (!pos) return
      
      const bgColor = this.getStepColor(step.type)
      const borderColor = this.getStepBorderColor(step.type)
      const fontSize = this.compactValue ? "text-xs" : "text-sm"
      
      const padding = this.compactValue ? 8 : 12
      const badgeSize = this.compactValue ? 16 : 24
      const badgeSizeClass = this.compactValue ? 'text-xs' : 'text-xs'
      
      nodesHtml += `
        <div class="absolute workflow-node z-10" style="left: ${pos.x}px; top: ${pos.y}px; width: ${nodeWidth}px;" data-step-index="${step.index}">
          <div class="border-2 rounded-lg bg-white shadow-sm ${borderColor}" style="min-height: ${nodeHeight}px; padding: ${padding}px;">
            <div class="flex items-center mb-1">
              <span class="inline-flex items-center justify-center rounded-full ${badgeSizeClass} font-semibold ${bgColor} mr-2" style="width: ${badgeSize}px; height: ${badgeSize}px;">
                ${step.index + 1}
              </span>
              <span class="${fontSize} font-medium uppercase text-gray-600">${this.escapeHtml(step.type)}</span>
            </div>
            <h4 class="font-semibold ${fontSize} text-gray-900 mb-1 break-words" style="${this.compactValue ? 'display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;' : 'display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;'}">${this.escapeHtml(step.title)}</h4>
          </div>
        </div>
      `
    })
    
    nodesHtml += "</div>"
    return nodesHtml
  }

  // Calculate node positions (simplified for compact view)
  calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin) {
    const positions = {}
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    const branchTargets = new Set()
    connections.forEach(conn => {
      if (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else") {
        branchTargets.add(conn.to)
      }
    })
    
    let currentX = nodeMargin
    let currentY = nodeMargin
    let maxY = nodeMargin
    
    steps.forEach((step, index) => {
      const isBranchTarget = branchTargets.has(index)
      
      if (isBranchTarget && index > 0) {
        const existingY = currentY
        let foundY = false
        
        for (let i = 0; i < index; i++) {
          const existingPos = positions[i]
          if (existingPos && Math.abs(existingPos.x - currentX) < horizontalSpacing / 2) {
            currentY = Math.max(currentY, existingPos.y + verticalSpacing)
            foundY = true
          }
        }
        
        if (!foundY) {
          currentY = maxY + verticalSpacing
        }
      } else if (index > 0 && !isBranchTarget) {
        currentY = nodeMargin
      }
      
      positions[index] = { x: currentX, y: currentY }
      maxY = Math.max(maxY, currentY + nodeHeight)
      
      if (step.type === "decision") {
        currentX += horizontalSpacing * 1.5
      } else {
        currentX += horizontalSpacing
      }
    })
    
    return positions
  }

  getStepColor(type) {
    switch(type) {
      case "question": return "bg-blue-100 text-blue-800"
      case "decision": return "bg-green-100 text-green-800"
      case "action": return "bg-purple-100 text-purple-800"
      default: return "bg-gray-100 text-gray-800"
    }
  }

  getStepBorderColor(type) {
    switch(type) {
      case "question": return "border-blue-300"
      case "decision": return "border-green-300"
      case "action": return "border-purple-300"
      default: return "border-gray-300"
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

