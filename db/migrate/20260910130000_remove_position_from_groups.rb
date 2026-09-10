# Groups sort by name everywhere since the admin redesign (spec Q33), and nothing
# has read or written this column since Stage 4b dropped its field (Q60). Folders
# keep their own position: drag reorder uses it.
class RemovePositionFromGroups < ActiveRecord::Migration[8.1]
  def change
    remove_index :groups, %i[parent_id position], name: "index_groups_on_parent_id_and_position"
    remove_column :groups, :position, :integer
  end
end
