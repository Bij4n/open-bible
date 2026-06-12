class User < ApplicationRecord
  UI_LOCALES = %w[en es].freeze
  THEMES     = %w[light dark system].freeze
  DISPLAY_NAME_MAX = 60

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :default_translation, class_name: "Translation", optional: true

  has_many :highlights, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :upvotes, dependent: :destroy

  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :owned_groups, class_name: "Group", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner

  # Polymorphic note shares keyed on this user (shareable).
  has_many :note_shares, as: :shareable, dependent: :destroy

  # Outbound email invites this user has sent — Sprint 23.1.
  has_many :sent_group_invitations,
           class_name: "GroupInvitation",
           foreign_key: :invited_by_id,
           dependent: :destroy,
           inverse_of: :invited_by

  # Follows (Sprint R5). Two directed edge sets; the intersection is
  # #friends — the audience of the friends_note visibility (R6).
  has_many :follows, foreign_key: :follower_id, dependent: :destroy, inverse_of: :follower
  has_many :following, through: :follows, source: :followed
  has_many :reverse_follows, class_name: "Follow", foreign_key: :followed_id,
                             dependent: :destroy, inverse_of: :followed
  has_many :followers, through: :reverse_follows, source: :follower

  validates :ui_locale, inclusion: { in: UI_LOCALES }
  validates :theme,     inclusion: { in: THEMES }
  validates :display_name,
            length: { maximum: DISPLAY_NAME_MAX },
            uniqueness: { case_sensitive: false, allow_blank: true }

  def follow!(user)
    follows.find_or_create_by!(followed: user)
  end

  def unfollow!(user)
    follows.where(followed: user).destroy_all
  end

  def following?(user)
    follows.exists?(followed: user)
  end

  # Mutual follows. Two index-backed subqueries (the through
  # associations' id sets) intersected — composes cleanly as a
  # relation for R6's visible_to branch (friends.select(:id)).
  def friends
    User.where(id: following.select(:id)).where(id: followers.select(:id))
  end

  def friends_with?(user)
    friends.exists?(user.id)
  end

  # Public-facing author label for notes, comments, and group-bible
  # attributions. Prefers display_name; falls back to the email
  # local-part so we never expose the full email address to groupmates.
  def author_name
    return display_name if display_name.present?

    email.to_s.split("@").first.presence || email
  end
end
