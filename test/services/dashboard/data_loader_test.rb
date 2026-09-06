require "test_helper"

class Dashboard::DataLoaderTest < ActiveSupport::TestCase
  def setup
    @admin = User.create!(
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "admin"
    )
    @editor = User.create!(
      email: "editor-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    @regular = User.create!(
      email: "csr-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!"
    )
    @workflow = Workflow.create!(title: "Test Flow", user: @editor, is_public: true)
  end

  # -- CSR detection --

  test "csr? is true for regular users" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_predicate loader, :csr?
  end

  test "csr? is false for editors" do
    loader = Dashboard::DataLoader.new(@editor)
    assert_not loader.csr?
  end

  test "csr? is false for admins" do
    loader = Dashboard::DataLoader.new(@admin)
    assert_not loader.csr?
  end

  # -- Pinned workflows --

  test "pinned_workflows returns pinned workflows" do
    UserWorkflowPin.create!(user: @regular, workflow: @workflow)
    loader = Dashboard::DataLoader.new(@regular)
    assert_includes loader.pinned_workflows, @workflow
  end

  test "pinned_workflows is empty when no pins" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_empty loader.pinned_workflows
  end

  test "pinned_workflows excludes unpublished workflows" do
    UserWorkflowPin.create!(user: @regular, workflow: @workflow)
    @workflow.update!(status: "draft")
    loader = Dashboard::DataLoader.new(@regular)
    assert_empty loader.pinned_workflows
  end

  # -- CSR stats --

  test "personal_scenario_total counts live scenarios only" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "simulation", status: "completed")

    loader = Dashboard::DataLoader.new(@regular)
    assert_equal 1, loader.personal_scenario_total
  end

  test "scenarios_this_week counts only live scenarios in current week" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "active")
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "simulation", status: "completed")

    loader = Dashboard::DataLoader.new(@regular)
    assert_equal 2, loader.scenarios_this_week
  end

  test "scenarios_this_week returns 0 with no scenarios" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_equal 0, loader.scenarios_this_week
  end

  test "personal_completion_rate calculates from live scenarios" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "active")

    loader = Dashboard::DataLoader.new(@regular)
    assert_equal 50, loader.personal_completion_rate
  end

  test "personal_completion_rate returns 0 with no scenarios" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_equal 0, loader.personal_completion_rate
  end

  test "most_used_workflow returns hash with workflow and count" do
    other_wf = Workflow.create!(title: "Other Flow", user: @editor, is_public: true)
    3.times { Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed") }
    Scenario.create!(workflow: other_wf, user: @regular, purpose: "live", status: "completed")

    loader = Dashboard::DataLoader.new(@regular)
    result = loader.most_used_workflow
    assert_equal @workflow, result[:workflow]
    assert_equal 3, result[:count]
  end

  test "most_used_workflow returns nil with no scenarios" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_nil loader.most_used_workflow
  end

  # -- SME company-wide stats --

  test "company_scenario_total counts all scenarios" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @editor, purpose: "simulation", status: "active")

    loader = Dashboard::DataLoader.new(@editor)
    assert_equal 2, loader.company_scenario_total
  end

  test "company_completion_rate calculates across all users" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @editor, purpose: "simulation", status: "completed")
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "active")

    loader = Dashboard::DataLoader.new(@editor)
    assert_equal 67, loader.company_completion_rate
  end

  test "company_completion_rate returns 0 with no scenarios" do
    loader = Dashboard::DataLoader.new(@editor)
    assert_equal 0, loader.company_completion_rate
  end

  test "company_scenarios_this_week counts all scenarios this week" do
    Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    Scenario.create!(workflow: @workflow, user: @editor, purpose: "simulation", status: "active")

    loader = Dashboard::DataLoader.new(@editor)
    assert_equal 2, loader.company_scenarios_this_week
  end

  # -- Shared --

  # -- Slice 1: every number on a surface shares one scope ----------------------
  #
  # The SME dashboard mixed three company-wide stat cards with a personal
  # activity feed, under copy reading "Scenarios run by your team". It also
  # computed `published = workflow_count - draft_count`, subtracting the admin's
  # own drafts from a number that came from `visible_to` and had therefore never
  # contained a draft: an admin owning 11 drafts saw "10 published" when 21 were.

  test "published_workflow_count never subtracts drafts from a published-only scope" do
    2.times { |i| Workflow.create!(title: "Pub #{i}", user: @editor, status: "published") }
    3.times { |i| Workflow.create!(title: "Mine #{i}", user: @admin, status: "draft") }

    loader = Dashboard::DataLoader.new(@admin)

    assert_equal Workflow.published.count, loader.published_workflow_count,
                 "an admin sees every published workflow, regardless of how many drafts they own"
  end

  test "draft_count is org-wide for an admin" do
    Workflow.create!(title: "Someone else's draft", user: @editor, status: "draft")
    Workflow.create!(title: "My draft", user: @admin, status: "draft")

    # Against the real total rather than a literal: an admin's figure is the
    # org's figure, which is the whole point, and fixtures may add their own.
    assert_equal Workflow.drafts.count, Dashboard::DataLoader.new(@admin).draft_count
    assert_operator Dashboard::DataLoader.new(@admin).draft_count, :>=, 2
  end

  test "draft_count is own drafts only for an editor" do
    Workflow.create!(title: "Admin draft", user: @admin, status: "draft")
    Workflow.create!(title: "Editor draft", user: @editor, status: "draft")

    assert_equal 1, Dashboard::DataLoader.new(@editor).draft_count,
                 "an editor must not see a colleague's unpublished work"
    assert_operator Workflow.drafts.count, :>, 1,
                    "the assertion above is vacuous unless other drafts exist"
  end

  test "draft_count is zero for a regular user" do
    Workflow.create!(title: "Editor draft", user: @editor, status: "draft")

    assert_equal 0, Dashboard::DataLoader.new(@regular).draft_count
  end

  test "company_recent_scenarios includes runs by other people" do
    theirs = Scenario.create!(workflow: @workflow, user: @editor, purpose: "live",
                              started_at: Time.current, execution_path: [], results: {}, inputs: {})

    assert_includes Dashboard::DataLoader.new(@admin).company_recent_scenarios, theirs,
                    "the card next to this feed counts every scenario, so the feed must too"
  end

  test "recent_scenarios stays personal, because the CSR dashboard means yours" do
    Scenario.create!(workflow: @workflow, user: @editor, purpose: "live",
                     started_at: Time.current, execution_path: [], results: {}, inputs: {})

    assert_empty Dashboard::DataLoader.new(@regular).recent_scenarios
  end

  test "company_scenario_active counts live runs across everyone" do
    Scenario.create!(workflow: @workflow, user: @editor, purpose: "live", status: "active",
                     started_at: Time.current, execution_path: [], results: {}, inputs: {})

    assert_equal 1, Dashboard::DataLoader.new(@admin).company_scenario_active
  end

  test "workflow_count returns visible workflows count" do
    loader = Dashboard::DataLoader.new(@editor)
    assert_operator loader.workflow_count, :>=, 1, "Expected at least 1 visible workflow"
  end

  # Was "draft_count returns user drafts only" — true for an editor, and it stayed
  # true, but it was silently also the rule for admins, which is what hid 23
  # org-wide drafts from the only people who could act on them.
  test "draft_count returns the drafts the viewer is allowed to see" do
    Workflow.create!(title: "Draft Flow", user: @editor, status: "draft")

    assert_equal 1, Dashboard::DataLoader.new(@editor).draft_count
  end

  test "workflows returns recent workflows" do
    loader = Dashboard::DataLoader.new(@regular)
    assert_includes loader.workflows, @workflow
  end

  test "recent_scenarios returns user scenarios" do
    scenario = Scenario.create!(workflow: @workflow, user: @regular, purpose: "live", status: "completed")
    loader = Dashboard::DataLoader.new(@regular)
    assert_includes loader.recent_scenarios, scenario
  end
end
