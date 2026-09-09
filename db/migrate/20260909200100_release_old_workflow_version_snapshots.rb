# Closes the backlog that predates release-on-publish.
#
# Snapshots are released when a workflow is published, because the rule is a
# count and only a publish can push a version past it. That leaves one gap: a
# workflow published fifty times and then abandoned keeps all fifty, and an
# abandoned workflow is exactly where old versions pile up unread. So the
# existing backlog is closed once, here, rather than by adding a nightly scan
# that would find nothing on almost every night it ran.
#
# Nothing is deleted. Each released version keeps its number, date, publisher,
# title and changelog, and gives up only `steps_snapshot`.
class ReleaseOldWorkflowVersionSnapshots < ActiveRecord::Migration[8.1]
  # Bare AR classes: the real models carry validations and callbacks that will
  # keep changing, and a migration has to keep meaning the same thing later.
  class WorkflowVersion < ActiveRecord::Base
  end

  def up
    limit = ENV.fetch("WORKFLOW_VERSION_RESTORE_LIMIT", 10).to_i
    now = Time.current
    released = 0

    WorkflowVersion.where(stripped_at: nil).distinct.pluck(:workflow_id).each do |workflow_id|
      keep = WorkflowVersion.where(workflow_id: workflow_id, stripped_at: nil)
                            .order(version_number: :desc)
                            .limit(limit)
                            .pluck(:id)
      released += WorkflowVersion.where(workflow_id: workflow_id, stripped_at: nil)
                                 .where.not(id: keep)
                                 .update_all(steps_snapshot: "[]", stripped_at: now)
    end

    say "Released #{released} workflow version snapshot(s) past the newest #{limit}"
  end

  def down
    # The snapshots are gone; there is nothing to restore them from.
    raise ActiveRecord::IrreversibleMigration
  end
end
