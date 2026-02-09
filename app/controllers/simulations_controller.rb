class SimulationsController < ApplicationController
  before_action :set_workflow, only: [:new, :create]

  def new
    @simulation = Simulation.new
    @workflow = Workflow.find(params[:workflow_id])
    ensure_can_view_workflow!(@workflow)
  end

  def create
    @workflow = Workflow.find(params[:workflow_id])
    ensure_can_view_workflow!(@workflow)
    
    @simulation = Simulation.new(simulation_params)
    @simulation.workflow = @workflow
    @simulation.user = current_user
    @simulation.current_step_index = 0
    @simulation.execution_path = []
    @simulation.results = {}
    @simulation.inputs = {}
    

    if @simulation.save
      # Redirect to step view instead of executing immediately
      redirect_to step_simulation_path(@simulation), notice: "Simulation started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    ensure_can_view_workflow!(@workflow)
  end
  
  def step
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    ensure_can_view_workflow!(@workflow)
    
    # If simulation is stopped, redirect to show page
    if @simulation.stopped?
      redirect_to simulation_path(@simulation), notice: "This workflow has been stopped."
      return
    end
    
    # If simulation is complete, redirect appropriately
    if @simulation.complete?
      if @simulation.parent_simulation.present?
        redirect_to step_simulation_path(@simulation.parent_simulation)
      else
        redirect_to simulation_path(@simulation), notice: "Simulation completed!"
      end
      return
    end

    # If parent is awaiting sub-flow, redirect to active child or process completion
    if @simulation.awaiting_subflow?
      active_child = @simulation.active_child_simulation
      if active_child && !active_child.complete?
        redirect_to step_simulation_path(active_child)
        return
      else
        # Child is complete (or no active child found) — process completion and resume parent
        @simulation.process_subflow_completion
        if @simulation.complete?
          redirect_to simulation_path(@simulation), notice: "Simulation completed!"
        else
          redirect_to step_simulation_path(@simulation)
        end
        return
      end
    end
    
    # Handle going back to the previous interactive step
    if params[:back].present?
      if @simulation.execution_path.present? && @simulation.execution_path.length > 0
        # Pop entries from the end, skipping decision/simple_decision/sub_flow types
        # (auto-advancing steps users never interact with), until we find an interactive step
        popped_step = nil
        while @simulation.execution_path.length > 0
          candidate = @simulation.execution_path.pop
          if %w[decision simple_decision sub_flow].include?(candidate['step_type'])
            next
          else
            popped_step = candidate
            break
          end
        end

        if popped_step
          # Rebuild results and inputs from the remaining execution_path
          @simulation.results = {}
          @simulation.inputs = {}
          @simulation.execution_path.each do |path_entry|
            if path_entry['answer'].present?
              if @simulation.graph_mode? && path_entry['step_uuid'].present?
                step = @workflow.find_step_by_id(path_entry['step_uuid'])
              elsif path_entry['step_index'].present?
                idx = path_entry['step_index'].to_i
                step = @workflow.steps[idx] if idx >= 0 && idx < @workflow.steps.length
              end

              if step && step['type'] == 'question'
                input_key = step['variable_name'].present? ? step['variable_name'] : (path_entry['step_index'] || 0).to_s
                @simulation.inputs[input_key] = path_entry['answer']
                @simulation.inputs[step['title']] = path_entry['answer']
                @simulation.results[step['title']] = path_entry['answer']
                @simulation.results[step['variable_name']] = path_entry['answer'] if step['variable_name'].present?
              end
            end
          end

          # Set current position to the popped interactive step so the user re-sees it
          if @simulation.graph_mode? && popped_step['step_uuid'].present?
            @simulation.current_node_uuid = popped_step['step_uuid']
          elsif popped_step['step_index'].present?
            @simulation.current_step_index = popped_step['step_index'].to_i
          end

          # Reset status to active if it was completed (edge case: back from final step)
          @simulation.status = 'active' if @simulation.status == 'completed'

          @simulation.save
        end
      end

    # Handle jumping to a specific step in execution path
    elsif params[:step].present?
      step_index = params[:step].to_i
      if step_index >= 0 && step_index < @simulation.execution_path.length
        # Find the step_index from the execution path
        path_item = @simulation.execution_path[step_index]
        if path_item && path_item['step_index'].present?
          # Restore simulation state to this point
          target_step_index = path_item['step_index']

          # Truncate execution_path to this point
          @simulation.execution_path = @simulation.execution_path[0..step_index]

          # Rebuild results and inputs from execution path up to this point
          @simulation.results = {}
          @simulation.inputs = {}
          @simulation.execution_path.each do |path_entry|
            if path_entry['answer'].present?
              # Find the step to get variable_name - add bounds checking
              step_index = path_entry['step_index'].to_i
              if step_index >= 0 && step_index < @workflow.steps.length
                step = @workflow.steps[step_index]
                if step && step['type'] == 'question'
                  input_key = step['variable_name'].present? ? step['variable_name'] : step_index.to_s
                  @simulation.inputs[input_key] = path_entry['answer']
                  @simulation.inputs[step['title']] = path_entry['answer']
                  @simulation.results[step['title']] = path_entry['answer']
                  @simulation.results[step['variable_name']] = path_entry['answer'] if step['variable_name'].present?
                end
              end
            end
          end

          # Set current_step_index to the next step after the selected one
          # Validate that target_step_index + 1 doesn't exceed workflow length
          next_step_index = target_step_index.to_i + 1
          if next_step_index >= @workflow.steps.length
            @simulation.status = 'completed'
            @simulation.current_step_index = @workflow.steps.length
          else
            @simulation.current_step_index = next_step_index
          end

          @simulation.save
        end
      end
    end
    
    # Auto-advance decision, simple_decision, and sub_flow steps immediately without user interaction
    # Note: checkpoint steps don't auto-advance - they require user resolution
    current_step = @simulation.current_step
    if current_step && %w[decision simple_decision sub_flow].include?(current_step['type'])
      # Process step immediately and advance
      @simulation.process_step(nil)

      # After processing a sub_flow step, parent may now be awaiting_subflow
      if @simulation.awaiting_subflow?
        active_child = @simulation.active_child_simulation
        if active_child
          redirect_to step_simulation_path(active_child)
        else
          redirect_to step_simulation_path(@simulation)
        end
        return
      end

      if @simulation.complete?
        if @simulation.parent_simulation.present?
          redirect_to step_simulation_path(@simulation.parent_simulation)
        else
          redirect_to simulation_path(@simulation), notice: "Simulation completed!"
        end
      else
        # Redirect to next step (don't show decision/sub_flow step)
        redirect_to step_simulation_path(@simulation)
      end
      return
    end

    # Note: escalate and resolve steps show UI first, then process on Continue click
    # They are NOT auto-advanced here - they need user acknowledgment
  end
  
  def stop
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    ensure_can_view_workflow!(@workflow)
    
    # Ensure user owns this simulation
    unless @simulation.user == current_user
      redirect_to simulation_path(@simulation), alert: "You don't have permission to stop this workflow."
      return
    end
    
    # Stop the workflow
    @simulation.stop!(@simulation.current_step_index)
    redirect_to simulation_path(@simulation), notice: "Workflow stopped."
  end

  def resolve_checkpoint
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    ensure_can_view_workflow!(@workflow)
    
    # Ensure user owns this simulation
    unless @simulation.user == current_user
      redirect_to simulation_path(@simulation), alert: "You don't have permission to resolve this checkpoint."
      return
    end
    
    # Get resolution parameters
    resolved = params[:resolved] == 'true' || params[:resolved] == true
    notes = params[:notes]
    
    # Resolve the checkpoint
    if @simulation.resolve_checkpoint!(resolved: resolved, notes: notes)
      if resolved
        redirect_to simulation_path(@simulation), notice: "Issue resolved. Workflow completed."
      else
        redirect_to step_simulation_path(@simulation), notice: "Continuing workflow..."
      end
    else
      redirect_to step_simulation_path(@simulation), alert: "Failed to resolve checkpoint. Make sure you're on a checkpoint step."
    end
  end

  def next_step
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    ensure_can_view_workflow!(@workflow)
    
    # Prevent processing if stopped
    if @simulation.stopped?
      redirect_to simulation_path(@simulation), alert: "This workflow has been stopped and cannot be continued."
      return
    end
    
    # Get answer from params
    answer = params[:answer]
    
    # Process the current step
    # Note: checkpoint steps won't process here - they use resolve_checkpoint instead
    if @simulation.process_step(answer)
      # After processing a sub_flow step, parent may now be awaiting_subflow
      if @simulation.awaiting_subflow?
        active_child = @simulation.active_child_simulation
        if active_child
          redirect_to step_simulation_path(active_child)
        else
          redirect_to step_simulation_path(@simulation)
        end
        return
      end

      if @simulation.complete?
        # If this is a child simulation, redirect to parent's step view to resume it
        if @simulation.parent_simulation.present?
          redirect_to step_simulation_path(@simulation.parent_simulation)
        else
          redirect_to simulation_path(@simulation), notice: "Simulation completed successfully!"
        end
      else
        # Check if next step is auto-advancing - if so, process it
        # decision, simple_decision, and sub_flow types auto-advance (routing steps)
        # escalate, resolve, and message steps show UI first and need user acknowledgment
        next_step = @simulation.current_step
        if next_step && %w[decision simple_decision sub_flow].include?(next_step['type'])
          @simulation.process_step(nil)

          # After processing a sub_flow step, parent may now be awaiting_subflow
          if @simulation.awaiting_subflow?
            active_child = @simulation.active_child_simulation
            if active_child
              redirect_to step_simulation_path(active_child)
            else
              redirect_to step_simulation_path(@simulation)
            end
            return
          end

          if @simulation.complete?
            if @simulation.parent_simulation.present?
              redirect_to step_simulation_path(@simulation.parent_simulation)
            else
              redirect_to simulation_path(@simulation), notice: "Simulation completed successfully!"
            end
          else
            redirect_to step_simulation_path(@simulation)
          end
        else
          redirect_to step_simulation_path(@simulation)
        end
      end
    else
      redirect_to step_simulation_path(@simulation), alert: "Failed to process step."
    end
  end

  private

  def set_workflow
    # Handled in actions
  end

  def simulation_params
    # Permit workflow_id, inputs are optional (will be built up step by step)
    params.require(:simulation).permit(:workflow_id, inputs: {})
  end
end

