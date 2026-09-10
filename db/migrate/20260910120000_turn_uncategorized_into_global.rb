# Uncategorized becomes Global: the group everyone signed in can see.
#
# Stage 4a of the admin redesign (spec Q39, Q41, Q46, Q48). Uncategorized was
# never "for everyone": auto-filing put new published workflows there, and a
# Regular user saw none of them. Renaming it without emptying it would show
# everyone every workflow somebody forgot to group, so what it holds is taken
# out (Q46). Those workflows keep any other group, or have no audience until
# someone chooses one, and the admin Overview lists them. Public workflows were
# the ones meant for everyone, so they are filed into Global (Q48).
#
# Preview the effect on real data first — it reads only:
#   bin/rails runner db/scripts/preview_global_migration.rb
#
# Inline models, so a later change to Group or Workflow cannot change what
# this does.
class TurnUncategorizedIntoGlobal < ActiveRecord::Migration[8.1]
  class MigrationGroup < ActiveRecord::Base
    self.table_name = "groups"
  end

  class MigrationGroupWorkflow < ActiveRecord::Base
    self.table_name = "group_workflows"
  end

  class MigrationUserGroup < ActiveRecord::Base
    self.table_name = "user_groups"
  end

  class MigrationWorkflow < ActiveRecord::Base
    self.table_name = "workflows"
  end

  DESCRIPTION = "Everyone signed in can see workflows filed here.".freeze

  def up
    global = rename_or_create_global
    file_public_workflows_into(global)
  end

  # The rows taken out of Uncategorized are gone. Renaming the group back would
  # not restore who could see what, so this does not pretend to.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def rename_or_create_global
    uncategorized = MigrationGroup.find_by(name: "Uncategorized", parent_id: nil)
    global = MigrationGroup.find_by(name: "Global", parent_id: nil)
    if uncategorized && global
      raise "Both a root Uncategorized and a root Global group exist " \
            "(ids #{uncategorized.id}, #{global.id}). Rename one, then migrate."
    end

    group = uncategorized || global
    # No position: 20260910130000 drops that column, and this migration's test
    # runs it against the schema as it is now.
    return MigrationGroup.create!(name: "Global", description: DESCRIPTION) unless group

    if MigrationGroup.exists?(parent_id: group.id)
      raise "Group ##{group.id} (#{group.name}) has subgroups, and Global may not. Move them, then migrate."
    end

    MigrationGroupWorkflow.where(group_id: group.id).delete_all
    MigrationUserGroup.where(group_id: group.id).delete_all
    group.update!(name: "Global", description: DESCRIPTION)
    group
  end

  def file_public_workflows_into(global)
    public_ids = MigrationWorkflow.where(is_public: true).pluck(:id)
    return if public_ids.empty?

    has_primary = MigrationGroupWorkflow.where(workflow_id: public_ids, is_primary: true).distinct.pluck(:workflow_id).to_set
    now = Time.current
    rows = public_ids.map do |workflow_id|
      { group_id: global.id, workflow_id: workflow_id, is_primary: has_primary.exclude?(workflow_id),
        created_at: now, updated_at: now }
    end
    MigrationGroupWorkflow.insert_all(rows)
  end
end
