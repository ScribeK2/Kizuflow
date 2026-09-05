class AddHandoffForeignKeyToScenarios < ActiveRecord::Migration[8.1]
  # `handed_off_from_id` shipped with an index and no foreign key, while its
  # sibling `parent_scenario_id` has carried ON DELETE SET NULL since it was
  # added. That asymmetry is not cosmetic: `CleanupScenariosJob` deletes with
  # `delete_all`, which bypasses callbacks, so `has_one :handed_off_to,
  # dependent: :nullify` never runs during retention. Reaping a handed-off
  # source left the column pointing at a row that no longer existed, and
  # `Scenario#run_origin` then resolved to the head itself — dropping the run's
  # entire transcript rather than just the part that was deleted.
  def up
    # A constraint cannot go on over rows that already violate it. Nothing in
    # production can have run this feature yet, but a dev or staging database
    # that exercised a handoff and then ran cleanup will have orphans, and a
    # migration that fails there is a migration nobody trusts.
    execute(<<~SQL.squish)
      UPDATE scenarios
         SET handed_off_from_id = NULL
       WHERE handed_off_from_id IS NOT NULL
         AND NOT EXISTS (
               SELECT 1 FROM scenarios AS existing
                WHERE existing.id = scenarios.handed_off_from_id
             )
    SQL

    add_foreign_key :scenarios, :scenarios, column: :handed_off_from_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :scenarios, column: :handed_off_from_id
  end
end
