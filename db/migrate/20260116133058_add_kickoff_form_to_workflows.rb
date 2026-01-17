class AddKickoffFormToWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :workflows, :kickoff_form, :json, default: nil, null: true
  end
end
