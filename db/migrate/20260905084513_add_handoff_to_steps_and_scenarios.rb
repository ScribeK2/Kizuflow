class AddHandoffToStepsAndScenarios < ActiveRecord::Migration[8.1]
  def change
    # SPIKE — the two columns Wave 2's tail call needs, and nothing else.
    #
    # `default: true` is what keeps every existing sub_flow step behaving
    # exactly as it does now: a sub-flow returns unless it is told not to.
    add_column :steps, :sub_flow_returns, :boolean, default: true, null: false

    # Which scenario handed the run to this one. Distinct from
    # parent_scenario_id on purpose: a parent is waiting to be returned to, and
    # the whole point of a handoff is that nobody is waiting.
    add_column :scenarios, :handed_off_from_id, :integer
    add_index :scenarios, :handed_off_from_id
  end
end
