class CreateDonationReports < ActiveRecord::Migration[8.1]
  def change
    # Self-reported donations from /donate/confirm — user clicks 'I sent
    # one'. No on-chain verification (v1). Email + message are nullable;
    # every POST writes a row regardless, so DonationReport.count gives a
    # usage-signal floor and where.not(email: nil) isolates the
    # email-bearing subset for any thank-you outreach.
    create_table :donation_reports do |t|
      t.string :email
      t.text :message
      t.timestamps
    end
  end
end
