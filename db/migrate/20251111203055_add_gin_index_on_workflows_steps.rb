class AddGinIndexOnWorkflowsSteps < ActiveRecord::Migration[8.0]
  def up
    # Remove existing index if it exists (may be a non-GIN index)
    remove_index :workflows, :steps, if_exists: true
    
    # Convert json column to jsonb if needed (idempotent - safe if already jsonb)
    # This is necessary because GIN indexes only work on jsonb, not json
    if connection.adapter_name == 'PostgreSQL'
      execute <<-SQL
        ALTER TABLE workflows 
        ALTER COLUMN steps TYPE jsonb USING steps::jsonb;
      SQL
    end
    
    # Add GIN index on steps JSONB column to enable DISTINCT queries in PostgreSQL
    # This fixes: PG::UndefinedFunction: ERROR: could not identify an equality operator for type json
    add_index :workflows, :steps, using: :gin, name: 'index_workflows_on_steps'
  end

  def down
    remove_index :workflows, :steps, if_exists: true
    
    # Optionally convert back to json (but this is usually not necessary)
    # Leaving as jsonb is fine and actually preferred for performance
  end
end
