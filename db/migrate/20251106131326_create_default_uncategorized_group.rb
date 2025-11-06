class CreateDefaultUncategorizedGroup < ActiveRecord::Migration[8.0]
  def up
    # Create default "Uncategorized" group for workflows without explicit group assignment
    # Check if it already exists to avoid duplicates
    unless Group.exists?(name: "Uncategorized")
      Group.create!(
        name: "Uncategorized",
        description: "Default group for workflows without explicit group assignment",
        position: 0
      )
    end
  end

  def down
    Group.find_by(name: "Uncategorized")&.destroy
  end
end
