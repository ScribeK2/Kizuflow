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

  class << self
    def failed_count(adapter: default_adapter)
      return 0 unless solid_queue?(adapter)

      SolidQueue::FailedExecution.count
    end

    # Keys of recurring tasks that should have run by now and have not.
    def stalled_task_keys(adapter: default_adapter, now: Time.current)
      return [] unless solid_queue?(adapter) && finished_jobs_kept_long_enough?

      cutoff = now - STALE_AFTER
      SolidQueue::RecurringTask.where.not(class_name: nil)
                               .where(created_at: ...cutoff)
                               .order(:key)
                               .select { |task| stalled?(task, cutoff: cutoff, now: now) }
                               .map(&:key)
    end

    private

    def default_adapter
      Rails.application.config.active_job.queue_adapter
    end

    def solid_queue?(adapter)
      adapter.to_s == "solid_queue"
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
  end
end
