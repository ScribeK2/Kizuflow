require "test_helper"

# Rows are built by hand in the queue database, the way JobHealthTest does. A
# real failed job has no ReadyExecution, so the one after_create made is removed
# first — otherwise a retry's dispatch collides with it. Retry resets counters
# inside the serialized arguments, so the job carries real ones.
class Admin::FailedJobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "failed-jobs-admin-#{SecureRandom.hex(4)}@example.com",
                          password: "password123!", role: "admin")
    @editor = User.create!(email: "failed-jobs-editor-#{SecureRandom.hex(4)}@example.com",
                           password: "password123!", role: "editor")
    job = SolidQueue::Job.create!(queue_name: "default", class_name: "CleanupDraftsJob",
                                  arguments: CleanupDraftsJob.new.serialize)
    job.ready_execution.destroy!
    @failed = SolidQueue::FailedExecution.create!(job: job, error: { "exception_class" => "RuntimeError",
                                                                     "message" => "boom" })
  end

  test "retry queues the job again and clears the failure" do
    sign_in @admin

    post admin_failed_job_retry_path(@failed)

    assert_redirected_to admin_data_health_path(anchor: "background-jobs")
    assert_equal "Queued Cleanup drafts to run again.", flash[:notice]
    assert_not SolidQueue::FailedExecution.exists?(@failed.id)
    assert SolidQueue::ReadyExecution.exists?(job_id: @failed.job_id), "retry dispatches the job"
  end

  test "discard removes the job, not only its failure" do
    sign_in @admin

    delete admin_failed_job_path(@failed)

    assert_redirected_to admin_data_health_path(anchor: "background-jobs")
    assert_equal "Discarded Cleanup drafts. It will not run again.", flash[:notice]
    assert_not SolidQueue::FailedExecution.exists?(@failed.id)
    assert_not SolidQueue::Job.exists?(@failed.job_id)
  end

  test "a job someone already dealt with is a message, not an error page" do
    sign_in @admin
    @failed.discard

    post admin_failed_job_retry_path(@failed)
    assert_redirected_to admin_data_health_path(anchor: "background-jobs")
    assert_match(/no longer failed/, flash[:alert])

    delete admin_failed_job_path(@failed)
    assert_redirected_to admin_data_health_path(anchor: "background-jobs")
    assert_match(/no longer failed/, flash[:alert])
  end

  test "a non-admin can do neither" do
    sign_in @editor

    post admin_failed_job_retry_path(@failed)
    assert_redirected_to root_path
    delete admin_failed_job_path(@failed)
    assert_redirected_to root_path

    assert SolidQueue::FailedExecution.exists?(@failed.id)
  end
end
