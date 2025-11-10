class AddStatusToWorkflows < ActiveRecord::Migration[8.0]
  def change
    # Add status enum column (draft or published)
    # Default to 'published' for backward compatibility with existing workflows
    add_column :workflows, :status, :string, default: 'published', null: false
    
    # Add draft expiration timestamp for cleanup
    add_column :workflows, :draft_expires_at, :datetime, null: true
    
    # Add indexes for efficient queries
    add_index :workflows, :status
    add_index :workflows, [:status, :user_id]
    add_index :workflows, :draft_expires_at
    
    # Set all existing workflows to published status (they're already published)
    # This is redundant but explicit for clarity
    execute "UPDATE workflows SET status = 'published' WHERE status IS NULL OR status = ''"
  end
end

