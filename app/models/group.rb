class Group < ApplicationRecord
  PRIVACIES = { private_group: 0, invite_only: 1 }.freeze
  INVITATION_CODE_FORMAT = /\A[A-Z0-9]{6,8}\z/

  enum :privacy, PRIVACIES

  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :invitation_code,
            uniqueness: true,
            format: { with: INVITATION_CODE_FORMAT },
            allow_blank: true

  def member?(user)
    return false unless user

    owner_id == user.id || memberships.exists?(user_id: user.id)
  end

  def self.generate_invitation_code
    alphabet = ("A".."Z").to_a + ("0".."9").to_a
    length   = 6 + rand(3) # 6..8
    Array.new(length) { alphabet.sample }.join
  end
end
