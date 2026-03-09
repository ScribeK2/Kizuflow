class Transition < ApplicationRecord
  belongs_to :step
  belongs_to :target_step, class_name: "Step"

  validates :step_id, uniqueness: { scope: :target_step_id, message: "already has a transition to this target" }

  default_scope { order(:position) }
end
