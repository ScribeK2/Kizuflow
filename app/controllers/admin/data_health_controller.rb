module Admin
  class DataHealthController < BaseController
    def index
      # The leak indicator. Retention can only collect runs that ended, and
      # nothing used to end an abandoned one — so this number grew forever. If it
      # climbs without bound now that SweepIdleScenariosJob runs, the sweep is not
      # reaching something (handoff chains being the first suspect).
      #
      # Deliberately a COUNT and not `sweep_idle_runs(dry_run: true)`: the dry run
      # walks every frame of every open run, which is fine in a rake task and far
      # too much for a page render.
      @run_stats = {
        outstanding: Scenario.outstanding_non_terminal,
        idle_timeout_hours: Scenario.idle_timeout_hours,
        simulation_days: Scenario.simulation_retention_days,
        live_days: Scenario.live_retention_days
      }
      @draft_stats = {
        total: Workflow.draft.count,
        expired: Workflow.expired_drafts.count,
        orphaned: Workflow.orphaned_drafts.count
      }
      # The number that would have answered "is version growth worth doing anything
      # about" at the outset. Nothing on this page reported it, so the case for
      # pruning got sized by arithmetic on an assumed publish rate instead — and
      # the real answer was one version per workflow.
      @version_stats = {
        total: WorkflowVersion.count,
        restorable: WorkflowVersion.restorable.count,
        released: WorkflowVersion.stripped.count,
        max_per_workflow: WorkflowVersion.group(:workflow_id).count.values.max || 0,
        restore_limit: WorkflowVersion.restore_limit
      }
      @storage = storage_stats
      # Read from the file rather than the queue database, so the schedule shows
      # in every environment, including the ones where Solid Queue does not run.
      @schedule = Rails.application.config_for(:recurring, env: "production")
    end

    def cleanup_drafts
      expired = Workflow.cleanup_expired_drafts
      orphaned = Workflow.cleanup_orphaned_drafts
      redirect_to admin_data_health_path(anchor: "drafts"),
                  notice: "Cleaned up #{expired} expired and #{orphaned} orphaned draft(s)."
    end

    private

    # Counts always. A size only where the database can report one (PostgreSQL),
    # rather than a column reading N/A everywhere else (Q55).
    def storage_stats
      sizes = ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
      { "Runs" => Scenario, "Step responses" => StepResponse,
        "Workflow versions" => WorkflowVersion, "Uploaded files" => ActiveStorage::Blob }.map do |label, model|
        { label: label, count: model.count, size: (table_size(model.table_name) if sizes) }
      end
    end

    def table_size(table)
      connection = ActiveRecord::Base.connection
      connection.select_value("SELECT pg_size_pretty(pg_total_relation_size(#{connection.quote(table)}))")
    end
  end
end
