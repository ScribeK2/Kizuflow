module Workflows
  class ExecutionsController < BaseController
    before_action :ensure_can_manage_workflows!
    before_action :ensure_can_view_workflow!

    # GET used to render a landing page. Turbo prefetches GET links, so this
    # must not start a run. Leftover bookmarks land on the workflow instead.
    def new
      redirect_to workflow_path(@workflow)
    end

    # POST /workflows/:workflow_id/execution
    def create
      @scenario = Scenario.new(
        workflow: @workflow,
        user: current_user,
        current_step_index: 0,
        current_node_uuid: @workflow.start_node&.uuid,
        execution_path: [],
        results: {},
        inputs: {},
        status: 'active'
      )

      if @scenario.save
        # Settle before redirecting: a workflow whose first step is a sub_flow
        # opens on a node with no UI, and GET step no longer moves the run.
        landed = ScenarioSettler.new(@scenario).settle_from_start
        redirect_to step_scenario_path(landed)
      else
        redirect_to workflow_path(@workflow), alert: "Failed to start workflow: #{@scenario.errors.full_messages.join(', ')}"
      end
    end
  end
end
