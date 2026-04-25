class DonationReport < ApplicationRecord
  # Both fields nullable by design: every POST to /donate/confirm writes
  # a row even without email or message, so DonationReport.count is a
  # usage-signal floor; DonationReport.where.not(email: nil) isolates
  # the email-bearing subset for thank-you outreach.
  validates :email, length: { maximum: 255 }, allow_blank: true
  validates :message, length: { maximum: 1000 }, allow_blank: true
end
