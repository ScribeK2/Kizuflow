class AddIsPublicToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :is_public, :boolean, default: false, null: false
    add_index :workflows, :is_public
  end
end
