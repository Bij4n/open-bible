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

  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :owned_groups, class_name: "Group", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner

  # Polymorphic note shares keyed on this user (shareable).
  has_many :note_shares, as: :shareable, dependent: :destroy

  validates :ui_locale, inclusion: { in: UI_LOCALES }
  validates :theme,     inclusion: { in: THEMES }
  validates :display_name,
            length: { maximum: DISPLAY_NAME_MAX },
            uniqueness: { case_sensitive: false, allow_blank: true }

  # Public-facing author label for notes, comments, and group-bible
  # attributions. Prefers display_name; falls back to the email
  # local-part so we never expose the full email address to groupmates.
  def author_name
    return display_name if display_name.present?

    email.to_s.split("@").first.presence || email
  end
end
