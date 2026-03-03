class Group < ApplicationRecord
  PRIVACIES = { private_group: 0, invite_only: 1 }.freeze
  INVITATION_CODE_FORMAT = /\A[A-Z0-9]{6,8}\z/

  enum :privacy, PRIVACIES

  belongs_to :owner, class_name: "User"
  # delete_all (not :destroy) bypasses the at-least-one-owner callback on
  # Membership — if the whole group is going away, there's nothing to
  # preserve. Individual membership destroys still hit the callback.
  has_many :memberships, dependent: :delete_all
  has_many :members, through: :memberships, source: :user

  has_many :note_shares, as: :shareable, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :invitation_code,
            uniqueness: true,
            format: { with: INVITATION_CODE_FORMAT },
            allow_blank: true

  # Every group has an owner Membership so `user.groups` transparently
  # spans both owned and joined groups in a single association.
  after_create :ensure_owner_membership

  def member?(user)
    return false unless user

    owner_id == user.id || memberships.exists?(user_id: user.id)
  end

  def self.generate_invitation_code
    alphabet = ("A".."Z").to_a + ("0".."9").to_a
    length   = 6 + rand(3) # 6..8
    Array.new(length) { alphabet.sample }.join
  end

  private

  def ensure_owner_membership
    memberships.find_or_create_by!(user: owner) do |m|
      m.role = :owner
    end
  end
end
