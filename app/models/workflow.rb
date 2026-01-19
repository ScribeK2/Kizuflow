class Workflow < ApplicationRecord
  include WorkflowAuthorization
  include WorkflowNormalization

  belongs_to :user
  has_rich_text :description

  # Group associations
  has_many :group_workflows, dependent: :destroy
  has_many :groups, through: :group_workflows
  
  # Simulation associations
  has_many :simulations, dependent: :destroy

  # Steps stored as JSON - automatically serialized/deserialized
  validates :title, presence: true, length: { maximum: 255 }
  validates :user_id, presence: true
  validate :validate_steps
  validate :validate_workflow_size

  # Size limits to prevent DoS and ensure performance
  # These can be overridden via environment variables if needed
  MAX_STEPS = ENV.fetch("WORKFLOW_MAX_STEPS", 200).to_i
  MAX_STEP_TITLE_LENGTH = 500
  MAX_STEP_CONTENT_LENGTH = 50_000  # 50KB per step field
  MAX_TOTAL_STEPS_SIZE = 5_000_000  # 5MB total for steps JSON
  
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
    
    if user&.admin?
      # Admins see all workflows
      base_scope
    elsif user&.editor?
      # Editors see their own workflows + all public workflows + workflows in assigned groups
      if user.groups&.any?
        # Use optimized single-query method to get all accessible group IDs
        accessible_group_ids = Group.accessible_group_ids_for(user)
        # Use subquery to avoid DISTINCT on JSONB column - select only ID for distinct operation
        distinct_ids = base_scope.left_joins(:groups)
                                  .where("workflows.user_id = ? OR workflows.is_public = ? OR groups.id IN (?) OR groups.id IS NULL",
                                         user.id, true, accessible_group_ids)
                                  .select("DISTINCT workflows.id")
        base_scope.where(id: distinct_ids)
      else
        # No group assignments: own workflows + public workflows
        base_scope.where(user: user).or(base_scope.where(is_public: true))
      end
    else
      # Users: See public workflows + workflows in assigned groups + workflows without groups
      if user&.groups&.any?
        # Use optimized single-query method to get all accessible group IDs
        accessible_group_ids = Group.accessible_group_ids_for(user)
        # Public workflows OR workflows in user's groups OR workflows without groups
        public_workflows = base_scope.where(is_public: true)
        group_workflows = base_scope.joins(:groups).where(groups: { id: accessible_group_ids })
        workflows_without_groups = base_scope.left_joins(:groups).where(groups: { id: nil })
        base_scope.where(id: public_workflows.select(:id))
                   .or(base_scope.where(id: group_workflows.select(:id)))
                   .or(base_scope.where(id: workflows_without_groups.select(:id)))
      else
        # No group assignments: only public workflows + workflows without groups (backward compatibility)
        # Note: Workflows in Uncategorized group are NOT included for users without group assignments
        public_workflows = base_scope.where(is_public: true)
        workflows_without_groups = base_scope.left_joins(:groups).where(groups: { id: nil })
        base_scope.where(id: public_workflows.select(:id))
                   .or(base_scope.where(id: workflows_without_groups.select(:id)))
      end
    end
  }

  # Filter workflows by group (includes workflows in descendant groups)
  # If group is nil, returns workflows without groups (for backward compatibility)
  # 
  # Example: If "Customer Support" has child "Phone Support", 
  # in_group(Customer Support) returns workflows in both groups
  scope :in_group, ->(group) {
    return where.not(id: joins(:groups).select(:id)) if group.nil?
    
    # Get group and all its descendants using optimized method
    # This avoids N+1 queries by using a single efficient query
    descendant_ids = group.descendant_ids
    group_ids = [group.id] + descendant_ids
    # Use pluck to get distinct IDs, then query by those IDs
    # Unscope order to avoid PostgreSQL DISTINCT/ORDER BY conflict
    # This ensures we can pluck IDs without ORDER BY interfering
    distinct_ids = joins(:groups).where(groups: { id: group_ids }).unscope(:order).distinct.pluck(:id)
    where(id: distinct_ids)
  }
  
  # Search workflows by title and description (fuzzy matching)
  # Searches both title and description fields with case-insensitive queries
  # Uses ILIKE for PostgreSQL, LIKE for SQLite (which is case-insensitive by default)
  scope :search_by, ->(query) {
    return all if query.blank?
    
    search_term = "%#{query.strip}%"
    
    # Search in title
    title_matches = case_insensitive_like('title', search_term)
    
    # Search in description (plain text column)
    desc_matches = case_insensitive_like('description', search_term)
    
    # Also search in ActionText rich text content
    # Join with action_text_rich_texts to search rich text body
    like_op = connection.adapter_name.downcase.include?('postgresql') ? 'ILIKE' : 'LIKE'
    rich_text_matches = joins("LEFT JOIN action_text_rich_texts ON action_text_rich_texts.record_type = 'Workflow' AND action_text_rich_texts.record_id = workflows.id AND action_text_rich_texts.name = 'description'")
                       .where("action_text_rich_texts.body #{like_op} ?", search_term)
    
    # Combine all matches using OR - no need for distinct since we're selecting IDs
    where(id: title_matches.select(:id))
      .or(where(id: desc_matches.select(:id)))
      .or(where(id: rich_text_matches.select(:id)))
  }
  
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

  # Check if workflow is a draft
  def draft?
    status == 'draft'
  end

  # Check if workflow is published
  def published?
    status == 'published' || status.nil?
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

  # Group helper methods
  def primary_group
    group_workflows.find_by(is_primary: true)&.group || groups.first
  end

  def all_groups
    groups
  end

  # ============================================================================
  # ID-Based Step Reference Helpers (Sprint 1: Decision Step Revolution)
  # These methods support ID-based step references instead of title-based,
  # making workflows more robust when steps are renamed.
  # ============================================================================

  # Find a step by its ID
  # Returns the step hash or nil if not found
  def find_step_by_id(step_id)
    return nil unless steps.present? && step_id.present?
    steps.find { |step| step['id'] == step_id }
  end

  # Find a step by its title (for backward compatibility)
  # Returns the step hash or nil if not found
  def find_step_by_title(title)
    return nil unless steps.present? && title.present?
    steps.find { |step| step['title'] == title }
  end

  # Get step info for display purposes
  # Returns an array of hashes with id, title, type, and index
  def step_options_for_select
    return [] unless steps.present?
    
    steps.map.with_index do |step, index|
      next nil unless step.is_a?(Hash) && step['title'].present?
      
      {
        id: step['id'],
        title: step['title'],
        type: step['type'],
        index: index,
        display_name: "#{index + 1}. #{step['title']}",
        type_icon: step_type_icon(step['type'])
      }
    end.compact
  end

  # Get variables with their metadata (answer type, options) for condition builders
  # Returns an array of hashes with variable info
  def variables_with_metadata
    return [] unless steps.present?
    
    steps.select { |step| step['type'] == 'question' && step['variable_name'].present? }
         .map do |step|
           {
             name: step['variable_name'],
             title: step['title'],
             answer_type: step['answer_type'],
             options: step['options'] || [],
             display_name: "#{step['title']} (#{step['variable_name']})"
           }
         end
  end

  # Convert a step reference (title or ID) to ID
  # Used for migrating from title-based to ID-based references
  def resolve_step_reference_to_id(reference)
    return nil if reference.blank?
    
    # If it looks like a UUID, assume it's already an ID
    if reference.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      # Verify the ID exists
      return reference if find_step_by_id(reference)
    end
    
    # Otherwise, treat it as a title and find the corresponding ID
    step = find_step_by_title(reference)
    step&.dig('id')
  end

  # Convert a step reference (ID or title) to title for display
  # Used for displaying step references in the UI
  def resolve_step_reference_to_title(reference)
    return nil if reference.blank?
    
    # If it looks like a UUID, find the step and return its title
    if reference.match?(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      step = find_step_by_id(reference)
      return step['title'] if step
    end
    
    # Otherwise, it might already be a title (backward compatibility)
    # Verify the title exists
    step = find_step_by_title(reference)
    step ? reference : nil
  end

  # Migrate all step references in branches from title-based to ID-based
  # This is idempotent - safe to run multiple times
  def migrate_step_references_to_ids!
    return false unless steps.present?
    
    changed = false
    
    steps.each do |step|
      next unless step.is_a?(Hash) && step['type'] == 'decision'
      
      # Migrate branch paths
      if step['branches'].present? && step['branches'].is_a?(Array)
        step['branches'].each do |branch|
          path = branch['path'] || branch[:path]
          if path.present?
            new_id = resolve_step_reference_to_id(path)
            if new_id && new_id != path
              branch['path'] = new_id
              changed = true
            end
          end
        end
      end
      
      # Migrate else_path
      if step['else_path'].present?
        new_id = resolve_step_reference_to_id(step['else_path'])
        if new_id && new_id != step['else_path']
          step['else_path'] = new_id
          changed = true
        end
      end
      
      # Migrate legacy paths
      %w[true_path false_path].each do |path_key|
        if step[path_key].present?
          new_id = resolve_step_reference_to_id(step[path_key])
          if new_id && new_id != step[path_key]
            step[path_key] = new_id
            changed = true
          end
        end
      end
    end
    
    save if changed
    changed
  end

  # Get an emoji icon for a step type
  def step_type_icon(type)
    case type
    when 'question' then '❓'
    when 'decision' then '🔀'
    when 'action' then '⚡'
    when 'checkpoint' then '📍'
    else '📝'
    end
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
        end

        # Validate else_path (regardless of whether branches is present)
        if step['else_path'].present? && !step_titles.include?(step['else_path'])
          # For imports, mark as incomplete instead of error
          if step['_import_incomplete']
            step['_import_errors'] ||= []
            step['_import_errors'] << "'Else' path references non-existent step: #{step['else_path']}"
          else
            errors.add(:steps, "Step #{index + 1}: 'Else' path references non-existent step: #{step['else_path']}")
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
      # Note: simple_decision is a variant of decision used for yes/no routing
      unless %w[question decision simple_decision action checkpoint].include?(step['type'])
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

        # Validate jumps if present
        validate_jumps(step, step_num)

      when 'action'
        # Validate jumps if present
        validate_jumps(step, step_num)
        
        # Validate output_fields if present
        if step['output_fields'].present?
          unless step['output_fields'].is_a?(Array)
            errors.add(:steps, "Step #{step_num}: output_fields must be an array")
          else
            step['output_fields'].each_with_index do |field, field_index|
              unless field.is_a?(Hash)
                errors.add(:steps, "Step #{step_num}, Output Field #{field_index + 1}: must be a hash")
              else
                if field['name'].blank?
                  errors.add(:steps, "Step #{step_num}, Output Field #{field_index + 1}: name is required")
                end
                # Value is optional - can be empty or contain {{variable}} interpolation
              end
            end
          end
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
              
              # Normalize branch hash keys (convert symbols to strings)
              branch['condition'] = branch_condition if branch_condition.present?
              branch['path'] = branch_path if branch_path.present?
              
              # Remove symbol keys to avoid confusion
              branch.delete(:condition)
              branch.delete(:path)
              
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

        # Validate jumps if present (decision steps can use jumps instead of branches)
        validate_jumps(step, step_num)

      when 'action'
        # Action steps don't have required fields beyond title
        # But we could validate action_type if needed
      end
    end
    
    # Validate step references
    validate_step_references
  end

  def valid_condition_format?(condition)
    ConditionEvaluator.valid?(condition)
  end

  def validate_jumps(step, step_num)
    return unless step['jumps'].present?

    unless step['jumps'].is_a?(Array)
      errors.add(:steps, "Step #{step_num}: jumps must be an array")
      return
    end

    step['jumps'].each_with_index do |jump, jump_index|
      unless jump.is_a?(Hash)
        errors.add(:steps, "Step #{step_num}, Jump #{jump_index + 1}: must be an object")
        next
      end

      # Allow empty jumps (user is still configuring)
      if jump['condition'].present? || jump['next_step_id'].present?
        # If either field is present, both should be present
        if jump['condition'].blank?
          errors.add(:steps, "Step #{step_num}, Jump #{jump_index + 1}: condition is required when next_step_id is specified")
        end

        if jump['next_step_id'].blank?
          errors.add(:steps, "Step #{step_num}, Jump #{jump_index + 1}: next_step_id is required when condition is specified")
        end

        # Validate that next_step_id references a valid step
        if jump['next_step_id'].present?
          referenced_step = steps.find { |s| s['id'] == jump['next_step_id'] }
          if referenced_step.nil?
            errors.add(:steps, "Step #{step_num}, Jump #{jump_index + 1}: references non-existent step ID: #{jump['next_step_id']}")
          end
        end
      end
    end
  end

  # Validate workflow size limits to prevent DoS and ensure performance
  def validate_workflow_size
    return unless steps.present?

    # Check step count
    if steps.length > MAX_STEPS
      errors.add(:steps, "Workflow cannot exceed #{MAX_STEPS} steps (currently #{steps.length})")
      return  # Skip other validations if way too many steps
    end

    # Check total JSON size
    begin
      steps_json = steps.to_json
      if steps_json.bytesize > MAX_TOTAL_STEPS_SIZE
        size_mb = (steps_json.bytesize / 1_000_000.0).round(2)
        max_mb = (MAX_TOTAL_STEPS_SIZE / 1_000_000.0).round(2)
        errors.add(:steps, "Total workflow data is too large (#{size_mb}MB, max #{max_mb}MB)")
        return
      end
    rescue => e
      errors.add(:steps, "Invalid step data format")
      return
    end

    # Check individual step content sizes
    steps.each_with_index do |step, index|
      next unless step.is_a?(Hash)
      step_num = index + 1

      # Check title length
      if step['title'].present? && step['title'].to_s.length > MAX_STEP_TITLE_LENGTH
        errors.add(:steps, "Step #{step_num}: Title is too long (max #{MAX_STEP_TITLE_LENGTH} characters)")
      end

      # Check large text fields
      large_fields = %w[description question instructions checkpoint_message]
      large_fields.each do |field|
        if step[field].present? && step[field].to_s.bytesize > MAX_STEP_CONTENT_LENGTH
          size_kb = (step[field].to_s.bytesize / 1000.0).round(1)
          max_kb = (MAX_STEP_CONTENT_LENGTH / 1000.0).round(1)
          errors.add(:steps, "Step #{step_num}: #{field.humanize} is too large (#{size_kb}KB, max #{max_kb}KB)")
        end
      end

      # Check options array size (for multiple choice questions)
      if step['options'].is_a?(Array) && step['options'].length > 100
        errors.add(:steps, "Step #{step_num}: Too many options (max 100)")
      end

      # Check branches array size (for decision steps)
      if step['branches'].is_a?(Array) && step['branches'].length > 50
        errors.add(:steps, "Step #{step_num}: Too many branches (max 50)")
      end

      # Check jumps array size
      if step['jumps'].is_a?(Array) && step['jumps'].length > 50
        errors.add(:steps, "Step #{step_num}: Too many jumps (max 50)")
      end
    end
  end

end

