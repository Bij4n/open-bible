require "rails_helper"

RSpec.describe Translation, type: :model do
  describe "validations" do
    subject { build(:translation) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:language) }

    it "requires code uniqueness case-insensitively" do
      create(:translation, code: "KJV")
      duplicate = build(:translation, code: "kjv")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to be_present
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:books).dependent(:destroy) }
  end

  describe "defaults" do
    it "defaults public_domain to false" do
      expect(Translation.new.public_domain).to eq(false)
    end
  end
end
