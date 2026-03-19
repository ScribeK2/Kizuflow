class AddPositionXyToSteps < ActiveRecord::Migration[8.1]
  def change
    add_column :steps, :position_x, :integer
    add_column :steps, :position_y, :integer
  end
end
