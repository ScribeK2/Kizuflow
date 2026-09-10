# Background jobs as Data Health shows them. Solid Queue's rows name a job by
# class and a schedule by cron, neither of which an admin should have to read.
module DataHealthHelper
  # "CleanupDraftsJob" -> "Cleanup drafts". A recurring command has no class.
  def admin_job_name(class_name)
    return "Command" if class_name.blank?

    class_name.demodulize.delete_suffix("Job").underscore.humanize
  end

  def admin_job_error_line(execution)
    [execution.exception_class, execution.message.to_s.lines.first&.strip].compact_blank.join(": ")
  end

  def admin_job_error_detail(execution)
    header = [execution.exception_class, execution.message].compact_blank.join(": ")
    [header, *Array(execution.backtrace)].join("\n")
  end

  # "0 2 * * *" -> "Daily at 02:00". Only the plain daily form is translated;
  # every other schedule in config/recurring.yml is already words.
  def admin_schedule_label(schedule)
    match = schedule.to_s.match(/\A(\d{1,2}) (\d{1,2}) \* \* \*\z/)
    return schedule.to_s.upcase_first unless match

    format("Daily at %<hour>02d:%<minute>02d", hour: match[2].to_i, minute: match[1].to_i)
  end
end
