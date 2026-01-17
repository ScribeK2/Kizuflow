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
    
    # If simulation is complete, redirect to show page
    if @simulation.complete?
      redirect_to simulation_path(@simulation), notice: "Simulation completed!"
      return
    end
    
    # Handle jumping to a specific step in execution path
    if params[:step].present?
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
    
    # Auto-advance decision steps immediately without user interaction
    # Note: checkpoint steps don't auto-advance - they require user resolution
    # Both 'decision' and 'simple_decision' types should auto-advance
    current_step = @simulation.current_step
    if current_step && %w[decision simple_decision].include?(current_step['type'])
      # Process decision immediately and advance
      @simulation.process_step(nil)
      if @simulation.complete?
        redirect_to simulation_path(@simulation), notice: "Simulation completed!"
      else
        # Redirect to next step (don't show decision step)
        redirect_to step_simulation_path(@simulation)
      end
      return
    end
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
      if @simulation.complete?
        redirect_to simulation_path(@simulation), notice: "Simulation completed successfully!"
      else
        # Check if next step is a decision - if so, auto-advance
        # Both 'decision' and 'simple_decision' types should auto-advance
        next_step = @simulation.current_step
        if next_step && %w[decision simple_decision].include?(next_step['type'])
          @simulation.process_step(nil)
          if @simulation.complete?
            redirect_to simulation_path(@simulation), notice: "Simulation completed successfully!"
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

