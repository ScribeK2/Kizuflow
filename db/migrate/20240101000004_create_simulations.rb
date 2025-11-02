class CreateSimulations < ActiveRecord::Migration[8.0]
  def change
    create_table :simulations do |t|
      t.references :workflow, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.json :inputs
      t.json :execution_path
      t.json :results

      t.timestamps
    end
  end
end

