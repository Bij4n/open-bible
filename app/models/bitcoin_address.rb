class BitcoinAddress < ApplicationRecord
  # Length floor catches obvious typos; max accommodates bech32 (up to ~90).
  # Not validating base58/bech32 checksum — that's a library dep we don't
  # need for admin-authored input. Real consequence of a bad paste is
  # on-chain (sends go nowhere recoverable), and validation can't prevent
  # that either way.
  validates :address, presence: true, length: { minimum: 20, maximum: 128 }
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  # Returns the row currently marked active, or nil. Used by the public
  # /donate page to render the active address (or fall through to the
  # unavailable state when this returns nil).
  def self.current
    where(active: true).first
  end

  # Atomic one-step rotation: archive whatever's currently active, create
  # the new row as active, all in a single transaction. Race-safe at the
  # application level; the partial unique index on (active = true) is the
  # DB-level backstop if two concurrent rotations sneak past.
  def self.rotate_to!(address:, notes: nil)
    transaction do
      where(active: true).update_all(active: false, archived_at: Time.current)
      create!(address: address, notes: notes, active: true)
    end
  end
end
