import { Controller } from "@hotwired/stimulus"

// Wizard-specific flow preview controller for step3
// Reads steps from workflow data instead of form inputs
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    workflowId: Number,
    stepsData: Array
  }

  connect() {
    // Load steps from script tag (safer than HTML attributes for complex JSON)
    this.loadStepsFromScript()
    // Delay initial render to ensure DOM is ready
    setTimeout(() => {
      this.render()
    }, 100)
  }

  refresh() {
    this.loadStepsFromScript()
    this.render()
  }

  // Load steps from script tag (safer than HTML attributes for complex JSON)
  loadStepsFromScript() {
    const scriptTag = this.element.querySelector('script[type="application/json"]')
    if (scriptTag) {
      try {
        const stepsJson = scriptTag.textContent.trim()
        this.stepsDataValue = JSON.parse(stepsJson)
      } catch (e) {
        console.error('Error parsing workflow steps JSON:', e)
        console.error('Raw JSON:', scriptTag.textContent.substring(0, 200))
        this.stepsDataValue = []
      }
    } else {
      this.stepsDataValue = []
    }
  }

  // Get steps from the workflow data value
  getSteps() {
    if (!this.hasStepsDataValue || !this.stepsDataValue || this.stepsDataValue.length === 0) {
      return []
    }
    
    // Ensure steps have index property
    return this.stepsDataValue.map((step, index) => ({
      ...step,
      index: index
    }))
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
                const branchColors = ["#10b981", "#3b82f6", "#f59e0b", "#8b5cf6", "#ec4899"]
                const color = branchColors[branchIndex % branchColors.length]
                const branchType = `branch_${branchIndex}`
                
                let label = branch.condition || `Branch ${branchIndex + 1}`
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
                label: "Yes",
                color: "#10b981"
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
                label: "No",
                color: "#ef4444"
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
        }
      }
    })
    
    return connections
  }

  // Find step by title
  findStepByTitle(steps, title) {
    return steps.find(s => s.title === title)
  }

  // Get step color based on type
  getStepColor(type) {
    const colors = {
      question: "#3b82f6",    // blue
      decision: "#10b981",    // green
      action: "#8b5cf6",      // purple
      checkpoint: "#f59e0b"   // yellow
    }
    return colors[type] || "#6b7280" // gray default
  }

  // Get step icon based on type
  getStepIcon(type) {
    const icons = {
      question: "❓",
      decision: "🔀",
      action: "⚡",
      checkpoint: "📍"
    }
    return icons[type] || "●"
  }

  render() {
    const steps = this.getSteps()
    if (!steps || steps.length === 0) {
      this.canvasTarget.innerHTML = '<p class="text-gray-500 dark:text-gray-400 text-center py-8">No steps to preview. Add steps to see the flowchart.</p>'
      return
    }

    const connections = this.buildConnections(steps)
    const html = this.buildFlowchartHtml(steps, connections)
    this.canvasTarget.innerHTML = html
  }

  // Build HTML for flowchart with better layout
  buildFlowchartHtml(steps, connections) {
    const nodeWidth = 200
    const nodeHeight = 120
    const nodeMargin = 40
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    // Calculate positions (simple horizontal layout with vertical offsets for branches)
    const positions = this.calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin)
    
    if (Object.keys(positions).length === 0) {
      return '<p class="text-gray-500 dark:text-gray-400 text-center py-8">Unable to render flow preview</p>'
    }
    
    // Calculate canvas dimensions
    const positionValues = Object.values(positions)
    const maxX = Math.max(...positionValues.map(p => p.x + nodeWidth)) + nodeMargin
    const maxY = Math.max(...positionValues.map(p => p.y + nodeHeight)) + nodeMargin
    
    // Build SVG for connections
    let svgHtml = `<svg class="absolute inset-0 pointer-events-none" style="width: ${maxX}px; height: ${maxY}px; z-index: 0;">`
    svgHtml += `
      <defs>
        <marker id="wizard-arrowhead-gray" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#6b7280" />
        </marker>
        <marker id="wizard-arrowhead-green" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#10b981" />
        </marker>
        <marker id="wizard-arrowhead-red" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#ef4444" />
        </marker>
      </defs>
    `
    
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
        const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
        const controlX = fromX + (toX - fromX) * 0.5
        const controlY = (fromY + toY) / 2
        path = `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
      } else {
        path = `M ${fromX} ${fromY} L ${toX} ${toY}`
      }
      
      const arrowId = color === "#10b981" ? "wizard-arrowhead-green" : 
                      color === "#ef4444" ? "wizard-arrowhead-red" : 
                      "wizard-arrowhead-gray"
      const strokeDasharray = conn.type === "else" ? "5,5" : "none"
      
      svgHtml += `<path d="${path}" stroke="${color}" stroke-width="2" fill="none" stroke-dasharray="${strokeDasharray}" marker-end="url(#${arrowId})"/>`
      
      // Add label
      if (conn.label && (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else")) {
        const labelX = (fromX + toX) / 2
        const labelY = (fromY + toY) / 2 - 5
        const labelText = this.escapeHtml(conn.label)
        const textLength = labelText.length * 6
        svgHtml += `
          <rect x="${labelX - textLength/2 - 4}" y="${labelY - 8}" width="${textLength + 8}" height="14" fill="white" opacity="0.8" rx="2"/>
          <text x="${labelX}" y="${labelY}" text-anchor="middle" fill="${color}" font-size="11" font-weight="600">${labelText}</text>
        `
      }
    })
    
    svgHtml += `</svg>`
    
    // Build nodes
    let nodesHtml = `<div class="relative" style="min-height: ${maxY}px; width: ${maxX}px;">`
    nodesHtml += svgHtml
    
    steps.forEach((step, arrayIndex) => {
      const pos = positions[arrayIndex] || positions[step.index]
      if (!pos) return
      
      const bgColor = this.getStepColor(step.type)
      const icon = this.getStepIcon(step.type)
      
      nodesHtml += `
        <div class="absolute workflow-node z-10 cursor-pointer hover:opacity-80 transition-opacity" 
             style="left: ${pos.x}px; top: ${pos.y}px; width: ${nodeWidth}px;" 
             data-step-index="${step.index}"
             data-action="click->wizard-flow-preview#editStep">
          <div class="border-2 rounded-lg p-3 bg-white dark:bg-gray-800 shadow-sm" 
               style="border-color: ${bgColor}; min-height: ${nodeHeight}px;">
            <div class="flex items-center mb-2">
              <span class="inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold text-white mr-2" style="background-color: ${bgColor};">
                ${step.index + 1}
              </span>
              <span class="text-xs font-medium uppercase text-gray-600 dark:text-gray-400">${this.escapeHtml(step.type || 'unknown')}</span>
            </div>
            <h4 class="font-semibold text-sm text-gray-900 dark:text-gray-100 mb-1 break-words">${this.escapeHtml(step.title || `Step ${step.index + 1}`)}</h4>
            ${step.type === "decision" && step.condition ? `<p class="text-xs text-gray-600 dark:text-gray-400 mt-1">${this.escapeHtml(step.condition)}</p>` : ""}
            <p class="text-xs text-gray-500 dark:text-gray-500 mt-2">Click to edit</p>
          </div>
        </div>
      `
    })
    
    nodesHtml += "</div>"
    
    return nodesHtml
  }

  // Calculate node positions
  calculatePositions(steps, connections, nodeWidth, nodeHeight, nodeMargin) {
    const positions = {}
    const horizontalSpacing = nodeWidth + nodeMargin
    const verticalSpacing = nodeHeight + nodeMargin
    
    // Track branch targets
    const branchTargets = new Set()
    connections.forEach(conn => {
      if (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else") {
        branchTargets.add(conn.to)
      }
    })
    
    // Simple horizontal layout with vertical offsets for branches
    let currentX = nodeMargin
    let currentY = nodeMargin
    let maxY = nodeMargin
    
    steps.forEach((step, index) => {
      // If this step is a branch target, offset it vertically
      if (branchTargets.has(index) && index > 0) {
        currentY += verticalSpacing / 2
        maxY = Math.max(maxY, currentY)
      } else {
        // Reset Y for non-branch targets
        currentY = nodeMargin
      }
      
      positions[index] = { x: currentX, y: currentY }
      currentX += horizontalSpacing
    })
    
    return positions
  }

  editStep(event) {
    event.preventDefault()
    const stepIndex = parseInt(event.currentTarget.dataset.stepIndex)
    if (isNaN(stepIndex)) return
    
    const steps = this.getSteps()
    const step = steps[stepIndex]
    if (!step) return
    
    // Dispatch event to open step modal with the step data
    const editEvent = new CustomEvent("wizard-flow-preview:edit-step", {
      detail: { stepIndex, step, workflowId: this.workflowIdValue },
      bubbles: true
    })
    document.dispatchEvent(editEvent)
    
    // Also navigate to step2 as fallback
    const workflowId = this.workflowIdValue
    if (workflowId) {
      Turbo.visit(`/workflows/${workflowId}/step2#step-${stepIndex}`)
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}

