class AddLockVersionToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :lock_version, :integer, default: 0, null: false
  end
end
