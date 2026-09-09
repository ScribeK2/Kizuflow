# A version's RECORD is permanent; only its restorable payload has a limit.
#
# `stripped_at` says the steps snapshot was intentionally released, which
# `steps_snapshot: []` alone cannot: the column is NOT NULL, and an empty array
# would otherwise be indistinguishable from a bug. It also dates the event, which
# is the kind of thing the versions page exists to record.
class AddStrippedAtToWorkflowVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_versions, :stripped_at, :datetime
  end
end
