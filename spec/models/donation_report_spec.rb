require "rails_helper"

RSpec.describe DonationReport, type: :model do
  it "is valid with no fields set" do
    expect(DonationReport.new).to be_valid
  end

  it "is valid with both email and message present" do
    report = DonationReport.new(email: "donor@example.com", message: "Thank you for the work")
    expect(report).to be_valid
  end

  it "rejects email longer than 255 chars" do
    expect(DonationReport.new(email: "x" * 256)).not_to be_valid
  end

  it "rejects message longer than 1000 chars" do
    expect(DonationReport.new(message: "x" * 1001)).not_to be_valid
  end
end
