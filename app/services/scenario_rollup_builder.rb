# Rolls runs up into daily aggregates before retention deletes them.
#
# WHICH DAYS GET ROLLED IS THE WHOLE DESIGN. The obvious rule — "re-roll every
# day that still has raw data" — silently corrupts history, because cleanup keys
# on `completed_at` while a rollup keys on `started_at`. Runs started on day X
# finish on X, X+1, X+2, so they are deleted on different nights. Day X still has
# raw rows after the first tranche goes, so a blind re-roll recomputes it from
# the survivors, undercounts, and then freezes at the wrong number — failing
# exactly at the horizon the table exists to protect.
#
# So: a day is rolled only while it is still moving.
#
#   (a) it has no rollup rows yet — first run, and any night the job missed; or
#   (b) it falls inside REFRESH_DAYS, which covers runs that settle a day or two
#       after they started (the sweep's window is 24h plus up to a day).
#
# A day outside the window that already has rows is never touched again. That is
# what makes the history durable rather than merely written down.
class ScenarioRollupBuilder
  # Wide enough for the idle sweep's real window (24h threshold, swept nightly,
  # so up to ~48h) plus a night's slack.
  REFRESH_DAYS = 3

  def self.rebuild! = new.rebuild!

  def rebuild!
    days = days_to_roll
    return { days: 0, rollups: 0, dropoffs: 0 } if days.empty?

    rollups = daily_rows(days)
    dropoffs = dropoff_rows(days)

    ScenarioRollup.transaction do
      # Delete-then-insert, not upsert: when a run settles it moves from
      # "pending" to its real outcome, and an upsert would leave the stale
      # pending row behind, double-counting the run.
      ScenarioRollup.for_days(days).delete_all
      ScenarioDropoffRollup.where(day: days).delete_all
      ScenarioRollup.insert_all!(rollups) if rollups.any?
      ScenarioDropoffRollup.insert_all!(dropoffs) if dropoffs.any?
    end

    { days: days.size, rollups: rollups.size, dropoffs: dropoffs.size }
  end

  private

  def window_start = (Date.current - REFRESH_DAYS)

  # Days that still have runs, minus the closed ones already written.
  def days_to_roll
    with_raw = Scenario.where.not(started_at: nil)
                       .distinct
                       .pluck(Arel.sql(date_sql))
                       .filter_map { |d| to_date(d) }
    already_rolled = ScenarioRollup.distinct.pluck(:day).filter_map { |d| to_date(d) }.to_set

    with_raw.select { |day| already_rolled.exclude?(day) || day >= window_start }
  end

  def daily_rows(days)
    now = Time.current
    grouped = Scenario.where.not(started_at: nil)
                      .group(Arel.sql(date_sql), :workflow_id, :purpose, :outcome)
                      .pluck(
                        Arel.sql(date_sql), :workflow_id, :purpose, :outcome,
                        Arel.sql("COUNT(*)"),
                        Arel.sql("COALESCE(SUM(duration_seconds), 0)"),
                        Arel.sql("COUNT(duration_seconds)")
                      )

    grouped.filter_map do |row|
      day, workflow_id, purpose, outcome, count, sum, dur_count = row
      date = to_date(day)
      next unless date && days.include?(date)

      {
        workflow_id: workflow_id, day: date, purpose: purpose,
        outcome: outcome.presence || ScenarioRollup::PENDING,
        runs_count: count, duration_sum_seconds: sum.to_i, duration_count: dur_count.to_i,
        created_at: now, updated_at: now
      }
    end
  end

  # execution_path is JSON, so the last step cannot be grouped in portable SQL.
  # Bounded by `days` rather than capped by a magic number: scoping to the days
  # actually being rolled is what keeps this from walking the whole retention
  # window every night.
  def dropoff_rows(days)
    now = Time.current
    counts = Hash.new(0)

    Scenario.where(outcome: "abandoned").where.not(started_at: nil)
            .select(:id, :workflow_id, :started_at, :execution_path)
            .find_each(batch_size: 500) do |scenario|
      date = scenario.started_at.to_date
      next unless days.include?(date)

      title = scenario.execution_path&.last&.dig("step_title")
      next if title.blank?

      counts[[scenario.workflow_id, date, title]] += 1
    end

    counts.map do |(workflow_id, day, step_title), count|
      { workflow_id: workflow_id, day: day, step_title: step_title,
        runs_count: count, created_at: now, updated_at: now }
    end
  end

  # SQLite returns a String here and PostgreSQL a Date. Normalising matters: an
  # unnormalised key makes the two behave differently, and dev is SQLite while
  # production is PostgreSQL, so the divergence would never show up locally.
  def to_date(value)
    return value if value.is_a?(Date)

    value.presence && Date.parse(value.to_s)
  rescue Date::Error
    nil
  end

  def date_sql
    if ActiveRecord::Base.connection.adapter_name.downcase.include?("sqlite")
      "date(started_at)"
    else
      "started_at::date"
    end
  end
end
