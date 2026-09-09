# Where runs stopped, per workflow per day, kept past the retention horizon.
#
# Separate from ScenarioRollup because the question has a different grain: the
# step someone abandoned on is read from `execution_path.last` on an individual
# run, and no aggregate of outcomes can reconstruct it. Without this table the
# drop-off report is the one analytic that still dies when the runs are deleted.
class ScenarioDropoffRollup < ApplicationRecord
  belongs_to :workflow

  validates :day, :step_title, presence: true
  validates :runs_count, numericality: { greater_than_or_equal_to: 0 }
end
