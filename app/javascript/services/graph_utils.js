/**
 * Graph Utilities
 *
 * BFS-based traversal helpers for computing step depth and reachability
 * in graph-mode workflows.
 */

/**
 * BFS from startUuid, assign depth 0 to start, depth+1 to each connected node.
 * @param {Array<{id: string, transitions: Array<{target_uuid: string}>}>} steps
 * @param {string} startUuid
 * @returns {Map<string, number>} stepId → depth
 */
export function buildDepthMap(steps, startUuid) {
  const depthMap = new Map()
  if (!startUuid || !steps || steps.length === 0) return depthMap

  const stepById = new Map(steps.map(s => [s.id, s]))
  const queue = [{ id: startUuid, depth: 0 }]
  depthMap.set(startUuid, 0)

  while (queue.length > 0) {
    const { id, depth } = queue.shift()
    const step = stepById.get(id)
    if (!step || !step.transitions) continue

    for (const t of step.transitions) {
      if (t.target_uuid && !depthMap.has(t.target_uuid)) {
        depthMap.set(t.target_uuid, depth + 1)
        queue.push({ id: t.target_uuid, depth: depth + 1 })
      }
    }
  }

  return depthMap
}

/**
 * Returns the Set of step IDs not reachable from startUuid.
 * @param {Array<{id: string, transitions: Array<{target_uuid: string}>}>} steps
 * @param {string} startUuid
 * @returns {Set<string>}
 */
export function findOrphans(steps, startUuid) {
  const depthMap = buildDepthMap(steps, startUuid)
  const orphans = new Set()
  for (const step of steps) {
    if (!depthMap.has(step.id)) {
      orphans.add(step.id)
    }
  }
  return orphans
}
