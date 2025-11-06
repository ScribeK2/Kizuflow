class CreateGroupWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :group_workflows do |t|
      t.references :group, null: false, foreign_key: true
      t.references :workflow, null: false, foreign_key: true
      t.boolean :is_primary, default: false, null: false

      t.timestamps
    end

    add_index :group_workflows, [:group_id, :workflow_id], unique: true, name: "index_group_workflows_on_group_and_workflow"
  end
end
