require "test_helper"

# Rows are built by hand in the queue database. Note that SolidQueue::Job's
# after_create dispatches every job, so each one here also gets a
# ReadyExecution — finished ones included. JobHealth only reads Failed and
# Claimed executions, so those extra rows are expected, not a setup mistake.
class JobHealthTest < ActiveSupport::TestCase
  NOW = Time.zone.parse("2026-09-10 12:00")

  def register(key, class_name, registered_at: NOW - 3.days)
    SolidQueue::RecurringTask.create!(key: key, class_name: class_name, schedule: "0 2 * * *",
                                      created_at: registered_at, updated_at: registered_at)
  end

  def enqueue(class_name, at:, finished: false)
    SolidQueue::Job.create!(queue_name: "default", class_name: class_name, created_at: at, updated_at: at,
                            finished_at: (at + 1.minute if finished))
  end

  def fail!(job)
    SolidQueue::FailedExecution.create!(job: job, error: { "message" => "boom" })
  end

  test "reports nothing where Solid Queue does not run the jobs" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob")
    fail!(enqueue("CleanupDraftsJob", at: NOW - 1.hour))

    assert_equal 0, JobHealth.failed_count(adapter: :test)
    assert_empty JobHealth.stalled_task_keys(adapter: :async, now: NOW)
  end

  test "counts failed executions" do
    fail!(enqueue("CleanupDraftsJob", at: NOW - 1.hour))

    assert_equal 1, JobHealth.failed_count(adapter: :solid_queue)
  end

  test "a task that ran inside the window is healthy" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob")
    enqueue("SweepIdleScenariosJob", at: NOW - 10.hours, finished: true)

    assert_empty JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end

  test "a task with no run inside the window is stalled" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob")
    enqueue("SweepIdleScenariosJob", at: NOW - 30.hours, finished: true)

    assert_equal ["sweep_idle_scenarios"], JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end

  test "a newly registered task gets its first window before it can be stalled" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob", registered_at: NOW - 2.hours)

    assert_empty JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end

  test "a run nothing picked up for hours is stalled; one a worker holds is not" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob")
    job = enqueue("SweepIdleScenariosJob", at: NOW - 8.hours)
    assert_equal ["sweep_idle_scenarios"], JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)

    process = SolidQueue::Process.create!(kind: "Worker", name: "worker-#{SecureRandom.hex(3)}", pid: 1,
                                          hostname: "test", last_heartbeat_at: NOW)
    SolidQueue::ClaimedExecution.create!(job: job, process: process)
    assert_empty JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end

  test "a failed run is reported as failed, not also as stalled" do
    register("sweep_idle_scenarios", "SweepIdleScenariosJob")
    fail!(enqueue("SweepIdleScenariosJob", at: NOW - 8.hours))

    assert_empty JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end

  test "command tasks are not checked" do
    SolidQueue::RecurringTask.create!(key: "clear_finished", command: "SolidQueue::Job.count",
                                      schedule: "0 * * * *", created_at: NOW - 3.days, updated_at: NOW - 3.days)

    assert_empty JobHealth.stalled_task_keys(adapter: :solid_queue, now: NOW)
  end
end
