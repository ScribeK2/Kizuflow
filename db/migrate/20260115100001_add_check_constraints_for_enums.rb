class AddCheckConstraintsForEnums < ActiveRecord::Migration[8.0]
  def up
    # Add CHECK constraint for users.role
    # Ensures only valid roles can be stored at the database level
    if connection.adapter_name.downcase.include?('postgresql')
      execute <<-SQL
        ALTER TABLE users
        ADD CONSTRAINT check_users_role
        CHECK (role IN ('admin', 'editor', 'user'));
      SQL

      # Add CHECK constraint for simulations.status
      execute <<-SQL
        ALTER TABLE simulations
        ADD CONSTRAINT check_simulations_status
        CHECK (status IN ('active', 'completed', 'stopped', 'timeout', 'error'));
      SQL

      # Add CHECK constraint for workflows.status
      execute <<-SQL
        ALTER TABLE workflows
        ADD CONSTRAINT check_workflows_status
        CHECK (status IN ('draft', 'published'));
      SQL
    else
      # SQLite: CHECK constraints via column redefinition
      # Note: SQLite supports CHECK but adding to existing columns requires table rebuild
      # For SQLite, we rely on model validations (which is acceptable for dev/test)
      Rails.logger.info "Skipping CHECK constraints for SQLite - using model validations only"
    end
  end

  def down
    if connection.adapter_name.downcase.include?('postgresql')
      execute "ALTER TABLE users DROP CONSTRAINT IF EXISTS check_users_role;"
      execute "ALTER TABLE simulations DROP CONSTRAINT IF EXISTS check_simulations_status;"
      execute "ALTER TABLE workflows DROP CONSTRAINT IF EXISTS check_workflows_status;"
    end
  end
end
