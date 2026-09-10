require "test_helper"

module Admin
  class AttentionTest < ActiveSupport::TestCase
    PRODUCTION = ActiveSupport::EnvironmentInquirer.new("production")
    TEST_ENV = ActiveSupport::EnvironmentInquirer.new("test")

    setup do
      SmtpSetting.delete_all
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

      result = attention(adapter: :solid_queue)

      assert_equal 1, result.failed_jobs_count
      assert_equal ["sweep_idle_scenarios"], result.stalled_task_keys
      assert_equal 3, result.count
    end

    test "nothing is waiting once every account has a group" do
      group = Group.create!(name: "Attn #{SecureRandom.hex(3)}")
      User.awaiting_groups.find_each { |user| UserGroup.create!(user: user, group: group) }

      assert_equal 0, attention.count
      assert_not attention.any?
    end
  end
end
