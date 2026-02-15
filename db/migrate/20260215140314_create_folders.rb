class CreateFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :folders do |t|
      t.string :name, null: false
      t.references :group, null: false, foreign_key: true
      t.integer :parent_id
      t.integer :position, default: 0
      t.text :description

      t.timestamps
    end

    add_index :folders, [:group_id, :position]
    add_index :folders, [:group_id, :name], unique: true
    add_index :folders, :parent_id
  end
end
