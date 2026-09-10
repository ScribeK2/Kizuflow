class UserGroup < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id }
  validate :group_is_not_global

  private

  # Global's audience is everyone signed in, so a membership would mean nothing
  # while reading as though it did.
  def group_is_not_global
    errors.add(:group, "Global has no members — everyone signed in already sees it") if group&.global?
  end
end
