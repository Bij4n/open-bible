# A directed edge: follower watches followed. Mutual edges make the
# pair "friends" (User#friends) — the audience of the friends_note
# visibility (Sprint R6). Follows are public-profile data, consistent
# with public notes; there are no notifications in v1.
class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"

  validates :followed_id, uniqueness: { scope: :follower_id }
  validate  :not_self

  private

  def not_self
    errors.add(:followed, :invalid) if follower_id.present? && follower_id == followed_id
  end
end
