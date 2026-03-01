class AddPublishedVersionIdToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_reference :workflows, :published_version, null: true,
                  foreign_key: { to_table: :workflow_versions }
  end
end
