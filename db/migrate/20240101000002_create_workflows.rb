class CreateWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :workflows do |t|
      t.string :title, null: false
      t.text :description
      t.json :steps
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :workflows, :created_at
  end
end

