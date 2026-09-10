module Admin
  # What is waiting on an administrator, and nothing else. Drives the Overview
  # and the count on its sidebar item, so the two cannot disagree.
  #
  # Each check is a model question — User.awaiting_groups, SmtpSetting.unconfigured?,
  # JobHealth. This only gathers them for one screen, the way Admin::UsersFilter
  # composes the Users list. Dependencies are arguments because there is no
  # stubbing library: tests construct the production case directly.
  class Attention
    LISTED_USERS = 10

    def initialize(env: Rails.env, environment_address: ENV.fetch("SMTP_ADDRESS", nil),
                   adapter: Rails.application.config.active_job.queue_adapter, now: Time.current)
      @env = env
      @environment_address = environment_address
      @adapter = adapter
      @now = now
    end

    def awaiting_groups_count
      @awaiting_groups_count ||= User.awaiting_groups.count
    end

    def awaiting_groups
      User.awaiting_groups.order(created_at: :desc).limit(LISTED_USERS)
    end

    def email_unconfigured?
      return @email_unconfigured if defined?(@email_unconfigured)

      @email_unconfigured = SmtpSetting.unconfigured?(env: @env, environment_address: @environment_address)
    end

    def failed_jobs_count
      @failed_jobs_count ||= JobHealth.failed_count(adapter: @adapter)
    end

    def stalled_task_keys
      @stalled_task_keys ||= JobHealth.stalled_task_keys(adapter: @adapter, now: @now)
    end

    # One per kind of problem. Seven users waiting for a group is one thing to
    # do, and a count that read "37" during a department's onboarding would say
    # nothing more than "1" does.
    def count
      [awaiting_groups_count.positive?, email_unconfigured?, failed_jobs_count.positive?,
       stalled_task_keys.any?].count(true)
    end

    def any?
      count.positive?
    end
  end
end
