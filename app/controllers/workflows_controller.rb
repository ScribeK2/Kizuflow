class WorkflowsController < ApplicationController
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :export, :export_pdf, :preview, :variables, :save_as_template, :start, :begin_execution, :step1, :update_step1, :step2, :update_step2, :step3, :create_from_draft, :render_step]
  before_action :ensure_draft_workflow!, only: [:step1, :update_step1, :step2, :update_step2, :step3, :create_from_draft]
  before_action :ensure_editor_or_admin!, only: [:new, :create, :import, :import_file]
  before_action :ensure_can_view_workflow!, only: [:show, :export, :export_pdf, :start, :begin_execution]
  before_action :ensure_can_edit_workflow!, only: [:edit, :update, :save_as_template]
  before_action :ensure_can_delete_workflow!, only: [:destroy]

  def index
    # Eager load associations to prevent N+1 queries (especially important for caching)
    @workflows = Workflow.visible_to(current_user)
                         .includes(:user, :rich_text_description)
                         .search_by(params[:search])
                         .recent

    # Filter by group if selected
    if params[:group_id].present?
      begin
        # Check access first with a simple query
        potential_group = Group.find_by(id: params[:group_id])
        if potential_group && potential_group.can_be_viewed_by?(current_user)
          # Eager load ancestors to prevent N+1 queries in breadcrumb rendering
          # Load up to 5 levels deep (max depth) to cover all ancestors
          @selected_group = Group.includes(parent: { parent: { parent: { parent: :parent } } }).find_by(id: params[:group_id])
          @workflows = @workflows.in_group(@selected_group)
        else
          @selected_group = nil
          flash.now[:alert] = "You don't have permission to view this group."
        end
      rescue => e
        Rails.logger.error "Error loading group #{params[:group_id]}: #{e.message}\n#{e.backtrace.join("\n")}"
        @selected_group = nil
        flash.now[:alert] = "An error occurred while loading the group."
      end
    end

    # Load accessible groups for sidebar
    # If no groups exist, show all workflows (backward compatibility)
    # Eager load children to prevent N+1 queries when rendering the tree
    @accessible_groups = Group.visible_to(current_user)
                               .roots
                               .includes(:children)
                               .order(:position, :name)
    
    # Fallback: if no groups exist at all, don't filter by groups
    if @accessible_groups.empty? && !current_user&.admin?
      # For non-admins with no groups, show all workflows they have access to
      # (this maintains backward compatibility)
    end

    @search_query = params[:search]
  end

  def show
  end

  def new
    # Create a draft workflow and redirect to wizard step 1
    @workflow = current_user.workflows.build(status: 'draft', title: 'Untitled Workflow')
    if @workflow.save
      redirect_to step1_workflow_path(@workflow), notice: "Let's create your workflow step by step."
    else
      # Fallback: if draft creation fails, show traditional form
      @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @workflow = current_user.workflows.build(workflow_params)
    
    if @workflow.save
      # Assign groups if provided
      if params[:workflow][:group_ids].present?
        group_ids = Array(params[:workflow][:group_ids]).reject(&:blank?)
        group_ids.each_with_index do |group_id, index|
          @workflow.group_workflows.create!(
            group_id: group_id,
            is_primary: index == 0  # First group is primary
          )
        end
      end
      
      redirect_to @workflow, notice: "Workflow was successfully created."
    else
      # Eager load groups to prevent N+1 queries
      @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Eager load groups to prevent N+1 queries
    @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
    @selected_group_ids = @workflow.group_ids
  end

  def update
    # Get client's lock_version for optimistic locking
    client_lock_version = params[:workflow][:lock_version].to_i if params[:workflow][:lock_version].present?
    
    begin
      Workflow.transaction do
        # Check for version conflict if client sent a lock_version
        if client_lock_version.present? && client_lock_version > 0
          if @workflow.lock_version != client_lock_version
            @workflow.errors.add(:base, "This workflow was modified by another user. Please refresh and try again.")
            raise ActiveRecord::StaleObjectError.new(@workflow, "update")
          end
        end
        
        if @workflow.update(workflow_params)
          # Update group assignments
          if params[:workflow][:group_ids].present?
            @workflow.group_workflows.destroy_all
            group_ids = Array(params[:workflow][:group_ids]).reject(&:blank?)
            group_ids.each_with_index do |group_id, index|
              @workflow.group_workflows.create!(
                group_id: group_id,
                is_primary: index == 0
              )
            end
          elsif params[:workflow].key?(:group_ids)
            # Explicitly clear groups if group_ids is present but empty
            @workflow.group_workflows.destroy_all
          end
          
          redirect_to @workflow, notice: "Workflow was successfully updated."
        else
          raise ActiveRecord::Rollback
        end
      end
    rescue ActiveRecord::StaleObjectError
      @workflow.reload
      @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
      @selected_group_ids = @workflow.group_ids
      @conflict_detected = true
      flash.now[:alert] = "This workflow was modified by another user. Your changes could not be saved. Please review the current version and try again."
      render :edit, status: :conflict
      return
    end
    
    # Handle validation errors (when update returns false)
    unless performed?
      @accessible_groups = Group.visible_to(current_user).order(:name)
      @selected_group_ids = @workflow.group_ids
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workflow.destroy
    redirect_to workflows_path, notice: "Workflow was successfully deleted."
  end

  def export
    send_data @workflow.to_json(except: [:id, :user_id, :status, :draft_expires_at]), 
              filename: "#{@workflow.title.parameterize}.json",
              type: "application/json"
  end

  def export_pdf
    require "prawn"
    
    pdf = Prawn::Document.new
    pdf.text @workflow.title, size: 24, style: :bold
    pdf.move_down 10
    pdf.text @workflow.description_text, size: 12 if @workflow.description_text.present?
    pdf.move_down 20

    if @workflow.steps.present?
      @workflow.steps.each_with_index do |step, index|
        pdf.text "#{index + 1}. #{step['title']}", size: 14, style: :bold
        pdf.text step['description'], size: 10 if step['description'].present?
        pdf.move_down 10
      end
    end

    send_data pdf.render, filename: "#{@workflow.title.parameterize}.pdf", type: "application/pdf"
  end

  def preview
    # Parse step data from params
    step_data = parse_step_from_params
    step_index = params[:step_index].to_i
    
    # Generate sample variables for interpolation preview
    # This allows users to see what variables will look like when interpolated
    sample_variables = generate_sample_variables(@workflow)
    
    # Render preview partial within Turbo Frame
    render partial: "workflows/preview_pane", 
           locals: { step: step_data, index: step_index, sample_variables: sample_variables },
           formats: [:html]
  end

  def variables
    # Return available variables from workflow
    variables = @workflow.variables
    
    render json: { variables: variables }
  end

  # Sprint 3: Render step HTML for dynamic step creation
  # This allows the JavaScript to request server-rendered HTML for new steps,
  # ensuring all the new Sprint 2/3 features are included
  def render_step
    step_type = params[:step_type]
    step_index = params[:step_index].to_i
    step_data = params[:step_data] || {}
    
    # Build a step hash from the parameters
    step = {
      'id' => SecureRandom.uuid,
      'type' => step_type,
      'title' => step_data[:title] || '',
      'description' => step_data[:description] || ''
    }
    
    # Add type-specific fields
    case step_type
    when 'question'
      step['question'] = step_data[:question] || ''
      step['answer_type'] = step_data[:answer_type] || 'yes_no'
      step['variable_name'] = step_data[:variable_name] || ''
      step['options'] = step_data[:options] || []
    when 'decision'
      step['branches'] = step_data[:branches] || []
      step['else_path'] = step_data[:else_path] || ''
    when 'action'
      step['action_type'] = step_data[:action_type] || 'Instruction'
      step['instructions'] = step_data[:instructions] || ''
      step['attachments'] = step_data[:attachments] || []
    when 'checkpoint'
      step['checkpoint_message'] = step_data[:checkpoint_message] || ''
    end
    
    # Render the step_item partial
    render partial: 'workflows/step_item', 
           locals: { 
             step: step, 
             index: step_index, 
             workflow: @workflow,
             expanded: true 
           },
           formats: [:html]
  end

  def save_as_template
    template_params = params.require(:template).permit(:name, :category, :description, :is_public)
    
    template_data = @workflow.convert_to_template(
      name: template_params[:name],
      category: template_params[:category],
      description: template_params[:description],
      is_public: template_params[:is_public] == "true"
    )
    
    @template = Template.new(template_data)
    
    if @template.save
      redirect_to templates_path, notice: "Template '#{@template.name}' was successfully created."
    else
      redirect_to edit_workflow_path(@workflow), alert: "Failed to save template: #{@template.errors.full_messages.join(', ')}"
    end
  end

  def start
    # Shows landing page for starting workflow
  end

  def begin_execution
    # Create simulation and start workflow execution
    @simulation = Simulation.new(
      workflow: @workflow,
      user: current_user,
      current_step_index: 0,
      execution_path: [],
      results: {},
      inputs: {},
      status: 'active'
    )

    if @simulation.save
      redirect_to step_simulation_path(@simulation), notice: "Workflow started!"
    else
      redirect_to start_workflow_path(@workflow), alert: "Failed to start workflow: #{@simulation.errors.full_messages.join(', ')}"
    end
  end

  def import
    # Show import form
  end

  def import_file
    unless params[:file].present?
      redirect_to import_workflows_path, alert: "Please select a file to import."
      return
    end

    uploaded_file = params[:file]
    file_content = uploaded_file.read
    
    # Validate file size (max 10MB)
    if file_content.bytesize > 10.megabytes
      redirect_to import_workflows_path, alert: "File is too large. Maximum size is 10MB."
      return
    end

    # Detect file format
    format = detect_file_format(uploaded_file.original_filename, uploaded_file.content_type)
    
    unless format
      redirect_to import_workflows_path, alert: "Unsupported file format. Please use JSON, CSV, YAML, or Markdown files."
      return
    end

    # Parse file
    parser = create_parser(format, file_content)
    workflow_data = parser.parse

    unless workflow_data
      redirect_to import_workflows_path, alert: "Failed to parse file: #{parser.errors.join(', ')}"
      return
    end

    # Create workflow with import metadata
    # Imported workflows are always published (not drafts)
    @workflow = current_user.workflows.build(
      title: workflow_data[:title],
      description: workflow_data[:description] || "",
      steps: workflow_data[:steps] || [],
      is_public: false,
      status: 'published'
    )

    # Store import metadata in a way we can access later
    @import_metadata = workflow_data[:import_metadata] || {}
    @import_warnings = parser.warnings
    @import_errors = parser.errors

    # Check if workflow has incomplete steps
    @has_incomplete_steps = workflow_data[:steps]&.any? { |step| step['_import_incomplete'] }

    # Try to save (validation will skip incomplete imported steps)
    if @workflow.save
      # If there are warnings or incomplete steps, redirect to edit with a notice
      if @has_incomplete_steps || @import_warnings.any?
        notice_parts = []
        notice_parts << "Workflow imported successfully!"
        notice_parts << "#{incomplete_steps_count} incomplete step(s) need attention." if @has_incomplete_steps
        notice_parts << "#{@import_warnings.count} warning(s) occurred." if @import_warnings.any?
        
        redirect_to edit_workflow_path(@workflow), notice: notice_parts.join(" ")
      else
        redirect_to @workflow, notice: "Workflow imported successfully!"
      end
    else
      redirect_to import_workflows_path, alert: "Failed to create workflow: #{@workflow.errors.full_messages.join(', ')}"
    end
  end

  # Wizard step actions
  def step1
    # Load draft workflow and accessible groups
    @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
    @selected_group_ids = @workflow.group_ids
  end

  def update_step1
    if @workflow.update(workflow_step1_params)
      # Update group assignments
      if params[:workflow][:group_ids].present?
        @workflow.group_workflows.destroy_all
        # Deduplicate group_ids to prevent duplicate entries
        group_ids = Array(params[:workflow][:group_ids]).reject(&:blank?).uniq
        group_ids.each_with_index do |group_id, index|
          @workflow.group_workflows.create!(
            group_id: group_id,
            is_primary: index == 0
          )
        end
      elsif params[:workflow].key?(:group_ids)
        # Explicitly clear groups if group_ids is present but empty
        @workflow.group_workflows.destroy_all
      end
      
      redirect_to step2_workflow_path(@workflow), notice: "Step 1 completed. Now let's add some steps."
    else
      @accessible_groups = Group.visible_to(current_user).includes(:children).order(:name)
      @selected_group_ids = @workflow.group_ids
      render :step1, status: :unprocessable_entity
    end
  end

  def step2
    # Load draft workflow for step 2 (add steps)
    # Steps will be managed via the existing workflow-builder controller
    Rails.logger.debug "[Phase1-Diagnosis] step2 action called for workflow #{@workflow.id}"
    Rails.logger.debug "[Phase1-Diagnosis] @workflow.steps count: #{@workflow.steps&.length || 0}"
    if @workflow.steps.present?
      @workflow.steps.each_with_index do |step, index|
        Rails.logger.debug "[Phase1-Diagnosis] Step #{index}: type=#{step['type']}, title=#{step['title']}, variable_name=#{step['variable_name']}"
        if step['type'] == 'decision' && step['branches'].present?
          Rails.logger.debug "[Phase1-Diagnosis] Step #{index} branches count: #{step['branches'].length}"
          step['branches'].each_with_index do |branch, branch_idx|
            Rails.logger.debug "[Phase1-Diagnosis] Step #{index}, Branch #{branch_idx}: condition=#{branch['condition']}, path=#{branch['path']}"
          end
        end
        if step['type'] == 'action' && step['output_fields'].present?
          Rails.logger.debug "[Phase1-Diagnosis] Step #{index} output_fields count: #{step['output_fields'].length}"
        end
      end
    end
  end

  def update_step2
    Rails.logger.debug "[Phase1-Diagnosis] update_step2 called for workflow #{@workflow.id}"
    
    permitted_params = workflow_step2_params
    Rails.logger.debug "[Phase1-Diagnosis] Permitted params steps count: #{permitted_params[:steps]&.length || 0}"
    
    # Log what we're about to save - with detailed variable_name tracking
    if permitted_params[:steps].present?
      permitted_params[:steps].each_with_index do |step, index|
        step_hash = step.is_a?(Hash) ? step : step.to_h
        Rails.logger.debug "[Phase1-Diagnosis] Permitted Step #{index}: type=#{step_hash[:type]}, variable_name=#{step_hash[:variable_name].inspect}"
        Rails.logger.debug "[Phase1-Diagnosis] Permitted Step #{index} keys: #{step_hash.keys.inspect}"
        if step_hash[:branches].present?
          Rails.logger.debug "[Phase1-Diagnosis] Permitted Step #{index} branches: #{step_hash[:branches].inspect}"
        end
        if step_hash[:output_fields].present?
          Rails.logger.debug "[Phase1-Diagnosis] Permitted Step #{index} output_fields: #{step_hash[:output_fields].inspect}"
        end
      end
    end
    
    # CRITICAL FIX: Merge submitted steps with existing steps to preserve fields not in form
    # Rails replaces the entire array, so we need to merge by step ID to preserve variable_name, etc.
    # Strategy: Start with existing steps, then overlay submitted changes
    if permitted_params[:steps].present? && @workflow.steps.present?
      existing_steps_hash = {}
      @workflow.steps.each do |step|
        step_id = step['id']
        existing_steps_hash[step_id] = step.dup if step_id.present?
      end
      
      # Convert submitted steps to hash format and merge with existing
      merged_steps = permitted_params[:steps].map do |submitted_step|
        step_hash = submitted_step.is_a?(Hash) ? submitted_step.stringify_keys : submitted_step.to_h.stringify_keys
        step_id = step_hash['id']
        
        if step_id.present? && existing_steps_hash[step_id]
          # Merge: start with existing step, overlay submitted values
          existing_step = existing_steps_hash[step_id]
          merged = existing_step.deep_dup
          
          # Track which keys were actually submitted
          submitted_keys = step_hash.keys
          
          # Log for debugging
          if existing_step['type'] == 'question'
            Rails.logger.debug "[Phase1-Diagnosis] Existing question step variable_name: #{existing_step['variable_name'].inspect}"
            Rails.logger.debug "[Phase1-Diagnosis] Submitted keys for question step: #{submitted_keys.inspect}"
            Rails.logger.debug "[Phase1-Diagnosis] variable_name in submitted keys: #{submitted_keys.include?('variable_name')}"
          end
          
          step_hash.each do |key, value|
            # Always use submitted value if it's present in the submission
            # This handles both updates and intentional clearing (empty string)
            merged[key] = value
          end
          
          # CRITICAL: Preserve important fields from existing step if not in submission OR if submitted value is empty
          # This handles cases where fields aren't submitted (e.g., collapsed sections) or are submitted as empty strings
          if merged['type'] == 'question'
            # For question steps, preserve variable_name if:
            # 1. Not in submission, OR
            # 2. Submitted as empty string but existing value is present
            submitted_var_name = step_hash['variable_name']
            existing_var_name = existing_step['variable_name']
            
            if !submitted_keys.include?('variable_name')
              # Not in submission - preserve existing
              Rails.logger.debug "[Phase1-Diagnosis] variable_name not in submission, preserving: #{existing_var_name.inspect}"
              merged['variable_name'] = existing_var_name if existing_var_name.present?
            elsif submitted_var_name.blank? && existing_var_name.present?
              # Submitted as empty but existing has value - preserve existing (user didn't intentionally clear it)
              Rails.logger.debug "[Phase1-Diagnosis] Submitted variable_name is empty, preserving existing: #{existing_var_name.inspect}"
              merged['variable_name'] = existing_var_name
            else
              # Submitted with a value (or both are empty) - use submitted value
              Rails.logger.debug "[Phase1-Diagnosis] Using submitted variable_name: #{submitted_var_name.inspect} (existing was: #{existing_var_name.inspect})"
              merged['variable_name'] = submitted_var_name
            end
          end
          
          merged
        else
          # New step or no ID - use submitted data as-is
          step_hash
        end
      end
      
      # Update permitted_params with merged steps
      permitted_params[:steps] = merged_steps
      
      Rails.logger.debug "[Phase1-Diagnosis] After merge - checking variable_name preservation"
      merged_steps.each_with_index do |step, index|
        if step['type'] == 'question'
          Rails.logger.debug "[Phase1-Diagnosis] Merged Question Step #{index}: variable_name=#{step['variable_name'].inspect}"
        end
      end
    end
    
    if @workflow.update(permitted_params)
      Rails.logger.debug "[Phase1-Diagnosis] Workflow updated successfully. Steps in DB: #{@workflow.steps&.length || 0}"
      # Log what was actually saved to the database
      if @workflow.steps.present?
        @workflow.steps.each_with_index do |step, index|
          Rails.logger.debug "[Phase1-Diagnosis] Saved Step #{index}: type=#{step['type']}, variable_name=#{step['variable_name'].inspect}"
          if step['type'] == 'question'
            Rails.logger.debug "[Phase1-Diagnosis] Saved Question Step #{index} - variable_name present: #{step['variable_name'].present?}"
          end
        end
      end
      redirect_to step3_workflow_path(@workflow), notice: "Steps added. Let's review your workflow."
    else
      Rails.logger.error "[Phase1-Diagnosis] Workflow update failed: #{@workflow.errors.full_messages.join(', ')}"
      render :step2, status: :unprocessable_entity
    end
  end

  def step3
    # Load draft workflow for step 3 (review and launch)
    # Preview will be shown here
    Rails.logger.debug "[Phase1-Diagnosis] step3 action called for workflow #{@workflow.id}"
    Rails.logger.debug "[Phase1-Diagnosis] @workflow.steps count: #{@workflow.steps&.length || 0}"
    if @workflow.steps.present?
      @workflow.steps.each_with_index do |step, index|
        Rails.logger.debug "[Phase1-Diagnosis] Step #{index}: type=#{step['type']}, title=#{step['title']}, variable_name=#{step['variable_name']}"
        if step['type'] == 'decision' && step['branches'].present?
          Rails.logger.debug "[Phase1-Diagnosis] Step #{index} branches count: #{step['branches'].length}"
        end
        if step['type'] == 'action' && step['output_fields'].present?
          Rails.logger.debug "[Phase1-Diagnosis] Step #{index} output_fields count: #{step['output_fields'].length}"
        end
      end
    end
  end

  def create_from_draft
    # Validate draft before converting to published
    unless @workflow.valid?
      render :step3, status: :unprocessable_entity
      return
    end
    
    # Validate that workflow has at least one step
    if @workflow.steps.blank? || @workflow.steps.empty?
      @workflow.errors.add(:base, "Workflow must have at least one step")
      render :step3, status: :unprocessable_entity
      return
    end
    
    # Validate all steps have required fields
    @workflow.steps.each_with_index do |step, index|
      unless step.is_a?(Hash)
        @workflow.errors.add(:steps, "Step #{index + 1}: Invalid step format")
        next
      end
      
      unless step['type'].present?
        @workflow.errors.add(:steps, "Step #{index + 1}: Step type is required")
      end
      
      unless step['title'].present? || step['title'].to_s.strip.present?
        @workflow.errors.add(:steps, "Step #{index + 1}: Step title is required")
      end
      
      # Type-specific validation
      if step['type'] == 'question' && !step['question'].present?
        @workflow.errors.add(:steps, "Step #{index + 1}: Question text is required for question steps")
      end
    end
    
    if @workflow.errors.any?
      render :step3, status: :unprocessable_entity
      return
    end
    
    # Convert draft to published workflow
    @workflow.status = 'published'
    @workflow.draft_expires_at = nil
    
    # Assign to Uncategorized group if no groups assigned (triggered by status change)
    if @workflow.save
      # Ensure groups are assigned (after_create callback handles this for published workflows)
      @workflow.assign_to_uncategorized_if_needed if @workflow.groups.empty?
      
      redirect_to @workflow, notice: "Workflow was successfully created!"
    else
      render :step3, status: :unprocessable_entity
    end
  end

  private

  # Generate sample variable values for preview interpolation
  # This creates realistic sample data so users can see what interpolated text looks like
  def generate_sample_variables(workflow)
    return {} unless workflow&.steps.present?
    
    sample_vars = {}
    
    workflow.steps.each do |step|
      next unless step.is_a?(Hash)
      
      # Get variables from question steps
      if step['type'] == 'question' && step['variable_name'].present?
        var_name = step['variable_name']
        # Generate sample value based on answer type
        sample_vars[var_name] = case step['answer_type']
        when 'yes_no'
          'yes'
        when 'number'
          '42'
        when 'date'
          Date.today.strftime('%Y-%m-%d')
        when 'multiple_choice', 'dropdown'
          # Use first option if available, otherwise default
          if step['options'].present? && step['options'].is_a?(Array) && step['options'].first
            opt = step['options'].first
            opt.is_a?(Hash) ? (opt['value'] || opt['label'] || 'option1') : opt.to_s
          else
            'option1'
          end
        else
          # Default text value - use step title or generic name
          step['title'].present? ? step['title'].split(' ').first : 'sample_value'
        end
      end
      
      # Get variables from action step output_fields
      if step['type'] == 'action' && step['output_fields'].present? && step['output_fields'].is_a?(Array)
        step['output_fields'].each do |output_field|
          next unless output_field.is_a?(Hash) && output_field['name'].present?
          
          var_name = output_field['name']
          # Use the defined value if static, or generate sample if it contains interpolation
          if output_field['value'].present?
            # If value contains {{, it's interpolated - use a placeholder
            if output_field['value'].include?('{{')
              sample_vars[var_name] = '[interpolated]'
            else
              # Static value
              sample_vars[var_name] = output_field['value']
            end
          else
            # No value defined - use generic sample
            sample_vars[var_name] = 'completed'
          end
        end
      end
    end
    
    sample_vars
  end

  def set_workflow
    @workflow = Workflow.find(params[:id])
  end

  # Override parent methods to use @workflow instance variable
  def ensure_can_view_workflow!
    unless @workflow.can_be_viewed_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to view this workflow."
    end
  end

  def ensure_can_edit_workflow!
    unless @workflow.can_be_edited_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to edit this workflow."
    end
  end

  def ensure_can_delete_workflow!
    unless @workflow.can_be_deleted_by?(current_user)
      redirect_to workflows_path, alert: "You don't have permission to delete this workflow."
    end
  end

  def ensure_draft_workflow!
    unless @workflow.status == 'draft' && @workflow.user == current_user
      redirect_to workflows_path, alert: "This workflow is not a draft or you don't have permission to edit it."
    end
  end

  def workflow_params
    # Permit nested steps hash structure
    # lock_version is used for optimistic locking to prevent race conditions
    permitted = params.require(:workflow).permit(:title, :description, :is_public, :lock_version, 
      steps: [
      :index, :id, :type, :title, :description, :question, :answer_type, :variable_name,
      :condition, :true_path, :false_path, :else_path, :action_type, :instructions,
      :checkpoint_message,
      options: [:label, :value],
      branches: [:condition, :path],
      jumps: [:condition, :next_step_id],
      attachments: [],
      output_fields: [:name, :value]
    ])
    permitted
  end

  def workflow_step1_params
    # Permit only title and description for step 1
    params.require(:workflow).permit(:title, :description)
  end

  def workflow_step2_params
    # Permit steps for step 2
    # NOTE: Must match workflow_params to ensure all nested structures are permitted
    # Missing fields identified in Phase 1 diagnosis: :id, :checkpoint_message, :jumps, output_fields
    params.require(:workflow).permit(steps: [
      :index, :id, :type, :title, :description, :question, :answer_type, :variable_name,
      :condition, :true_path, :false_path, :else_path, :action_type, :instructions,
      :checkpoint_message,
      options: [:label, :value],
      branches: [:condition, :path],
      jumps: [:condition, :next_step_id],
      attachments: [],
      output_fields: [:name, :value]
    ])
  end

  def parse_step_from_params
    step_params = params[:step] || {}
    
    # Parse options if provided as JSON string or array
    options = step_params[:options]
    if options.is_a?(String)
      begin
        options = JSON.parse(options)
      rescue JSON::ParserError
        options = []
      end
    elsif options.is_a?(Array)
      # Options is already an array, process it
      options = options.map do |opt|
        if opt.is_a?(Hash)
          { 'label' => opt['label'] || opt[:label], 'value' => opt['value'] || opt[:value] }
        else
          { 'label' => opt.to_s, 'value' => opt.to_s }
        end
      end
    elsif options.is_a?(ActionController::Parameters)
      # Handle Rails strong parameters
      options = options.values.map do |opt|
        { 'label' => opt['label'] || opt[:label], 'value' => opt['value'] || opt[:value] }
      end
    else
      options = []
    end

    # Parse attachments if provided
    attachments = step_params[:attachments]
    if attachments.is_a?(String)
      begin
        attachments = JSON.parse(attachments)
      rescue JSON::ParserError
        attachments = []
      end
    elsif attachments.is_a?(Array)
      attachments = attachments.compact
    else
      attachments = []
    end

    {
      type: step_params[:type] || "",
      title: step_params[:title] || "",
      description: step_params[:description] || "",
      question: step_params[:question] || "",
      answer_type: step_params[:answer_type] || "",
      variable_name: step_params[:variable_name] || "",
      options: options || [],
      condition: step_params[:condition] || "",
      true_path: step_params[:true_path] || "",
      false_path: step_params[:false_path] || "",
      action_type: step_params[:action_type] || "",
      instructions: step_params[:instructions] || "",
      attachments: attachments || []
    }
  end

  def detect_file_format(filename, content_type)
    extension = File.extname(filename).downcase
    
    case extension
    when '.json'
      :json
    when '.csv'
      :csv
    when '.yaml', '.yml'
      :yaml
    when '.md', '.markdown'
      :markdown
    else
      # Try content type as fallback
      case content_type
      when 'application/json', 'text/json'
        :json
      when 'text/csv', 'application/csv'
        :csv
      when 'text/x-yaml', 'application/x-yaml'
        :yaml
      when 'text/markdown', 'text/x-markdown'
        :markdown
      else
        nil
      end
    end
  end

  def create_parser(format, file_content)
    # Rails should autoload services automatically, but ensure it's loaded
    # Using const_get to handle autoloading gracefully
    case format
    when :json
      WorkflowParsers::JsonParser.new(file_content)
    when :csv
      WorkflowParsers::CsvParser.new(file_content)
    when :yaml
      WorkflowParsers::YamlParser.new(file_content)
    when :markdown
      WorkflowParsers::MarkdownParser.new(file_content)
    else
      raise ArgumentError, "Unknown format: #{format}"
    end
  rescue NameError => e
    # If autoloading fails, try explicit require
    Rails.logger.warn("Failed to autoload WorkflowParsers: #{e.message}")
    require Rails.root.join('app', 'services', 'workflow_parsers', 'base_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'json_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'csv_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'yaml_parser')
    require Rails.root.join('app', 'services', 'workflow_parsers', 'markdown_parser')
    retry
  end

  def incomplete_steps_count
    @workflow.steps&.count { |step| step['_import_incomplete'] } || 0
  end
end
