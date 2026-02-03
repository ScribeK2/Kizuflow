class AddGraphModeToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :graph_mode, :boolean, default: false, null: false
    add_column :workflows, :start_node_uuid, :string, null: true

    add_index :workflows, :graph_mode
  end
end
