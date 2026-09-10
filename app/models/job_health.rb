# Whether the recurring jobs in config/recurring.yml are actually running.
#
# Read from Solid Queue's own tables rather than inferred from the data those
# jobs maintain. Both inferences false-alarm: "runs left open past the idle
# timeout" keys on a frame's updated_at, which stops while a parent is parked on
# a live sub-flow (see Scenario#run_frames); and "the newest rollup day is old"
# is also true of an instance nobody used for two days.
#
# Stalled relies on Solid Queue keeping finished jobs for a day, so a healthy
# daily task always has its latest run on hand. If that retention is shortened
# the check switches itself off rather than crying wolf.
#
# Only meaningful where Solid Queue runs the jobs — :async in development and
# :test in test have no rows, and report nothing.
class JobHealth
  STALE_AFTER = 26.hours
  UNPICKED_AFTER = 6.hours
  LISTED_FAILURES = 20

  # A nightly task that has not run, with what an admin needs to judge it.
  # last_finished_at is nil more often than not: Solid Queue keeps finished
  # jobs for a day, and a stalled task has had no run for longer than that.
  StalledTask = Data.define(:key, :schedule, :last_finished_at)

  class << self
    def tracked?(adapter: default_adapter)
      adapter.to_s == "solid_queue"
    end

    def failed_count(adapter: default_adapter)
      return 0 unless tracked?(adapter: adapter)

      SolidQueue::FailedExecution.count
    end

    # An array rather than FailedExecution.none when untracked, so a host with no
    # queue database never loads the model at all.
    def failed_executions(adapter: default_adapter, limit: LISTED_FAILURES)
      return [] unless tracked?(adapter: adapter)

      SolidQueue::FailedExecution.includes(:job).order(created_at: :desc, id: :desc).limit(limit)
    end

    # Recurring tasks that should have run by now and have not.
    def stalled_tasks(adapter: default_adapter, now: Time.current)
      return [] unless tracked?(adapter: adapter) && finished_jobs_kept_long_enough?

      cutoff = now - STALE_AFTER
      SolidQueue::RecurringTask.where.not(class_name: nil)
                               .where(created_at: ...cutoff)
                               .order(:key)
                               .select { |task| stalled?(task, cutoff: cutoff, now: now) }
                               .map { |task| stalled_task(task) }
    end

    def stalled_task_keys(adapter: default_adapter, now: Time.current)
      stalled_tasks(adapter: adapter, now: now).map(&:key)
    end

    # When any Solid Queue process last reported. The supervisor, worker,
    # dispatcher and scheduler each write a heartbeat every minute.
    def last_heartbeat_at(adapter: default_adapter)
      return unless tracked?(adapter: adapter)

      SolidQueue::Process.maximum(:last_heartbeat_at)
    end

    # No process has reported within Solid Queue's own alive threshold, so nothing
    # is running jobs. Reading the newest heartbeat means rows a restart left
    # behind can't hide a live process (spec Q74).
    def worker_down?(adapter: default_adapter, now: Time.current, heartbeat: last_heartbeat_at(adapter: adapter))
      return false unless tracked?(adapter: adapter)

      heartbeat.nil? || heartbeat < now - SolidQueue.process_alive_threshold
    end

    private

    def default_adapter
      Rails.application.config.active_job.queue_adapter
    end

    def finished_jobs_kept_long_enough?
      SolidQueue.preserve_finished_jobs? && SolidQueue.clear_finished_jobs_after >= 1.day
    end

    def stalled?(task, cutoff:, now:)
      latest = SolidQueue::Job.where(class_name: task.class_name, created_at: cutoff..)
                              .order(created_at: :desc)
                              .first
      return true if latest.nil?
      return false if latest.finished_at.present?
      return false if latest.created_at > now - UNPICKED_AFTER

      SolidQueue::FailedExecution.where(job_id: latest.id).none? &&
        SolidQueue::ClaimedExecution.where(job_id: latest.id).none?
    end

    def stalled_task(task)
      last_finished_at = SolidQueue::Job.where(class_name: task.class_name).where.not(finished_at: nil)
                                        .maximum(:finished_at)
      StalledTask.new(key: task.key, schedule: task.schedule, last_finished_at: last_finished_at)
    end
  end
end
