# How Analytics names and colours a run's outcome. A run with no outcome yet is
# still going (the live view's nil, the rollups' "pending") and says so, where
# it used to read "Unknown" (spec Q66).
module AnalyticsHelper
  OUTCOME_BARS = {
    "resolved" => "analytics-bar--resolved",
    "completed" => "analytics-bar--completed",
    "escalated" => "analytics-bar--escalated",
    "error" => "analytics-bar--error",
    "transferred" => "analytics-bar--transferred",
    "abandoned" => "analytics-bar--muted"
  }.freeze

  def analytics_outcome_label(outcome)
    analytics_in_progress?(outcome) ? "In progress" : outcome.capitalize
  end

  def analytics_outcome_bar_class(outcome)
    return "analytics-bar--muted" if analytics_in_progress?(outcome)

    OUTCOME_BARS.fetch(outcome, "analytics-bar--default")
  end

  private

  def analytics_in_progress?(outcome)
    outcome.blank? || outcome == ScenarioRollup::PENDING
  end
end
