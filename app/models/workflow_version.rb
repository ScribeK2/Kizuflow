class WorkflowVersion < ApplicationRecord
  belongs_to :workflow
  belongs_to :published_by, class_name: "User"

  validates :version_number, presence: true,
            uniqueness: { scope: :workflow_id }
  validates :published_at, presence: true

  default_scope { order(version_number: :desc) }
end
