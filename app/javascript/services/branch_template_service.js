/**
 * Branch Template Service
 * Provides pre-built branch templates for common scenarios
 */
export class BranchTemplateService {
  /**
   * Get all available templates
   */
  static getTemplates() {
    return [
      {
        id: 'yes_no',
        name: 'Yes/No Branch',
        description: 'Create two branches for Yes and No answers',
        icon: '✅',
        category: 'common',
        branches: [
          {
            condition: '',
            label: 'If Yes',
            path: ''
          },
          {
            condition: '',
            label: 'If No',
            path: ''
          }
        ],
        requiresVariable: true,
        requiresOptions: false
      },
      {
        id: 'multiple_choice',
        name: 'Multiple Choice Branch',
        description: 'Create branches for each option in a multiple choice question',
        icon: '📋',
        category: 'common',
        branches: [], // Will be populated dynamically based on options
        requiresVariable: true,
        requiresOptions: true
      },
      {
        id: 'numeric_range',
        name: 'Numeric Range Branch',
        description: 'Create branches for numeric ranges (low, medium, high)',
        icon: '🔢',
        category: 'numeric',
        branches: [
          {
            condition: '',
            label: 'Low (< 50)',
            path: ''
          },
          {
            condition: '',
            label: 'Medium (50-100)',
            path: ''
          },
          {
            condition: '',
            label: 'High (> 100)',
            path: ''
          }
        ],
        requiresVariable: true,
        requiresOptions: false,
        customizable: {
          ranges: [
            { label: 'Low', operator: '<', value: '50' },
            { label: 'Medium', operator: '>=', value: '50', operator2: '<=', value2: '100' },
            { label: 'High', operator: '>', value: '100' }
          ]
        }
      },
      {
        id: 'empty_check',
        name: 'Empty Check Branch',
        description: 'Check if a variable is empty or has a value',
        icon: '📝',
        category: 'common',
        branches: [
          {
            condition: '',
            label: 'If Empty',
            path: ''
          },
          {
            condition: '',
            label: 'If Has Value',
            path: ''
          }
        ],
        requiresVariable: true,
        requiresOptions: false
      }
    ]
  }
  
  /**
   * Get template by ID
   */
  static getTemplate(templateId) {
    return this.getTemplates().find(t => t.id === templateId)
  }
  
  /**
   * Generate branches from template
   * @param {string} templateId - Template ID
   * @param {string} variable - Variable name
   * @param {Array} options - Options for multiple choice (optional)
   * @param {Object} customizations - Custom values for template (optional)
   */
  static generateBranches(templateId, variable, options = [], customizations = {}) {
    const template = this.getTemplate(templateId)
    if (!template) return []
    
    if (!variable) {
      throw new Error('Variable is required')
    }
    
    switch (templateId) {
      case 'yes_no':
        return [
          {
            condition: `${variable} == 'Yes'`,
            label: 'If Yes',
            path: ''
          },
          {
            condition: `${variable} == 'No'`,
            label: 'If No',
            path: ''
          }
        ]
        
      case 'multiple_choice':
        if (!options || options.length === 0) {
          throw new Error('Options are required for multiple choice template')
        }
        return options.map(option => {
          const value = option.value || option.label || option
          const label = option.label || option.value || option
          return {
            condition: `${variable} == '${value}'`,
            label: `If "${label}"`,
            path: ''
          }
        })
        
      case 'numeric_range':
        const ranges = customizations.ranges || template.customizable.ranges
        return ranges.map(range => {
          let condition = ''
          if (range.operator2) {
            // Range condition (e.g., >= 50 && <= 100)
            condition = `${variable} >= ${range.value} && ${variable} <= ${range.value2}`
          } else {
            // Single condition
            condition = `${variable} ${range.operator} ${range.value}`
          }
          return {
            condition: condition,
            label: range.label,
            path: ''
          }
        })
        
      case 'empty_check':
        return [
          {
            condition: `${variable} == ''`,
            label: 'If Empty',
            path: ''
          },
          {
            condition: `${variable} != ''`,
            label: 'If Has Value',
            path: ''
          }
        ]
        
      default:
        return []
    }
  }
  
  /**
   * Get templates suitable for a variable
   * @param {string} variable - Variable name
   * @param {string} answerType - Answer type (yes_no, multiple_choice, number, etc.)
   * @param {Array} options - Options for multiple choice (optional)
   */
  static getSuitableTemplates(variable, answerType, options = []) {
    const allTemplates = this.getTemplates()
    
    return allTemplates.filter(template => {
      // Filter based on answer type
      if (answerType === 'yes_no' && template.id === 'yes_no') {
        return true
      }
      if (answerType === 'multiple_choice' && template.id === 'multiple_choice') {
        return true
      }
      if (answerType === 'number' && template.id === 'numeric_range') {
        return true
      }
      
      // Empty check works for any variable
      if (template.id === 'empty_check') {
        return true
      }
      
      // Show common templates by default
      if (template.category === 'common') {
        return true
      }
      
      return false
    })
  }
}

