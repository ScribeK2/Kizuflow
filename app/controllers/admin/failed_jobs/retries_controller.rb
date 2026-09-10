module Admin
  module FailedJobs
    # Retry. Solid Queue's own FailedExecution#retry: resets the job's counters,
    # dispatches it, and removes the failure.
    class RetriesController < BaseController
      include FailedJobScoped

      def create
        @failed_execution.retry
        audit("retried failed job #{@failed_execution.job_id} (#{@failed_execution.job.class_name})")
        redirect_to background_jobs_path, notice: "Queued #{failed_job_name} to run again."
      end
    end
  end
end
