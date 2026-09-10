# What db/migrate/20260910120000_turn_uncategorized_into_global.rb will change.
# Reads only. Run it against production BEFORE deploying Stage 4a:
#
#   bin/rails runner db/scripts/preview_global_migration.rb
#
# Table-level models only, so it runs on the code that is live today. It prints
# titles, not just counts: these are the workflows whose audience changes.
module PreviewGlobalMigration
  class Group < ActiveRecord::Base
    self.table_name = "groups"
  end

  class GroupWorkflow < ActiveRecord::Base
    self.table_name = "group_workflows"
  end

  class UserGroup < ActiveRecord::Base
    self.table_name = "user_groups"
  end

  class Workflow < ActiveRecord::Base
    self.table_name = "workflows"
  end

  class User < ActiveRecord::Base
    self.table_name = "users"
  end

  def self.run
    uncategorized = Group.find_by(name: "Uncategorized", parent_id: nil)
    global = Group.find_by(name: "Global", parent_id: nil)
    if uncategorized && global
      $stdout.puts "BLOCKED: a root Uncategorized (##{uncategorized.id}) and a root Global (##{global.id}) both " \
                   "exist. The migration refuses to run until one is renamed."
      return
    end

    target = uncategorized || global
    report_target(target)
    public_ids = Workflow.where(is_public: true).pluck(:id)
    section("Filed into Global because they were Public — everyone signed in will see these", public_ids)

    still_grouped = GroupWorkflow.where.not(group_id: target&.id).select(:workflow_id)
    no_audience = Workflow.where(status: "published").where.not(id: still_grouped).where.not(id: public_ids).pluck(:id)
    section("Published with NO audience afterwards — only admins and each owner see these until someone " \
            "chooses groups; the admin Overview will list them", no_audience)
  end

  def self.report_target(target)
    unless target
      $stdout.puts "No Uncategorized group: the migration creates Global."
      return
    end

    $stdout.puts "Group ##{target.id} \"#{target.name}\" becomes Global."
    children = Group.where(parent_id: target.id).pluck(:name)
    $stdout.puts "BLOCKED: it has subgroups (#{children.join(', ')}). Move them before deploying." if children.any?
    section("Taken out of it — each loses this group", GroupWorkflow.where(group_id: target.id).pluck(:workflow_id))
    emails = User.where(id: UserGroup.where(group_id: target.id).select(:user_id)).order(:email).pluck(:email)
    $stdout.puts "", "Memberships removed (#{emails.size}):", *emails.map { "    - #{it}" }
  end

  def self.section(heading, workflow_ids)
    rows = Workflow.where(id: workflow_ids).order(:title).pluck(:title, :status)
    $stdout.puts "", "#{heading} (#{rows.size}):", *rows.map { |title, status| "    - #{title} (#{status})" }
  end
end

PreviewGlobalMigration.run
