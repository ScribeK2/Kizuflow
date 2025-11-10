class Workflow < ApplicationRecord
  belongs_to :user
  has_rich_text :description

  # Group associations
  has_many :group_workflows, dependent: :destroy
  has_many :groups, through: :group_workflows

  # Steps stored as JSON - automatically serialized/deserialized
  validates :title, presence: true
  validates :user_id, presence: true
  validate :validate_steps
  
  # Normalize steps before validation to convert legacy format
  before_validation :normalize_steps_on_save
  # Clean up import flags when steps are completed
  before_save :cleanup_import_flags
  # Assign to Uncategorized group if no groups assigned (only for published workflows)
  after_create :assign_to_uncategorized_if_needed, if: -> { status == 'published' || status.nil? }

  scope :recent, -> { order(created_at: :desc) }
  scope :public_workflows, -> { where(is_public: true) }
  
  # Draft workflow scopes
  scope :drafts, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }
  scope :expired_drafts, -> { drafts.where('draft_expires_at < ?', Time.current) }
  
  # Set draft expiration before save (7 days from creation or update)
  before_save :set_draft_expiration, if: -> { status == 'draft' }
  
  # Get workflows visible to a specific user
  # Admins see all, Editors see own + public, Users see only public
  # Also respects group membership: users see workflows in their assigned groups
  # Handles workflows without groups gracefully (they're accessible to everyone)
  # 
  # Access Control Rules:
  # - Admins: See all workflows regardless of group assignment
  # - Editors: See their own workflows + all public workflows + workflows in assigned groups
  # - Users: See public workflows + workflows in assigned groups
  # - Workflows without groups: Accessible to all users (backward compatibility)
  # - Drafts: Excluded from main workflow list (only accessible via wizard routes)
  # 
  # Group Access:
  # - Users assigned to a parent group can see workflows in child groups
  # - Workflows are visible if user is assigned to any group containing the workflow
  scope :visible_to, ->(user) {
    # Exclude drafts from main workflow list
    base_scope = published
    
    base_scope = if user&.admin?
      base_scope
    elsif user&.editor?
      base_scope.where(user: user).or(base_scope.where(is_public: true))
    else
      base_scope.where(is_public: true)
    end

    # Filter by group membership if user has group assignments
    # But always include workflows without groups (backward compatibility)
    if user&.groups&.any?
      # Get all accessible group IDs (user's groups + all their descendants)
      # Optimized: Pre-load user groups to avoid N+1 queries
      user_group_ids = user.groups.pluck(:id)
      # Get all descendant IDs for each user group (could be optimized further with a recursive CTE)
      accessible_group_ids = user.groups.flat_map { |g| [g.id] + g.descendants.map(&:id) }
      base_scope.left_joins(:groups)
                 .where("workflows.is_public = ? OR workflows.user_id = ? OR groups.id IN (?) OR groups.id IS NULL", 
                        true, user.id, accessible_group_ids)
                 .distinct
    else
      # If user has no group assignments, show all workflows they have access to
      # (including workflows without groups for backward compatibility)
      base_scope
    end
  }

  # Filter workflows by group (includes workflows in descendant groups)
  # If group is nil, returns workflows without groups (for backward compatibility)
  # 
  # Example: If "Customer Support" has child "Phone Support", 
  # in_group(Customer Support) returns workflows in both groups
  scope :in_group, ->(group) {
    return where.not(id: joins(:groups).select(:id)) if group.nil?
    
    # Get group and all its descendants
    group_ids = [group.id] + group.descendants.map(&:id)
    joins(:groups).where(groups: { id: group_ids }).distinct
  }
  
  # Search workflows by title and description (fuzzy matching)
  # Searches both title and description fields with case-insensitive LIKE queries
  scope :search_by, ->(query) {
    return all if query.blank?
    
    search_term = "%#{query.strip}%"
    
    # Search in title
    title_matches = where("title LIKE ?", search_term)
    
    # Search in description (plain text column)
    desc_matches = where("description LIKE ?", search_term)
    
    # Also search in ActionText rich text content
    # Join with action_text_rich_texts to search rich text body
    rich_text_matches = joins("LEFT JOIN action_text_rich_texts ON action_text_rich_texts.record_type = 'Workflow' AND action_text_rich_texts.record_id = workflows.id AND action_text_rich_texts.name = 'description'")
                       .where("action_text_rich_texts.body LIKE ?", search_term)
    
    # Combine all matches using OR
    where(id: title_matches.select(:id))
      .or(where(id: desc_matches.select(:id)))
      .or(where(id: rich_text_matches.select(:id)))
      .distinct
  }
  
  # Check if a user can view this workflow
  def can_be_viewed_by?(user)
    return false unless user
    
    # Admins can view all workflows
    return true if user.admin?
    
    # Editors can view their own workflows + public workflows
    return true if user.editor? && (user == self.user || is_public?)
    
    # Users can only view public workflows
    is_public?
  end
  
  # Check if a user can edit this workflow
  def can_be_edited_by?(user)
    return false unless user
    
    # Admins can edit all workflows
    return true if user.admin?
    
    # Editors can edit their own workflows or public workflows created by other editors
    if user.editor?
      return true if user == self.user
      return true if is_public? && self.user.editor?
    end
    
    false
  end
  
  # Check if a user can delete this workflow
  def can_be_deleted_by?(user)
    return false unless user
    
    # Admins can delete all workflows
    return true if user.admin?
    
    # Editors can only delete their own workflows
    user.editor? && user == self.user
  end
  
  # Helper method to safely get description text (handles migration from text column to rich text)
  # This avoids triggering Active Storage initialization errors
  def description_text
    begin
      if description.present?
        description.to_plain_text
      elsif read_attribute(:description).present?
        read_attribute(:description)
      else
        nil
      end
    rescue => e
      # Fallback if Active Storage isn't configured or there's an error
      Rails.logger.warn("Error accessing description: #{e.message}")
      read_attribute(:description) || nil
    end
  end
  
  # Helper method to check if description exists (works with both text and rich text)
  def has_description?
    begin
      description.present? || read_attribute(:description).present?
    rescue
      read_attribute(:description).present?
    end
  end

  # Clean up import flags when steps are completed
  # Assign workflow to Uncategorized group if no groups are assigned
  def assign_to_uncategorized_if_needed
    return if groups.any?
    
    uncategorized_group = Group.uncategorized
    GroupWorkflow.find_or_create_by!(
      workflow: self,
      group: uncategorized_group,
      is_primary: true
    )
  end
  
  # Set draft expiration timestamp (7 days from now)
  def set_draft_expiration
    self.draft_expires_at = 7.days.from_now if status == 'draft'
  end
  
  # Class method to cleanup expired drafts
  # Can be called from a scheduled job
  def self.cleanup_expired_drafts
    expired_drafts.delete_all
  end

  def cleanup_import_flags
    return unless steps.present?
    
    self.steps = steps.map do |step|
      next step unless step.is_a?(Hash)
      
      # Check if step is now complete
      is_complete = case step['type']
      when 'question'
        step['question'].present?
      when 'decision'
        branches = step['branches'] || []
        branches.any? { |b| b['condition'].present? && b['path'].present? }
      when 'action'
        step['instructions'].present?
      else
        true
      end
      
      # Remove import flags if step is complete
      if is_complete && step['_import_incomplete']
        step.delete('_import_incomplete')
        step.delete('_import_errors')
      end
      
      step
    end
  end

  # Normalize steps to convert legacy format to new format
  # This ensures backward compatibility with old workflows
  # Called before validation to convert old format to new format
  def normalize_steps_on_save
    return unless steps.present?
    
    # Filter out completely empty steps (no type, no title, no data)
    # But preserve steps that have data even if type is missing (they're still being filled out)
    self.steps = steps.select { |step| 
      step.is_a?(Hash) && (
        step['type'].present? || 
        step['title'].present? || 
        step['description'].present? ||
        step['question'].present? ||
        step['action_type'].present? ||
        step['condition'].present?
      )
    }
    
    return unless steps.present?
    
    steps.each do |step|
      next unless step.is_a?(Hash) && step['type'] == 'decision'
      
      # Check if this step uses legacy format (has condition + true_path/false_path but no branches)
      has_legacy_format = step['condition'].present? && 
                         (step['true_path'].present? || step['false_path'].present?) &&
                         (step['branches'].blank? || (step['branches'].is_a?(Array) && step['branches'].empty?))
      
      if has_legacy_format
        # Convert to new multi-branch format
        step['branches'] = []
        
        # Add true_path as a branch
        if step['true_path'].present?
          step['branches'] << {
            'condition' => step['condition'],
            'path' => step['true_path']
          }
        end
        
        # Add false_path as else_path
        if step['false_path'].present?
          step['else_path'] = step['false_path']
        end
        
        # Note: We keep the legacy fields (condition, true_path, false_path) for now
        # to ensure backward compatibility. They can be removed in a future migration.
      end
    end
  end
  
  # Get normalized steps (for reading/display)
  # This method normalizes steps on read without modifying the database
  def normalized_steps
    return [] unless steps.present?
    
    steps.map do |step|
      next step unless step.is_a?(Hash) && step['type'] == 'decision'
      
      # Check if needs normalization
      has_legacy_format = step['condition'].present? && 
                         (step['true_path'].present? || step['false_path'].present?) &&
                         (step['branches'].blank? || (step['branches'].is_a?(Array) && step['branches'].empty?))
      
      if has_legacy_format
        # Create a copy to avoid modifying the original
        normalized_step = step.dup
        
        # Convert to new format
        normalized_step['branches'] = []
        
        if normalized_step['true_path'].present?
          normalized_step['branches'] << {
            'condition' => normalized_step['condition'],
            'path' => normalized_step['true_path']
          }
        end
        
        if normalized_step['false_path'].present?
          normalized_step['else_path'] = normalized_step['false_path']
        end
        
        normalized_step
      else
        step
      end
    end
  end

  # Extract all variable names from question steps
  def variables
    return [] unless steps.present?
    
    steps.select { |step| step['type'] == 'question' && step['variable_name'].present? }
        .map { |step| step['variable_name'] }
        .compact
        .uniq
  end

  # Group helper methods
  def primary_group
    group_workflows.find_by(is_primary: true)&.group || groups.first
  end

  def all_groups
    groups
  end

  # Validate step references (e.g., decision steps reference valid step titles)
  def validate_step_references
    return true unless steps.present?
    
    step_titles = steps.map { |step| step['title'] }.compact
    
    steps.each_with_index do |step, index|
      # Skip validation for imported incomplete steps
      next if step['_import_incomplete'] == true
      
      if step['type'] == 'decision'
        # Handle multi-branch format (new)
        if step['branches'].present? && step['branches'].is_a?(Array)
          step['branches'].each_with_index do |branch, branch_index|
            branch_path = branch['path'] || branch[:path]
            branch_condition = branch['condition'] || branch[:condition]
            
            if branch_path.present? && !step_titles.include?(branch_path)
              # For imports, mark as incomplete instead of error
              if step['_import_incomplete']
                step['_import_errors'] ||= []
                step['_import_errors'] << "Branch #{branch_index + 1}: References non-existent step: #{branch_path}"
              else
                errors.add(:steps, "Step #{index + 1}, Branch #{branch_index + 1}: References non-existent step: #{branch_path}")
              end
            end
            
            if branch_condition.present? && !valid_condition_format?(branch_condition)
              errors.add(:steps, "Step #{index + 1}, Branch #{branch_index + 1}: Invalid condition format")
            end
          end
          
          # Validate else_path
          if step['else_path'].present? && !step_titles.include?(step['else_path'])
            # For imports, mark as incomplete instead of error
            if step['_import_incomplete']
              step['_import_errors'] ||= []
              step['_import_errors'] << "'Else' path references non-existent step: #{step['else_path']}"
            else
              errors.add(:steps, "Step #{index + 1}: 'Else' path references non-existent step: #{step['else_path']}")
            end
          end
        end
        
        # Handle legacy format (true_path/false_path)
        if step['true_path'].present? && !step_titles.include?(step['true_path'])
          errors.add(:steps, "Step #{index + 1}: 'If true' references non-existent step: #{step['true_path']}")
        end
        
        if step['false_path'].present? && !step_titles.include?(step['false_path'])
          errors.add(:steps, "Step #{index + 1}: 'If false' references non-existent step: #{step['false_path']}")
        end
      end
    end
    
    errors.empty?
  end

  # Convert workflow to template format
  # Returns a hash with template attributes
  def convert_to_template(name: nil, category: nil, description: nil, is_public: true)
    {
      name: name || title,
      description: description || description_text,
      category: category || "custom",
      workflow_data: steps || [],
      is_public: is_public
    }
  end

  private

  def validate_steps
    return unless steps.present?
    
    # Filter out steps with empty type (they're incomplete and shouldn't be validated)
    # This prevents errors when users are still filling out forms
    valid_steps = steps.select { |step| step.is_a?(Hash) && step['type'].present? && step['type'].strip.present? }
    
    valid_steps.each_with_index do |step, index|
      step_num = index + 1
      
      # Skip validation for imported incomplete steps (they'll be fixed by the user)
      next if step['_import_incomplete'] == true
      
      # Validate step has required fields
      unless step.is_a?(Hash)
        errors.add(:steps, "Step #{step_num}: Invalid step format")
        next
      end
      
      # Validate step type
      unless %w[question decision action checkpoint].include?(step['type'])
        errors.add(:steps, "Step #{step_num}: Invalid step type '#{step['type']}'")
        next
      end
      
      # Validate title (required for all steps)
      if step['title'].blank?
        errors.add(:steps, "Step #{step_num}: Title is required")
      end
      
      # Type-specific validation
      case step['type']
      when 'question'
        if step['question'].blank?
          errors.add(:steps, "Step #{step_num}: Question text is required")
        end
        
      when 'decision'
        # Check if using multi-branch format or legacy format
        has_branches = step['branches'].present? && step['branches'].is_a?(Array) && step['branches'].length > 0
        
        if has_branches
          # Multi-branch format: validate branches
          # Filter out completely empty branches first
          step['branches'].reject! { |b| (b['condition'] || b[:condition]).blank? && (b['path'] || b[:path]).blank? }
          
          # If after filtering we have no branches, allow it (user removed all branches)
          if step['branches'].empty?
            # Allow empty branches - user can add them later
            # Don't require branches for decision steps - they can be incomplete
          else
            step['branches'].each_with_index do |branch, branch_index|
              branch_condition = branch['condition'] || branch[:condition]
              branch_path = branch['path'] || branch[:path]
              
              # Allow completely empty branches (user is still filling them out)
              # Only validate if at least one field is set (meaning user is trying to use this branch)
              if branch_condition.present? || branch_path.present?
                # If either is set, both must be set
                if branch_condition.blank?
                  errors.add(:steps, "Step #{step_num}, Branch #{branch_index + 1}: Condition is required when a path is selected")
                end
                
                if branch_path.blank?
                  errors.add(:steps, "Step #{step_num}, Branch #{branch_index + 1}: Path is required when a condition is set")
                end
                
                # Validate condition syntax only if condition is provided
                if branch_condition.present? && !valid_condition_format?(branch_condition)
                  errors.add(:steps, "Step #{step_num}, Branch #{branch_index + 1}: Invalid condition format")
                end
              end
            end
          end
        else
          # Legacy format: only validate if condition is present (don't require it)
          # Allow decision steps without conditions/branches (user can add them later)
          if step['condition'].present? && !valid_condition_format?(step['condition'])
            errors.add(:steps, "Step #{step_num}: Invalid condition format. Use: variable == 'value' or variable != 'value'")
          end
        end
        
      when 'action'
        # Action steps don't have required fields beyond title
        # But we could validate action_type if needed
      end
    end
    
    # Validate step references
    validate_step_references
  end

  def valid_condition_format?(condition)
    return false if condition.blank?
    
    # Basic condition syntax validation
    valid_patterns = [
      /^\w+\s*==\s*['"][^'"]*['"]/,  # variable == 'value'
      /^\w+\s*!=\s*['"][^'"]*['"]/,  # variable != 'value'
      /^\w+\s*>\s*\d+/,              # variable > 10
      /^\w+\s*<\s*\d+/,              # variable < 10
      /^\w+\s*>=\s*\d+/,             # variable >= 10
      /^\w+\s*<=\s*\d+/,             # variable <= 10
    ]
    
    valid_patterns.any? { |pattern| pattern.match?(condition.strip) }
  end
end

