class AddStatusToSimulations < ActiveRecord::Migration[8.0]
  def change
    add_column :simulations, :status, :string, default: 'active', null: false
    add_column :simulations, :stopped_at_step_index, :integer, null: true
    
    # Update existing simulations: mark as completed if they've reached the end
    reversible do |dir|
      dir.up do
        Simulation.reset_column_information
        Simulation.find_each do |simulation|
          workflow = simulation.workflow
          if workflow && workflow.steps.present?
            if simulation.current_step_index >= workflow.steps.length
              simulation.update_column(:status, 'completed')
            else
              simulation.update_column(:status, 'active')
            end
          else
            simulation.update_column(:status, 'active')
          end
        end
      end
    end
    
    # Add index for better query performance
    add_index :simulations, :status
  end
end
