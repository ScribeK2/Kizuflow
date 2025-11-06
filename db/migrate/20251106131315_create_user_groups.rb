class CreateUserGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :user_groups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :group, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_groups, [:user_id, :group_id], unique: true, name: "index_user_groups_on_user_and_group"
  end
end
