class AddStartStepIdToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_reference :workflows, :start_step, foreign_key: { to_table: :steps }, null: true
  end
end
