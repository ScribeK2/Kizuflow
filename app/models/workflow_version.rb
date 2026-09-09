class WorkflowVersion < ApplicationRecord
  belongs_to :workflow
  belongs_to :published_by, class_name: "User"

  validates :version_number, presence: true,
                             uniqueness: { scope: :workflow_id }
  validates :published_at, presence: true

  scope :newest_first, -> { order(version_number: :desc) }
  scope :restorable, -> { where(stripped_at: nil) }
  scope :stripped, -> { where.not(stripped_at: nil) }

  # How many versions of a workflow stay restorable. Everything older keeps its
  # row — number, date, publisher, title, changelog — and releases only the steps.
  #
  # A count rather than an age: a workflow published twice a year is exactly where
  # you have forgotten what changed, and a time-based rule keeps it nothing.
  def self.restore_limit
    ENV.fetch("WORKFLOW_VERSION_RESTORE_LIMIT", 10).to_i
  end

  # The record survives; the payload does not. Nothing here is ever deleted —
  # `workflows.published_version_id` is a RESTRICT foreign key, and a design that
  # removed rows would have to reason about it on every path.
  def strip_snapshot!
    return if stripped?

    update!(steps_snapshot: [], stripped_at: Time.current)
  end

  def stripped?
    stripped_at.present?
  end

  def restorable?
    !stripped?
  end

  # Two publishes are the same publish when both halves match. Metadata counts:
  # renaming a workflow and republishing IS a change, even with identical steps.
  def same_content_as?(steps_snapshot_candidate, metadata_snapshot_candidate)
    return false if stripped?

    steps_snapshot == steps_snapshot_candidate.as_json &&
      metadata_snapshot == metadata_snapshot_candidate.as_json
  end
end
