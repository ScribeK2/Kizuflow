import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]

  connect() {
    // Delay initial render to ensure DOM is ready
    setTimeout(() => {
      this.render()
    }, 100)
    // Listen for updates from workflow builder
    this.setupUpdateListener()
  }

  setupUpdateListener() {
    // Listen for custom events from workflow builder
    document.addEventListener("workflow:updated", () => {
      this.render()
    })
    
    // Also listen for form changes
    const form = document.querySelector("form")
    if (form) {
      form.addEventListener("input", () => {
        clearTimeout(this.renderTimeout)
        this.renderTimeout = setTimeout(() => this.render(), 300)
      })
      
      form.addEventListener("change", () => {
        clearTimeout(this.renderTimeout)
        this.renderTimeout = setTimeout(() => this.render(), 300)
      })
    }
  }

  // Parse steps from the form
  parseSteps() {
    const steps = []
    // Find step items within the workflow builder container
    const workflowBuilder = document.querySelector("[data-controller*='workflow-builder']")
    const stepItems = workflowBuilder 
      ? workflowBuilder.querySelectorAll(".step-item")
      : document.querySelectorAll(".step-item")
    
    stepItems.forEach((stepItem, index) => {
      const typeInput = stepItem.querySelector("input[name*='[type]']")
      const titleInput = stepItem.querySelector("input[name*='[title]']")
      
      if (!typeInput || !titleInput) {
        console.warn(`Step ${index} missing type or title input`)
        return
      }
      
      const type = typeInput.value
      const title = titleInput.value.trim() || `Step ${index + 1}`
      
      // Skip if no type
      if (!type) return
      
      const step = {
        type: type,
        title: title,
        index: index
      }
      
      // Get type-specific fields
      if (type === "decision") {
        // Check for multi-branch format (branches array)
        const branchItems = stepItem.querySelectorAll('.branch-item')
        if (branchItems.length > 0) {
          step.branches = []
          branchItems.forEach(branchItem => {
            const conditionInput = branchItem.querySelector("input[name*='[branches][][condition]']")
            const pathSelect = branchItem.querySelector("select[name*='[branches][][path]']")
            if (conditionInput || pathSelect) {
              step.branches.push({
                condition: conditionInput ? conditionInput.value : "",
                path: pathSelect ? pathSelect.value : ""
              })
            }
          })
          
          // Get else_path
          const elsePathSelect = stepItem.querySelector("select[name*='[else_path]']")
          step.else_path = elsePathSelect ? elsePathSelect.value : ""
        } else {
          // Legacy format (true_path/false_path)
          const conditionInput = stepItem.querySelector("input[name*='[condition]']")
          const truePathSelect = stepItem.querySelector("select[name*='[true_path]']")
          const falsePathSelect = stepItem.querySelector("select[name*='[false_path]']")
          
          step.condition = conditionInput ? conditionInput.value : ""
          step.true_path = truePathSelect ? truePathSelect.value : ""
          step.false_path = falsePathSelect ? falsePathSelect.value : ""
        }
      } else if (type === "question") {
        const questionInput = stepItem.querySelector("input[name*='[question]']")
        step.question = questionInput ? questionInput.value : ""
      } else if (type === "action") {
        const instructionsInput = stepItem.querySelector("textarea[name*='[instructions]']")
        step.instructions = instructionsInput ? instructionsInput.value : ""
        
        // Get attachments
        const attachmentsInput = stepItem.querySelector("input[name*='[attachments]']")
        if (attachmentsInput && attachmentsInput.value) {
          try {
            step.attachments = JSON.parse(attachmentsInput.value)
          } catch (e) {
            step.attachments = []
          }
        } else {
          step.attachments = []
        }
      }
      
      steps.push(step)
    })
    
    return steps
  }

  // Find step by title
  findStepByTitle(steps, title) {
    return steps.find(s => s.title === title)
  }

  // Build a map of connections
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
            if (branch.path) {
              const targetStep = this.findStepByTitle(steps, branch.path)
              if (targetStep) {
                // Use different colors for different branches
                const branchColors = ["#10b981", "#3b82f6", "#f59e0b", "#8b5cf6", "#ec4899"]
                const color = branchColors[branchIndex % branchColors.length]
                const branchType = `branch_${branchIndex}`
                
                // Create a shorter label from the condition
                let label = branch.condition || `Branch ${branchIndex + 1}`
                // Truncate long labels or extract just the key part
                if (label.length > 20) {
                  // Try to extract just the variable and operator part
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
                color: "#6b7280" // gray
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
    // For each step, connect to the next step in sequence UNLESS:
    // 1. It's a decision step with branches defined (branches take priority)
    // 2. The next step is a branch target from a different step
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
        
        // Connect if:
        // - Not a decision with branches, OR
        // - Next step is not a branch target, OR  
        // - It's the immediate sequential step (index + 1)
        if (!isDecisionWithBranches) {
          // Always connect non-decision steps to next
          // Unless next step is a branch target from elsewhere (then skip)
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
          // Decision step with no branches - connect to next
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
      this.canvasTarget.innerHTML = '<p class="text-gray-500 text-center py-8">Add steps to see the flow preview</p>'
      return
    }
    
    const connections = this.buildConnections(steps)
    const html = this.buildFlowchartHtml(steps, connections)
    this.canvasTarget.innerHTML = html
  }

  // Build HTML for flowchart
  buildFlowchartHtml(steps, connections) {
    const nodeWidth = 200
    const nodeHeight = 120
    const nodeMargin = 40
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    // Calculate positions (simple horizontal layout, with vertical branches for decisions)
    const positions = this.calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin)
    
    // Safety check for empty positions
    if (Object.keys(positions).length === 0) {
      return '<p class="text-gray-500 text-center py-8">Unable to render flow preview</p>'
    }
    
    // Calculate canvas dimensions
    const positionValues = Object.values(positions)
    const maxX = Math.max(...positionValues.map(p => p.x + nodeWidth)) + nodeMargin
    const maxY = Math.max(...positionValues.map(p => p.y + nodeHeight)) + nodeMargin
    
    // Build SVG for connections
    let svgHtml = `<svg class="absolute inset-0 pointer-events-none" style="width: ${maxX}px; height: ${maxY}px; z-index: 0;">`
    
    connections.forEach(conn => {
      const fromPos = positions[conn.from]
      const toPos = positions[conn.to]
      
      if (!fromPos || !toPos) return
      
      // Calculate connection points - right edge of source, left edge of target (for horizontal layout)
      const fromX = fromPos.x + nodeWidth
      const fromY = fromPos.y + nodeHeight / 2
      const toX = toPos.x
      const toY = toPos.y + nodeHeight / 2
      
      // Distance between nodes
      const dx = toX - fromX
      const dy = toY - fromY
      
      let path = ""
      let color = conn.color || "#6b7280" // gray for default
      
      if (conn.type === "true") {
        color = "#10b981" // green
        // Curve downward to the right for "true" branch
        const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = Math.max(fromY, toY) + controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type === "false") {
        color = "#ef4444" // red
        // Curve upward to the left for "false" branch
        const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = Math.min(fromY, toY) - controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type.startsWith("branch_")) {
        // Multi-branch: curve vertically based on branch index
        const branchIndex = parseInt(conn.type.replace("branch_", "")) || 0
        const controlOffset = Math.min(60, Math.abs(dy) * 0.5) + (branchIndex * 30)
        const controlX = fromX + (toX - fromX) * 0.5
        // Alternate between upward and downward curves
        const controlY = branchIndex % 2 === 0 
          ? Math.max(fromY, toY) + controlOffset
          : Math.min(fromY, toY) - controlOffset
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else if (conn.type === "else") {
        // Else path: dashed line
        path = `M ${fromX} ${fromY} L ${toX} ${toY}`
      } else {
        // Straight horizontal line
        path = `M ${fromX} ${fromY} L ${toX} ${toY}`
      }
      
      // Create unique arrow ID based on color
      const colorName = color === "#10b981" ? "green" : color === "#ef4444" ? "red" : color.replace("#", "col")
      const arrowId = `arrowhead-${conn.type === "true" ? "green" : conn.type === "false" ? "red" : conn.type.startsWith("branch_") ? colorName : conn.type === "else" ? "gray" : "gray"}`
      
      // Use dashed line for else path
      const strokeDasharray = conn.type === "else" ? "5,5" : "none"
      svgHtml += `<path d="${path}" stroke="${color}" stroke-width="2" fill="none" stroke-dasharray="${strokeDasharray}" marker-end="url(#${arrowId})"/>`
      
      // Add label for decision branches only (not default sequential connections)
      if (conn.label && (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else")) {
        const labelX = (fromX + toX) / 2
        const labelY = (fromY + toY) / 2 - 5
        // Use a background rectangle for better readability
        const labelText = this.escapeHtml(conn.label)
        const textLength = labelText.length * 6 // approximate character width
        svgHtml += `
          <rect x="${labelX - textLength/2 - 4}" y="${labelY - 8}" width="${textLength + 8}" height="14" fill="white" opacity="0.8" rx="2"/>
          <text x="${labelX}" y="${labelY}" text-anchor="middle" fill="${color}" font-size="11" font-weight="600">${labelText}</text>
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
    
    // Build nodes
    let nodesHtml = `<div class="relative" style="min-height: ${maxY}px; width: ${maxX}px;">`
    
    // Add SVG first (behind nodes)
    nodesHtml += svgHtml
    
    steps.forEach((step, arrayIndex) => {
      // Use array index for position lookup (positions are keyed by array index)
      const pos = positions[arrayIndex] || positions[step.index]
      if (!pos) {
        console.warn(`No position found for step at index ${arrayIndex} (step.index: ${step.index}): ${step.title}`)
        return
      }
      
      const bgColor = this.getStepColor(step.type)
      const borderColor = this.getStepBorderColor(step.type)
      
      nodesHtml += `
        <div class="absolute workflow-node z-10" style="left: ${pos.x}px; top: ${pos.y}px; width: ${nodeWidth}px;" data-step-index="${step.index}">
          <div class="border-2 rounded-lg p-3 bg-white shadow-sm ${borderColor}" style="min-height: ${nodeHeight}px;">
            <div class="flex items-center mb-2">
              <span class="inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold ${bgColor} mr-2">
                ${step.index + 1}
              </span>
              <span class="text-xs font-medium uppercase text-gray-600">${this.escapeHtml(step.type)}</span>
            </div>
            <h4 class="font-semibold text-sm text-gray-900 mb-1 break-words">${this.escapeHtml(step.title)}</h4>
            ${step.type === "decision" && step.condition ? `<p class="text-xs text-gray-600 mt-1">${this.escapeHtml(step.condition)}</p>` : ""}
          </div>
        </div>
      `
    })
    
    nodesHtml += "</div>"
    
    return nodesHtml
  }

  // Calculate node positions (improved algorithm)
  calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin) {
    const positions = {}
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    // Track which steps are branch targets
    const branchTargets = new Set()
    connections.forEach(conn => {
      if (conn.type === "true" || conn.type === "false") {
        branchTargets.add(conn.to)
      }
    })
    
    // Simple horizontal layout with vertical offsets for branches
    let currentX = nodeMargin
    let currentY = nodeMargin
    let maxY = nodeMargin
    
    steps.forEach((step, index) => {
      // Check if this step is a target of a decision branch
      const isBranchTarget = branchTargets.has(index)
      
      if (isBranchTarget && index > 0) {
        // Offset vertically for branches - find a good Y position
        // Check if there's already a node at this X position
        const existingY = currentY
        let foundY = false
        
        // Try to place below existing nodes on this column
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
      } else if (index > 0) {
        // Reset Y for new main path (unless we're continuing a branch)
        if (!isBranchTarget) {
          currentY = nodeMargin
        }
      }
      
      positions[index] = { x: currentX, y: currentY }
      maxY = Math.max(maxY, currentY + nodeHeight)
      
      // Move to next column
      if (step.type === "decision") {
        // Decision nodes take more horizontal space
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

