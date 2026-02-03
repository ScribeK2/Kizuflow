// Shared FlowchartRenderer service for rendering workflow flowcharts
// Used by flow_preview_controller, template_flow_preview_controller, and wizard_flow_preview_controller

export class FlowchartRenderer {
  constructor(options = {}) {
    this.nodeWidth = options.nodeWidth || 200
    this.nodeHeight = options.nodeHeight || 120
    this.nodeMargin = options.nodeMargin || 40
    this.compact = options.compact || false
    this.darkMode = options.darkMode || false
    this.clickable = options.clickable || false
    this.arrowIdPrefix = options.arrowIdPrefix || ''
  }

  // Find step by title
  findStepByTitle(steps, title) {
    return steps.find(s => s.title === title)
  }

  // Find step by ID (for graph mode)
  findStepById(steps, id) {
    return steps.find(s => s.id === id)
  }

  // Check if workflow is in graph mode (steps have transitions arrays)
  isGraphMode(steps) {
    return steps.some(s => Array.isArray(s.transitions))
  }

  // Build a map of connections between steps
  buildConnections(steps) {
    // Check if this is a graph mode workflow
    if (this.isGraphMode(steps)) {
      return this.buildGraphConnections(steps)
    }
    return this.buildLinearConnections(steps)
  }

  // Build connections for graph mode workflows (using explicit transitions)
  buildGraphConnections(steps) {
    const connections = []
    const transitionColors = ["#6366f1", "#10b981", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899"]

    steps.forEach((step) => {
      if (!step.transitions || !Array.isArray(step.transitions)) return

      step.transitions.forEach((transition, tIndex) => {
        if (!transition.target_uuid) return

        const targetStep = this.findStepById(steps, transition.target_uuid)
        if (!targetStep) return

        const color = transitionColors[tIndex % transitionColors.length]
        const label = transition.label || transition.condition || ""

        connections.push({
          from: step.index,
          to: targetStep.index,
          type: transition.condition ? "conditional" : "default",
          label: label.length > 20 ? label.substring(0, 17) + "..." : label,
          color: transition.condition ? color : "#6b7280"
        })
      })
    })

    return connections
  }

  // Build connections for linear mode workflows (sequential + branches)
  buildLinearConnections(steps) {
    const connections = []
    const decisionSteps = new Set()
    const branchTargets = new Set()

    // First, collect all decision branches
    steps.forEach((step) => {
      if (step.type === "decision") {
        decisionSteps.add(step.index)

        // Handle multi-branch format
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

  // Calculate node positions
  calculatePositions(steps, connections) {
    const positions = {}
    const horizontalSpacing = this.nodeWidth + this.nodeMargin
    const verticalSpacing = this.nodeHeight + this.nodeMargin

    // Track branch targets
    const branchTargets = new Set()
    connections.forEach(conn => {
      if (conn.type === "true" || conn.type === "false" || conn.type.startsWith("branch_") || conn.type === "else") {
        branchTargets.add(conn.to)
      }
    })

    let currentX = this.nodeMargin
    let currentY = this.nodeMargin
    let maxY = this.nodeMargin

    steps.forEach((step, index) => {
      const isBranchTarget = branchTargets.has(index)

      if (isBranchTarget && index > 0) {
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
        currentY = this.nodeMargin
      }

      positions[index] = { x: currentX, y: currentY }
      maxY = Math.max(maxY, currentY + this.nodeHeight)

      if (step.type === "decision") {
        currentX += horizontalSpacing * 1.5
      } else {
        currentX += horizontalSpacing
      }
    })

    return positions
  }

  // Build SVG path for a connection
  buildConnectionPath(fromPos, toPos, connType, connIndex = 0) {
    const fromX = fromPos.x + this.nodeWidth
    const fromY = fromPos.y + this.nodeHeight / 2
    const toX = toPos.x
    const toY = toPos.y + this.nodeHeight / 2
    const dy = toY - fromY

    if (connType === "true") {
      const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
      const controlX = fromX + (toX - fromX) * 0.5
      const controlY = Math.max(fromY, toY) + controlOffset
      return `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
    } else if (connType === "false") {
      const controlOffset = Math.min(40, Math.abs(dy) * 0.5)
      const controlX = fromX + (toX - fromX) * 0.5
      const controlY = Math.min(fromY, toY) - controlOffset
      return `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
    } else if (connType.startsWith("branch_")) {
      const branchIndex = parseInt(connType.replace("branch_", "")) || 0
      const controlOffset = Math.min(60, Math.abs(dy) * 0.5) + (branchIndex * 30)
      const controlX = fromX + (toX - fromX) * 0.5
      const controlY = branchIndex % 2 === 0
        ? Math.max(fromY, toY) + controlOffset
        : Math.min(fromY, toY) - controlOffset
      return `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
    } else if (connType === "conditional") {
      // Graph mode conditional transition - curved path
      const controlOffset = Math.min(50, Math.abs(dy) * 0.5) + (connIndex * 20)
      const controlX = fromX + (toX - fromX) * 0.5
      const controlY = connIndex % 2 === 0
        ? Math.max(fromY, toY) + controlOffset
        : Math.min(fromY, toY) - controlOffset
      return `M ${fromX} ${fromY} Q ${controlX} ${controlY} ${toX} ${toY}`
    } else if (connType === "else") {
      return `M ${fromX} ${fromY} L ${toX} ${toY}`
    } else {
      return `M ${fromX} ${fromY} L ${toX} ${toY}`
    }
  }

  // Build SVG defs for arrowheads
  buildSvgDefs() {
    const prefix = this.arrowIdPrefix
    return `
      <defs>
        <marker id="${prefix}arrowhead-gray" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#6b7280" />
        </marker>
        <marker id="${prefix}arrowhead-green" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#10b981" />
        </marker>
        <marker id="${prefix}arrowhead-red" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#ef4444" />
        </marker>
        <marker id="${prefix}arrowhead-indigo" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#6366f1" />
        </marker>
        <marker id="${prefix}arrowhead-amber" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#f59e0b" />
        </marker>
        <marker id="${prefix}arrowhead-purple" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#8b5cf6" />
        </marker>
        <marker id="${prefix}arrowhead-pink" markerWidth="10" markerHeight="10" refX="0" refY="3" orient="auto" markerUnits="userSpaceOnUse">
          <polygon points="0 0, 10 3, 0 6" fill="#ec4899" />
        </marker>
      </defs>
    `
  }

  // Get arrow marker ID based on connection color
  getArrowId(conn) {
    const prefix = this.arrowIdPrefix
    if (conn.color === "#10b981" || conn.type === "true") return `${prefix}arrowhead-green`
    if (conn.color === "#ef4444" || conn.type === "false") return `${prefix}arrowhead-red`
    if (conn.color === "#6366f1") return `${prefix}arrowhead-indigo`
    if (conn.color === "#f59e0b") return `${prefix}arrowhead-amber`
    if (conn.color === "#8b5cf6") return `${prefix}arrowhead-purple`
    if (conn.color === "#ec4899") return `${prefix}arrowhead-pink`
    return `${prefix}arrowhead-gray`
  }

  // Build SVG for all connections
  buildConnectionsSvg(connections, positions, maxX, maxY) {
    const strokeWidth = this.compact ? 1.5 : 2
    const fontSize = this.compact ? 9 : 11
    const charWidth = this.compact ? 4 : 6

    let svgHtml = `<svg class="absolute inset-0 pointer-events-none" style="width: ${maxX}px; height: ${maxY}px; z-index: 0;">`
    svgHtml += this.buildSvgDefs()

    connections.forEach((conn, connIndex) => {
      const fromPos = positions[conn.from]
      const toPos = positions[conn.to]

      if (!fromPos || !toPos) return

      const fromX = fromPos.x + this.nodeWidth
      const fromY = fromPos.y + this.nodeHeight / 2
      const toX = toPos.x
      const toY = toPos.y + this.nodeHeight / 2

      const path = this.buildConnectionPath(fromPos, toPos, conn.type, connIndex)
      const color = conn.color || "#6b7280"
      const arrowId = this.getArrowId(conn)
      const strokeDasharray = conn.type === "else" ? "5,5" : "none"

      svgHtml += `<path d="${path}" stroke="${color}" stroke-width="${strokeWidth}" fill="none" stroke-dasharray="${strokeDasharray}" marker-end="url(#${arrowId})"/>`

      // Add label for branches and conditional connections
      const showLabel = conn.label && (
        conn.type === "true" ||
        conn.type === "false" ||
        conn.type.startsWith("branch_") ||
        conn.type === "else" ||
        conn.type === "conditional"
      )

      if (showLabel) {
        const labelX = (fromX + toX) / 2
        const labelY = (fromY + toY) / 2 - 5
        const labelText = this.escapeHtml(conn.label)
        const textLength = labelText.length * charWidth
        svgHtml += `
          <rect x="${labelX - textLength/2 - 4}" y="${labelY - 8}" width="${textLength + 8}" height="14" fill="white" opacity="0.9" rx="2"/>
          <text x="${labelX}" y="${labelY}" text-anchor="middle" fill="${color}" font-size="${fontSize}" font-weight="600">${labelText}</text>
        `
      }
    })

    svgHtml += `</svg>`
    return svgHtml
  }

  // Get step background color class
  getStepColorClass(type) {
    switch(type) {
      case "question": return "bg-blue-100 text-blue-800"
      case "decision": return "bg-green-100 text-green-800"
      case "action": return "bg-purple-100 text-purple-800"
      case "checkpoint": return "bg-orange-100 text-orange-800"
      case "sub_flow": return "bg-indigo-100 text-indigo-800"
      default: return "bg-gray-100 text-gray-800"
    }
  }

  // Get step border color class
  getStepBorderClass(type) {
    switch(type) {
      case "question": return "border-blue-300"
      case "decision": return "border-green-300"
      case "action": return "border-purple-300"
      case "checkpoint": return "border-orange-300"
      case "sub_flow": return "border-indigo-300"
      default: return "border-gray-300"
    }
  }

  // Get step color (hex)
  getStepColor(type) {
    const colors = {
      question: "#3b82f6",
      decision: "#10b981",
      action: "#8b5cf6",
      checkpoint: "#f59e0b",
      sub_flow: "#6366f1"
    }
    return colors[type] || "#6b7280"
  }

  // Build HTML for a single step node
  buildNodeHtml(step, pos, options = {}) {
    const bgColorClass = this.getStepColorClass(step.type)
    const borderClass = this.getStepBorderClass(step.type)
    const fontSize = this.compact ? "text-xs" : "text-sm"
    const padding = this.compact ? 8 : 12
    const badgeSize = this.compact ? 16 : 24

    const darkModeClasses = this.darkMode
      ? "dark:bg-gray-800 dark:text-gray-100"
      : ""

    const clickableAttrs = this.clickable
      ? `data-action="click->wizard-flow-preview#editStep" class="cursor-pointer hover:opacity-80 transition-opacity"`
      : ""

    const lineClamp = this.compact
      ? 'display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;'
      : 'display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden;'

    return `
      <div class="absolute workflow-node z-10 ${this.clickable ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''}"
           style="left: ${pos.x}px; top: ${pos.y}px; width: ${this.nodeWidth}px;"
           data-step-index="${step.index}"
           ${this.clickable ? `data-action="click->wizard-flow-preview#editStep"` : ''}>
        <div class="border-2 rounded-lg bg-white shadow-sm ${borderClass} ${darkModeClasses}"
             style="min-height: ${this.nodeHeight}px; padding: ${padding}px;">
          <div class="flex items-center mb-1">
            <span class="inline-flex items-center justify-center rounded-full ${fontSize} font-semibold ${bgColorClass} mr-2"
                  style="width: ${badgeSize}px; height: ${badgeSize}px;">
              ${step.index + 1}
            </span>
            <span class="${fontSize} font-medium uppercase text-gray-600">${this.escapeHtml(step.type || 'unknown')}</span>
          </div>
          <h4 class="font-semibold ${fontSize} text-gray-900 mb-1 break-words" style="${lineClamp}">
            ${this.escapeHtml(step.title || `Step ${step.index + 1}`)}
          </h4>
          ${step.type === "decision" && step.condition ? `<p class="${fontSize} text-gray-600 mt-1">${this.escapeHtml(step.condition)}</p>` : ""}
          ${this.clickable ? `<p class="text-xs text-gray-500 mt-2">Click to edit</p>` : ''}
        </div>
      </div>
    `
  }

  // Render the complete flowchart
  render(steps) {
    if (!steps || steps.length === 0) {
      return `<p class="text-gray-500 ${this.darkMode ? 'dark:text-gray-400' : ''} text-center py-8">No steps to preview</p>`
    }

    const connections = this.buildConnections(steps)
    const positions = this.calculatePositions(steps, connections)

    if (Object.keys(positions).length === 0) {
      return `<p class="text-gray-500 text-center py-8">Unable to render flow preview</p>`
    }

    // Calculate canvas dimensions
    const positionValues = Object.values(positions)
    const maxX = Math.max(...positionValues.map(p => p.x + this.nodeWidth)) + this.nodeMargin
    const maxY = Math.max(...positionValues.map(p => p.y + this.nodeHeight)) + this.nodeMargin

    // Build SVG and nodes
    let html = `<div class="relative" style="min-height: ${maxY}px; width: ${maxX}px;">`
    html += this.buildConnectionsSvg(connections, positions, maxX, maxY)

    steps.forEach((step, arrayIndex) => {
      const pos = positions[arrayIndex] || positions[step.index]
      if (!pos) return
      html += this.buildNodeHtml(step, pos)
    })

    html += "</div>"
    return html
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    if (!text) return ''
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

export default FlowchartRenderer
