class RemoveKickoffFormFromWorkflows < ActiveRecord::Migration[8.0]
  def change
    remove_column :workflows, :kickoff_form, :json, if_exists: true
  end
end
