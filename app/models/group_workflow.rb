class GroupWorkflow < ApplicationRecord
  belongs_to :group
  belongs_to :workflow, touch: true
  belongs_to :folder, optional: true

  validates :group_id, uniqueness: { scope: :workflow_id }
end
