# Trend history that outlives the runs it describes.
#
# Scenarios are deleted at the retention horizon (7 days simulation, 90 live), so
# every aggregate the analytics page draws quietly stopped meaning what it said —
# "all time" meant "the last 90 days" and nobody was told. Rolling a day up before
# its runs are deleted decouples "how long do we keep the transcript" from "how
# long do we keep the trend", which is the coupling that forced the choice.
#
# Two tables because the two questions have different grains. The daily table
# cannot answer "which step do agents bail at" — that is read from
# execution_path.last on individual runs, so it needs its own rollup or it is the
# one report that still dies at the horizon.
class CreateScenarioRollups < ActiveRecord::Migration[8.1]
  def change
    create_table :scenario_rollups do |t|
      t.references :workflow, null: false, foreign_key: true
      t.date :day, null: false
      t.string :purpose, null: false
      # "pending" is the sentinel for a run that had not settled when the day was
      # rolled. Not NULL: a unique index does not constrain NULLs in Postgres, so
      # a nullable column here would silently permit duplicate rows.
      t.string :outcome, null: false
      t.integer :runs_count, null: false, default: 0
      # SUM and COUNT rather than an average, so averages compose across days.
      # Storing a mean per day and averaging the means weights a quiet day the
      # same as a busy one.
      t.integer :duration_sum_seconds, null: false, default: 0
      t.integer :duration_count, null: false, default: 0
      t.timestamps
    end
    add_index :scenario_rollups, %i[workflow_id day purpose outcome],
              unique: true, name: "index_scenario_rollups_on_grain"
    add_index :scenario_rollups, :day

    create_table :scenario_dropoff_rollups do |t|
      t.references :workflow, null: false, foreign_key: true
      t.date :day, null: false
      t.string :step_title, null: false
      t.integer :runs_count, null: false, default: 0
      t.timestamps
    end
    add_index :scenario_dropoff_rollups, %i[workflow_id day step_title],
              unique: true, name: "index_scenario_dropoff_rollups_on_grain"
    add_index :scenario_dropoff_rollups, :day
  end
end
