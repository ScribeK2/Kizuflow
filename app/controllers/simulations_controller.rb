class SimulationsController < ApplicationController
  before_action :set_workflow, only: [:new, :create]

  def new
    @simulation = Simulation.new
    @workflow = Workflow.find(params[:workflow_id])
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to simulate this workflow."
    end
  end

  def create
    @workflow = Workflow.find(params[:workflow_id])
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to simulate this workflow."
      return
    end
    
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
    
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to view this simulation."
    end
  end
  
  def step
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to view this simulation."
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
              # Find the step to get variable_name
              step = @workflow.steps[path_entry['step_index']]
              if step && step['type'] == 'question'
                input_key = step['variable_name'].present? ? step['variable_name'] : path_entry['step_index'].to_s
                @simulation.inputs[input_key] = path_entry['answer']
                @simulation.inputs[step['title']] = path_entry['answer']
                @simulation.results[step['title']] = path_entry['answer']
                @simulation.results[step['variable_name']] = path_entry['answer'] if step['variable_name'].present?
              end
            end
          end
          
          # Set current_step_index to the next step after the selected one
          @simulation.current_step_index = target_step_index + 1
          
          @simulation.save
        end
      end
    end
    
    # Auto-advance decision steps immediately without user interaction
    current_step = @simulation.current_step
    if current_step && current_step['type'] == 'decision'
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
  
  def next_step
    @simulation = Simulation.find(params[:id])
    @workflow = @simulation.workflow
    
    unless @workflow.user == current_user
      redirect_to workflows_path, alert: "You don't have permission to view this simulation."
      return
    end
    
    # Get answer from params
    answer = params[:answer]
    
    # Process the current step
    if @simulation.process_step(answer)
      if @simulation.complete?
        redirect_to simulation_path(@simulation), notice: "Simulation completed successfully!"
      else
        # Check if next step is a decision - if so, auto-advance
        next_step = @simulation.current_step
        if next_step && next_step['type'] == 'decision'
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

