require "test_helper"

# Solid Queue runs jobs only in production, so no controller test, system test or
# dev browser ever sees a failed-job row. The rows are rendered here from an
# Attention built for the production adapter, over rows made by hand.
class AdminBackgroundJobsPartialTest < ActionView::TestCase
  def failed_job(class_name, at: Time.current, message: "boom")
    job = SolidQueue::Job.create!(queue_name: "default", class_name: class_name)
    job.ready_execution.destroy!
    SolidQueue::FailedExecution.create!(job: job, created_at: at,
                                        error: { "exception_class" => "RuntimeError", "message" => message,
                                                 "backtrace" => ["app/jobs/example.rb:1"] })
  end

  def render_jobs(adapter: :solid_queue)
    render partial: "admin/data_health/background_jobs", locals: { attention: Admin::Attention.new(adapter: adapter) }
  end

  test "where Solid Queue does not run the jobs it says there is nothing to report" do
    render_jobs(adapter: :test)

    assert_select "#background-jobs", text: /nothing to report/
    assert_select "#failed-jobs", 0
    assert_select ".stat-panel", 0
  end

  test "each failed job has its name, its error, the full error behind a disclosure, Retry and Discard" do
    failed = failed_job("CleanupDraftsJob", at: 2.hours.ago, message: "boom\nsecond line")

    render_jobs

    row = "#failed-jobs ##{dom_id(failed)}"
    assert_select "#{row} .list-row__title", text: "Cleanup drafts"
    assert_select "#{row} .list-row__sub", text: /\AFailed about 2 hours ago · RuntimeError: boom\z/
    assert_select "#{row} details summary", text: "Full error"
    assert_select "#{row} details pre", text: %r{second line\napp/jobs/example.rb:1}
    assert_select "#{row} form[action=?] button.btn--secondary", admin_failed_job_retry_path(failed), text: "Retry"
    assert_select "#{row} form[action=?][data-turbo-confirm] button.btn--plain", admin_failed_job_path(failed),
                  text: "Discard"
    assert_select "#{row} form[action=?] input[name=_method][value=delete]", admin_failed_job_path(failed)
    assert_select "#background-jobs .btn--primary, #background-jobs .btn--negative", 0
  end

  test "lists the newest twenty and says how many there are" do
    (JobHealth::LISTED_FAILURES + 1).times { |i| failed_job("CleanupDraftsJob", at: i.hours.ago) }

    render_jobs

    assert_select "#failed-jobs .list-row", JobHealth::LISTED_FAILURES
    assert_select "#background-jobs .stat-cell__value", text: "21"
    assert_select "#background-jobs", text: /Showing the newest 20 of 21/
  end

  test "a stalled nightly job shows its schedule and its last finished run" do
    SolidQueue::RecurringTask.create!(key: "sweep_idle_scenarios", class_name: "SweepIdleScenariosJob",
                                      schedule: "0 2 * * *", created_at: 3.days.ago, updated_at: 3.days.ago)

    render_jobs

    assert_select "#stalled-jobs .list-row__title", text: "Sweep idle scenarios"
    assert_select "#stalled-jobs .list-row__sub", text: "Daily at 02:00 · Last finished: none on record"
    assert_select "#stalled-jobs form", 0, "no Run-now button (Q53)"
  end

  test "nothing failed and nothing stalled reads as healthy" do
    render_jobs

    assert_select "#background-jobs .stat-cell__value", text: "0", count: 2
    assert_select "#failed-jobs, #stalled-jobs", 0
  end
end
