class AddGraphModeToTemplates < ActiveRecord::Migration[8.1]
  def change
    add_column :templates, :graph_mode, :boolean, default: true
    add_column :templates, :start_node_uuid, :string
  end
end
