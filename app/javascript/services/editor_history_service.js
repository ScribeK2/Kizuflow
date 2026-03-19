// EditorHistoryService: Manages undo/redo stacks for the visual editor.
// Stores deep-cloned snapshots of editor state. Max stack size is configurable.

export class EditorHistoryService {
  constructor(maxSnapshots = 50) {
    this.maxSnapshots = maxSnapshots
    this.undoStack = []
    this.redoStack = []
  }

  // Push a snapshot before a mutation. Clears redo stack.
  push(snapshot) {
    this.undoStack.push(structuredClone(snapshot))
    if (this.undoStack.length > this.maxSnapshots) {
      this.undoStack.shift()
    }
    this.redoStack = []
  }

  // Undo: push current state to redo, pop and return previous state from undo.
  undoWithCurrent(currentSnapshot) {
    if (this.undoStack.length === 0) return null
    this.redoStack.push(structuredClone(currentSnapshot))
    return this.undoStack.pop()
  }

  // Redo: push current state to undo, pop and return next state from redo.
  redoWithCurrent(currentSnapshot) {
    if (this.redoStack.length === 0) return null
    this.undoStack.push(structuredClone(currentSnapshot))
    return this.redoStack.pop()
  }

  get canUndo() {
    return this.undoStack.length > 0
  }

  get canRedo() {
    return this.redoStack.length > 0
  }

  clear() {
    this.undoStack = []
    this.redoStack = []
  }
}

export default EditorHistoryService
