class AddGinIndexOnWorkflowsSteps < ActiveRecord::Migration[8.0]
  def change
    # Add GIN index on steps JSONB column to enable DISTINCT queries in PostgreSQL
    # This fixes: PG::UndefinedFunction: ERROR: could not identify an equality operator for type json
    # Rails 8.0 uses JSONB for t.json columns in PostgreSQL
    add_index :workflows, :steps, using: :gin, name: 'index_workflows_on_steps'
  end
end
