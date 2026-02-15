class AddFolderIdToGroupWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_reference :group_workflows, :folder, null: true, foreign_key: true
  end
end
