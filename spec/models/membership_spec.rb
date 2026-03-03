require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:group) }
  end

  describe "role enum" do
    it "accepts owner and member" do
      expect(build(:membership, role: "owner")).to be_valid
      expect(build(:membership, role: "member")).to be_valid
    end

    it "rejects other values" do
      expect { build(:membership, role: "god") }.to raise_error(ArgumentError)
    end
  end

  describe "uniqueness" do
    it "disallows two memberships for the same user+group" do
      existing = create(:membership)
      dup = build(:membership, user: existing.user, group: existing.group)
      expect(dup).not_to be_valid
    end
  end

  describe "at-least-one-owner constraint" do
    let(:group) { create(:group) }

    it "prevents demoting the last owner" do
      last_owner = group.memberships.where(role: "owner").first
      last_owner.role = "member"
      expect(last_owner).not_to be_valid
      expect(last_owner.errors[:role]).to be_present
    end

    it "allows demoting an owner when another owner remains" do
      other = create(:user)
      create(:membership, :owner, user: other, group: group)
      original_owner_membership = group.memberships.find_by!(user: group.owner)
      original_owner_membership.role = "member"
      expect(original_owner_membership).to be_valid
    end

    it "prevents destroying the last owner membership" do
      last_owner = group.memberships.where(role: "owner").first
      expect { last_owner.destroy! }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows destroying a non-owner membership" do
      member = create(:membership, group: group, role: :member)
      expect { member.destroy! }.to change(Membership, :count).by(-1)
    end
  end
end
