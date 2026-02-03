class AddGraphFieldsToSimulations < ActiveRecord::Migration[8.0]
  def change
    add_column :simulations, :current_node_uuid, :string, null: true
    add_column :simulations, :parent_simulation_id, :integer, null: true
    add_column :simulations, :resume_node_uuid, :string, null: true

    add_index :simulations, :current_node_uuid
    add_index :simulations, :parent_simulation_id
    add_foreign_key :simulations, :simulations, column: :parent_simulation_id, on_delete: :nullify
  end
end
