# frozen_string_literal: true

class AddAwaitingSubflowToSimulationsStatusCheck < ActiveRecord::Migration[8.0]
  def up
    return unless connection.adapter_name.downcase.include?('postgresql')

    execute <<-SQL
      ALTER TABLE simulations DROP CONSTRAINT IF EXISTS check_simulations_status;
    SQL
    execute <<-SQL
      ALTER TABLE simulations
      ADD CONSTRAINT check_simulations_status
      CHECK (status IN ('active', 'completed', 'stopped', 'timeout', 'error', 'awaiting_subflow'));
    SQL
  end

  def down
    return unless connection.adapter_name.downcase.include?('postgresql')

    execute <<-SQL
      ALTER TABLE simulations DROP CONSTRAINT IF EXISTS check_simulations_status;
    SQL
    execute <<-SQL
      ALTER TABLE simulations
      ADD CONSTRAINT check_simulations_status
      CHECK (status IN ('active', 'completed', 'stopped', 'timeout', 'error'));
    SQL
  end
end
