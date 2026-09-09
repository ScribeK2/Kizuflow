module Admin
  class DataHealthController < BaseController
    def index
      @table_sizes = fetch_table_sizes
      @record_counts = fetch_record_counts
      @retention_config = {
        simulation_days: Scenario.simulation_retention_days,
        live_days: Scenario.live_retention_days
      }
      @draft_stats = {
        total: Workflow.draft.count,
        expired: Workflow.expired_drafts.count,
        orphaned: Workflow.orphaned_drafts.count
      }
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
        idle_timeout_hours: Scenario.idle_timeout_hours
      }
    end

    def cleanup_drafts
      expired = Workflow.cleanup_expired_drafts
      orphaned = Workflow.cleanup_orphaned_drafts
      redirect_to admin_data_health_path,
                  notice: "Cleaned up #{expired} expired and #{orphaned} orphaned draft(s)."
    end

    private

    def fetch_table_sizes
      tables = %w[scenarios step_responses workflow_versions active_storage_blobs]
      tables.index_with do |table|
        result = ActiveRecord::Base.connection.execute(
          "SELECT pg_size_pretty(pg_total_relation_size(#{ActiveRecord::Base.connection.quote(table)}))"
        )
        result.first["pg_size_pretty"]
      rescue ActiveRecord::StatementInvalid
        "N/A"
      end
    end

    def fetch_record_counts
      {
        scenarios: Scenario.count,
        step_responses: StepResponse.count,
        workflow_versions: WorkflowVersion.count,
        active_storage_blobs: ActiveStorage::Blob.count
      }
    end
  end
end
