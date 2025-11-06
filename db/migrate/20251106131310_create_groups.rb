class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.text :description
      t.integer :parent_id
      t.integer :position

      t.timestamps
    end

    add_index :groups, :parent_id
    add_index :groups, [:parent_id, :position], name: "index_groups_on_parent_id_and_position"
    add_index :groups, :name
  end
end
