class AddLimitToUsersDisplayName < ActiveRecord::Migration[8.0]
  def up
    # Add string length limit to display_name column
    # This ensures PostgreSQL enforces the same limit as the model validation
    change_column :users, :display_name, :string, limit: 50
  end

  def down
    # Remove the limit (revert to default varchar(255))
    change_column :users, :display_name, :string, limit: nil
  end
end
