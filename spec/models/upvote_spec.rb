require "rails_helper"

RSpec.describe Upvote, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:note) }
  end

  describe "uniqueness" do
    it "prevents a user from upvoting the same note twice" do
      existing = create(:upvote)
      dup = build(:upvote, user: existing.user, note: existing.note)
      expect(dup).not_to be_valid
    end

    it "allows different users to upvote the same note" do
      first = create(:upvote)
      other = build(:upvote, note: first.note)
      expect(other).to be_valid
    end
  end
end
