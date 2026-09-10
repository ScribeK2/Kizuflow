require "test_helper"

module Admin
  class AttentionTest < ActiveSupport::TestCase
    PRODUCTION = ActiveSupport::EnvironmentInquirer.new("production")
    TEST_ENV = ActiveSupport::EnvironmentInquirer.new("test")

    setup do
      SmtpSetting.delete_all
      # Fixture workflows persist in the test database, published and in no
      # group; left alone they would be a no-audience item in every count here.
      Workflow.where(id: Workflow.published_without_audience.select(:id)).update_all(status: "draft")
      User.create!(email: "attn-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                   password_confirmation: "password123!", role: "regular")
    end

    def attention(**overrides)
      Admin::Attention.new(env: TEST_ENV, environment_address: nil, adapter: :test, **overrides)
    end

    test "counts one item per kind of problem, not one per waiting user" do
      User.create!(email: "attn-editor-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                   password_confirmation: "password123!", role: "editor")

      result = attention
      assert_operator result.awaiting_groups_count, :>=, 2
      assert_equal 1, result.count
      assert_predicate result, :any?
    end

    test "an unconfigured relay in production is its own item" do
      result = attention(env: PRODUCTION)

      assert_predicate result, :email_unconfigured?
      assert_equal 2, result.count
    end

    test "failed and stalled jobs are items where Solid Queue runs the jobs" do
      job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanupDraftsJob")
      SolidQueue::FailedExecution.create!(job: job, error: { "message" => "boom" })
      SolidQueue::RecurringTask.create!(key: "sweep_idle_scenarios", class_name: "SweepIdleScenariosJob",
                                        schedule: "0 2 * * *", created_at: 3.days.ago, updated_at: 3.days.ago)
      SolidQueue::Process.create!(kind: "Worker", name: "worker-#{SecureRandom.hex(3)}", pid: 1,
                                  hostname: "test", last_heartbeat_at: Time.current)

      result = attention(adapter: :solid_queue)

      assert_equal 1, result.failed_jobs_count
      assert_equal ["sweep_idle_scenarios"], result.stalled_task_keys
      assert_equal 3, result.count
    end

    test "a worker with no heartbeat in five minutes is its own item" do
      SolidQueue::Process.create!(kind: "Worker", name: "worker-#{SecureRandom.hex(3)}", pid: 1,
                                  hostname: "test", last_heartbeat_at: 10.minutes.ago)

      result = attention(adapter: :solid_queue)

      assert_predicate result, :worker_down?
      assert_equal 2, result.count, "users waiting for a group, and the worker"
      assert_not attention.worker_down?
    end

    test "lists the failed executions and stalled tasks it counted" do
      job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanupDraftsJob")
      job.ready_execution.destroy!
      failed = SolidQueue::FailedExecution.create!(job: job, error: { "message" => "boom" })
      SolidQueue::RecurringTask.create!(key: "sweep_idle_scenarios", class_name: "SweepIdleScenariosJob",
                                        schedule: "0 2 * * *", created_at: 3.days.ago, updated_at: 3.days.ago)

      result = attention(adapter: :solid_queue)

      assert_predicate result, :jobs_tracked?
      assert_equal [failed], result.failed_executions.to_a
      assert_equal ["sweep_idle_scenarios"], result.stalled_tasks.map(&:key)
      assert_equal ["sweep_idle_scenarios"], result.stalled_task_keys
      assert_not attention.jobs_tracked?
    end

    test "nothing is waiting once every account has a group" do
      group = Group.create!(name: "Attn #{SecureRandom.hex(3)}")
      User.awaiting_groups.find_each { |user| UserGroup.create!(user: user, group: group) }

      assert_equal 0, attention.count
      assert_not attention.any?
    end

    test "published workflows with no audience are one item, listed newest first" do
      owner = User.create!(email: "attn-owner-#{SecureRandom.hex(4)}@example.com", password: "password123!",
                           password_confirmation: "password123!", role: "editor")
      older = Workflow.create!(title: "Older Forgotten", user: owner, updated_at: 2.days.ago)
      newer = Workflow.create!(title: "Newer Forgotten", user: owner)
      Workflow.create!(title: "Still a Draft", user: owner, status: "draft")
      file_in_global(Workflow.create!(title: "Chosen", user: owner))

      result = attention

      assert_equal 2, result.no_audience_count
      assert_equal [newer, older], result.no_audience_workflows.to_a
      assert_equal 2, result.count, "users waiting for a group, and workflows waiting for an audience"
    end
  end
end
