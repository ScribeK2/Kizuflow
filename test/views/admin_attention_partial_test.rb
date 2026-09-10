require "test_helper"

# The Overview's rows for the checks an integration test cannot reach: in the
# test environment mail is deliberately unconfigured-but-fine and Solid Queue is
# not the adapter, so those rows are rendered here from an injected Attention.
class AdminAttentionPartialTest < ActionView::TestCase
  PRODUCTION = ActiveSupport::EnvironmentInquirer.new("production")

  setup { SmtpSetting.delete_all }

  test "an unconfigured relay renders a row linking to Email" do
    render partial: "admin/dashboard/attention",
           locals: { attention: Admin::Attention.new(env: PRODUCTION, environment_address: nil, adapter: :test) }

    assert_select "#attention-email", text: /Email can.t be sent/
    assert_select "#attention-email a[href=?]", admin_smtp_setting_path
  end

  test "failed and stalled jobs render rows linking to Data Health" do
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanupDraftsJob")
    SolidQueue::FailedExecution.create!(job: job, error: { "message" => "boom" })
    SolidQueue::RecurringTask.create!(key: "sweep_idle_scenarios", class_name: "SweepIdleScenariosJob",
                                      schedule: "0 2 * * *", created_at: 3.days.ago, updated_at: 3.days.ago)

    render partial: "admin/dashboard/attention", locals: { attention: Admin::Attention.new(adapter: :solid_queue) }

    assert_select "#attention-failed-jobs", text: /1 background job failed/
    assert_select "#attention-failed-jobs a[href=?]", admin_data_health_path
    assert_select "#attention-stalled-jobs", text: /Sweep idle scenarios/
  end
end
