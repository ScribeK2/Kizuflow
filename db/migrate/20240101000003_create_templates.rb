class CreateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :templates do |t|
      t.string :name, null: false
      t.text :description
      t.json :workflow_data
      t.string :category
      t.boolean :is_public, default: true

      t.timestamps
    end

    add_index :templates, :category
    add_index :templates, :is_public
  end
end

