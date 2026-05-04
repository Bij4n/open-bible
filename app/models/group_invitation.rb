class GroupInvitation < ApplicationRecord
  # Email-based invitation to join a Group. Sprint 23.1 — augments the
  # invitation-code flow (Group#invitation_code, used directly via the
  # /groups join form). Owner enters a friend's email; we generate a
  # one-time token + email a tokenized link; recipient clicks → if
  # signed in, auto-join the group; if not, sign up first then auto-join
  # via session-stashed token.
  #
  # Lifecycle: created (pending) → accepted (joined) | expired (TTL) |
  # destroyed (cancelled by owner).
  TOKEN_LENGTH       = 24
  EXPIRATION_PERIOD  = 14.days

  belongs_to :group
  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  # Pending uniqueness mirrors the partial DB index — a group can have
  # at most one pending invite per email at a time.
  validates :email, uniqueness: { scope: :group_id,
                                  conditions: -> { pending },
                                  case_sensitive: false,
                                  message: "already has a pending invitation to this group" }

  before_validation :assign_token, on: :create
  before_validation :assign_expiration, on: :create
  before_validation :normalize_email

  scope :pending,  -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired,  -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def expired?
    accepted_at.nil? && expires_at <= Time.current
  end

  # Marks the invitation accepted + creates the membership in a single
  # transaction. Idempotent: if user is already a member, just records
  # the acceptance timestamp without creating a duplicate membership.
  def accept!(user)
    raise ArgumentError, "user required" unless user
    raise "invitation expired" if expired?
    raise "invitation already accepted" if accepted?

    transaction do
      group.memberships.find_or_create_by!(user: user) do |m|
        m.role = "member"
      end
      update!(accepted_at: Time.current)
    end
  end

  private

  def assign_token
    return if token.present?

    self.token = loop do
      candidate = SecureRandom.urlsafe_base64(TOKEN_LENGTH)
      break candidate unless self.class.exists?(token: candidate)
    end
  end

  def assign_expiration
    self.expires_at ||= EXPIRATION_PERIOD.from_now
  end

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
