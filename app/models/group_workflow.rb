class GroupWorkflow < ApplicationRecord
  belongs_to :group
  belongs_to :workflow

  validates :group_id, uniqueness: { scope: :workflow_id }
end

