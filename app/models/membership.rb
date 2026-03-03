class Membership < ApplicationRecord
  ROLES = { owner: 0, member: 1 }.freeze

  enum :role, ROLES

  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id }
  validate  :keeps_at_least_one_owner, on: :update
  before_destroy :refuse_destroy_of_last_owner

  private

  # Prevent demoting the last owner mid-update. Paired with
  # refuse_destroy_of_last_owner for deletion.
  def keeps_at_least_one_owner
    return unless role_changed? && role_was == "owner" && role == "member"
    return if other_owner_exists?

    errors.add(:role, "can't demote the last owner of the group")
  end

  def refuse_destroy_of_last_owner
    return unless role == "owner"
    return if other_owner_exists?

    errors.add(:base, "can't remove the last owner of the group")
    raise ActiveRecord::RecordInvalid, self
  end

  def other_owner_exists?
    Membership.where(group_id: group_id, role: Membership.roles[:owner])
              .where.not(id: id).exists?
  end
end
