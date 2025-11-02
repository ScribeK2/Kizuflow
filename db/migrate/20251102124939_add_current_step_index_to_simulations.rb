class AddCurrentStepIndexToSimulations < ActiveRecord::Migration[8.0]
  def change
    add_column :simulations, :current_step_index, :integer, default: 0, null: false
  end
end
