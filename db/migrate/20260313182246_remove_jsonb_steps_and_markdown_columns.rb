class RemoveJsonbStepsAndMarkdownColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :workflows, :steps, :json
    remove_column :workflows, :start_node_uuid, :string
    remove_column :workflows, :description, :text
  end
end
