module Admin
  # Discard. Solid Queue's own Execution#discard, which deletes the job along
  # with its failure — there is nothing left to retry afterwards.
  class FailedJobsController < BaseController
    include FailedJobScoped

    def destroy
      name = failed_job_name
      @failed_execution.discard
      audit("discarded failed job #{@failed_execution.job_id} (#{@failed_execution.job.class_name})")
      redirect_to background_jobs_path, notice: "Discarded #{name}. It will not run again."
    end
  end
end
