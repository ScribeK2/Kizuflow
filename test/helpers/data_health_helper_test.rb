require "test_helper"

class DataHealthHelperTest < ActionView::TestCase
  include DataHealthHelper

  test "a job's name drops its namespace and the Job suffix" do
    assert_equal "Cleanup drafts", admin_job_name("CleanupDraftsJob")
    assert_equal "Mail delivery", admin_job_name("ActionMailer::MailDeliveryJob")
    assert_equal "Command", admin_job_name(nil)
  end

  test "a daily cron reads as a time, anything else as itself" do
    assert_equal "Daily at 02:00", admin_schedule_label("0 2 * * *")
    assert_equal "Daily at 02:30", admin_schedule_label("30 2 * * *")
    assert_equal "Every hour at minute 12", admin_schedule_label("every hour at minute 12")
  end

  test "a failed job's error reads as one line, and in full behind it" do
    execution = SolidQueue::FailedExecution.new(error: { "exception_class" => "RuntimeError",
                                                         "message" => "boom\nsecond line",
                                                         "backtrace" => ["app/jobs/a.rb:1", "app/jobs/b.rb:2"] })

    assert_equal "RuntimeError: boom", admin_job_error_line(execution)
    assert_equal "RuntimeError: boom\nsecond line\napp/jobs/a.rb:1\napp/jobs/b.rb:2", admin_job_error_detail(execution)
    assert_equal "boom", admin_job_error_line(SolidQueue::FailedExecution.new(error: { "message" => "boom" }))
  end
end
