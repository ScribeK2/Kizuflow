/**
 * Branch Suggestion Service
 * Analyzes workflow steps to suggest branches for decision steps
 */
export class BranchSuggestionService {
  /**
   * Analyze workflow and suggest branches for a decision step
   * @param {Array} workflowSteps - All workflow steps
   * @param {number} currentStepIndex - Index of the decision step being created
   * @returns {Array} Array of suggestion objects
   */
  static suggestBranches(workflowSteps, currentStepIndex) {
    const suggestions = []
    const previousSteps = workflowSteps.slice(0, currentStepIndex)
    
    // Find question steps above the current decision step
    const questionSteps = previousSteps.filter(step => step.type === 'question')
    
    if (questionSteps.length === 0) {
      return suggestions
    }
    
    // Analyze each question step and create suggestions
    questionSteps.forEach(questionStep => {
      const answerType = questionStep.answer_type || ''
      const variableName = questionStep.variable_name || questionStep.title
      const questionTitle = questionStep.title
      
      let suggestion = null
      
      switch (answerType) {
        case 'yes_no':
          suggestion = this.createYesNoSuggestion(questionStep, variableName, questionTitle)
          break
          
        case 'multiple_choice':
        case 'dropdown':
          suggestion = this.createMultipleChoiceSuggestion(questionStep, variableName, questionTitle)
          break
          
        case 'number':
          suggestion = this.createNumericSuggestion(questionStep, variableName, questionTitle)
          break
          
        default:
          // For text or unknown types, suggest a basic equals condition
          suggestion = this.createTextSuggestion(questionStep, variableName, questionTitle)
      }
      
      if (suggestion) {
        suggestions.push(suggestion)
      }
    })
    
    return suggestions
  }
  
  /**
   * Create suggestion for Yes/No questions
   */
  static createYesNoSuggestion(questionStep, variableName, questionTitle) {
    // Use variable name if available, otherwise use sanitized title
    const varName = variableName || questionTitle.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
    
    return {
      type: 'yes_no',
      title: `Branch based on "${questionTitle}"`,
      description: `Create branches for Yes and No answers`,
      variable: varName,
      questionTitle: questionTitle,
      branches: [
        {
          condition: `${varName} == 'Yes'`,
          label: 'If Yes',
          path: ''
        },
        {
          condition: `${varName} == 'No'`,
          label: 'If No',
          path: ''
        }
      ]
    }
  }
  
  /**
   * Create suggestion for Multiple Choice/Dropdown questions
   */
  static createMultipleChoiceSuggestion(questionStep, variableName, questionTitle) {
    const options = questionStep.options || []
    
    if (options.length === 0) {
      return null
    }
    
    // Use variable name if available, otherwise use sanitized title
    const varName = variableName || questionTitle.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
    
    const branches = options.map(option => {
      const value = option.value || option.label || option
      const label = option.label || option.value || option
      
      return {
        condition: `${varName} == '${value}'`,
        label: `If "${label}"`,
        path: ''
      }
    })
    
    return {
      type: 'multiple_choice',
      title: `Branch based on "${questionTitle}"`,
      description: `Create branches for each option (${options.length} branches)`,
      variable: varName,
      questionTitle: questionTitle,
      branches: branches
    }
  }
  
  /**
   * Create suggestion for Numeric questions
   */
  static createNumericSuggestion(questionStep, variableName, questionTitle) {
    // Use variable name if available, otherwise use sanitized title
    const varName = variableName || questionTitle.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
    
    return {
      type: 'numeric',
      title: `Branch based on "${questionTitle}"`,
      description: `Create numeric condition branches`,
      variable: varName,
      questionTitle: questionTitle,
      branches: [
        {
          condition: `${varName} < 50`,
          label: 'If Less Than 50',
          path: ''
        },
        {
          condition: `${varName} >= 50`,
          label: 'If 50 or More',
          path: ''
        }
      ]
    }
  }
  
  /**
   * Create suggestion for Text questions
   */
  static createTextSuggestion(questionStep, variableName, questionTitle) {
    // Use variable name if available, otherwise use sanitized title
    const varName = variableName || questionTitle.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '')
    
    return {
      type: 'text',
      title: `Branch based on "${questionTitle}"`,
      description: `Create text condition branch`,
      variable: varName,
      questionTitle: questionTitle,
      branches: [
        {
          condition: `${varName} == ''`,
          label: `If "${questionTitle}" is empty`,
          path: ''
        },
        {
          condition: `${varName} != ''`,
          label: `If "${questionTitle}" has value`,
          path: ''
        }
      ]
    }
  }
  
  /**
   * Get the most relevant suggestion (closest question step)
   */
  static getMostRelevantSuggestion(suggestions) {
    if (suggestions.length === 0) return null
    
    // Return the last suggestion (most recent question step)
    return suggestions[suggestions.length - 1]
  }
}

