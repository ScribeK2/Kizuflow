class GroupWorkflow < ApplicationRecord
  belongs_to :group
  belongs_to :workflow
  belongs_to :folder, optional: true

  validates :group_id, uniqueness: { scope: :workflow_id }
end
