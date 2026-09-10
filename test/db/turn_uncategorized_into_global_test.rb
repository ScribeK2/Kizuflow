require "test_helper"
require Rails.root.join("db/migrate/20260910120000_turn_uncategorized_into_global.rb").to_s

# The migration only moves rows, so it can run inside the test transaction.
class TurnUncategorizedIntoGlobalTest < ActiveSupport::TestCase
  setup do
    Group.global.delete_all
    # Fixture rows persist in the test database, and workflows.yml has a public
    # one; the migration would rightly file it into Global too.
    TurnUncategorizedIntoGlobal::MigrationWorkflow.update_all(is_public: false)
    @owner = User.create!(email: "mig-owner-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                          password_confirmation: "password123!", role: "editor")
  end

  test "Uncategorized becomes Global, keeping its id and losing its workflows and members" do
    uncategorized = Group.create!(name: "Uncategorized")
    filed = Workflow.create!(title: "Filed There", user: @owner)
    GroupWorkflow.create!(group: uncategorized, workflow: filed, is_primary: true)
    UserGroup.create!(group: uncategorized, user: @owner)

    migrate

    global = Group.find(uncategorized.id)
    assert_predicate global, :global?
    assert_empty global.group_workflows
    assert_empty global.user_groups
    assert_empty filed.reload.groups
  end

  test "Public workflows are filed into Global, primary only when they had no primary" do
    Group.create!(name: "Uncategorized")
    department = Group.create!(name: "Department #{SecureRandom.hex(3)}")
    loose = public_workflow("Loose Public")
    grouped = public_workflow("Grouped Public")
    GroupWorkflow.create!(group: department, workflow: grouped, is_primary: true)
    private_one = Workflow.create!(title: "Not Public", user: @owner)

    migrate

    global = Group.global.first
    assert_predicate GroupWorkflow.find_by(group: global, workflow: loose), :is_primary?
    assert_not GroupWorkflow.find_by(group: global, workflow: grouped).is_primary?
    assert_nil GroupWorkflow.find_by(group: global, workflow: private_one)
  end

  test "with no Uncategorized group, Global is created" do
    assert_difference -> { Group.global.count }, 1 do
      migrate
    end
  end

  test "refuses to guess when both Uncategorized and Global exist" do
    Group.create!(name: "Uncategorized")
    Group.create!(name: Group::GLOBAL_NAME)

    error = assert_raises(RuntimeError) { migrate }
    assert_match(/Both a root Uncategorized and a root Global group exist/, error.message)
  end

  test "refuses when Uncategorized has subgroups, which Global may not" do
    uncategorized = Group.create!(name: "Uncategorized")
    Group.create!(name: "Stray", parent: uncategorized)

    error = assert_raises(RuntimeError) { migrate }
    assert_match(/has subgroups/, error.message)
  end

  private

  def migrate
    TurnUncategorizedIntoGlobal.new.up
  end

  # is_public is ignored by Workflow from Stage 4a on, so set it through the
  # migration's own table-level model. update_all bumps lock_version on a locked
  # table, so hand back a fresh copy or the next touch is a StaleObjectError.
  def public_workflow(title)
    workflow = Workflow.create!(title: title, user: @owner)
    TurnUncategorizedIntoGlobal::MigrationWorkflow.where(id: workflow.id).update_all(is_public: true)
    workflow.reload
  end
end
