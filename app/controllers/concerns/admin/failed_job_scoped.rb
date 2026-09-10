module Admin
  # A failed job on Data Health, found by its FailedExecution id. Two admins can
  # look at the same list, so a row that is gone by the time the button is
  # pressed is reported rather than raised.
  module FailedJobScoped
    extend ActiveSupport::Concern

    included do
      before_action :set_failed_execution
      rescue_from ActiveRecord::RecordNotFound, with: :failed_job_gone
    end

    private

    def set_failed_execution
      @failed_execution = SolidQueue::FailedExecution.includes(:job).find(params[:failed_job_id] || params[:id])
    end

    def failed_job_gone
      redirect_to background_jobs_path,
                  alert: "That job is no longer failed. Someone may have retried or discarded it already."
    end

    def failed_job_name
      helpers.admin_job_name(@failed_execution.job.class_name)
    end

    def background_jobs_path
      admin_data_health_path(anchor: "background-jobs")
    end

    def audit(message)
      Rails.logger.info "[ADMIN ACTION] #{current_user.email} #{message} from IP: #{request.remote_ip}"
    end
  end
end
