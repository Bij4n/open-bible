require "rails_helper"

RSpec.describe Group, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to have_many(:memberships).dependent(:delete_all) }
    it { is_expected.to have_many(:members).through(:memberships).source(:user) }
  end

  describe "validations" do
    subject { build(:group) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_length_of(:description).is_at_most(500) }

    it "requires a unique invitation_code when present" do
      create(:group, :with_invitation_code, invitation_code: "TAKEN0")
      dup = build(:group, :with_invitation_code, invitation_code: "TAKEN0")
      expect(dup).not_to be_valid
      expect(dup.errors[:invitation_code]).to be_present
    end

    it "allows blank invitation_code" do
      expect(build(:group, invitation_code: nil)).to be_valid
    end

    it "rejects invitation_code that isn't 6-8 alphanumeric chars" do
      expect(build(:group, invitation_code: "abc")).not_to be_valid
      expect(build(:group, invitation_code: "too-long-12345")).not_to be_valid
      expect(build(:group, invitation_code: "has spc")).not_to be_valid
      expect(build(:group, invitation_code: "ABC123")).to be_valid
      expect(build(:group, invitation_code: "ABCD1234")).to be_valid
    end
  end

  describe "privacy enum" do
    it "accepts all three privacy levels" do
      expect(build(:group, privacy: "private_group")).to be_valid
      expect(build(:group, privacy: "invite_only")).to be_valid
      expect(build(:group, privacy: "open_group")).to be_valid
    end

    it "rejects unknown privacies" do
      expect { build(:group, privacy: "public") }.to raise_error(ArgumentError)
    end
  end

  describe "#member?" do
    let(:group) { create(:group) }
    let(:outsider) { create(:user) }

    it "is true for the owner" do
      expect(group.member?(group.owner)).to be true
    end

    it "is true for an added member" do
      user = create(:user)
      create(:membership, user: user, group: group, role: :member)
      expect(group.member?(user)).to be true
    end

    it "is false for a non-member" do
      expect(group.member?(outsider)).to be false
    end

    it "is false for nil" do
      expect(group.member?(nil)).to be false
    end
  end

  describe ".generate_invitation_code" do
    it "produces 6-8 alphanumeric chars" do
      code = Group.generate_invitation_code
      expect(code).to match(/\A[A-Z0-9]{6,8}\z/)
    end

    it "varies between calls" do
      codes = 10.times.map { Group.generate_invitation_code }
      expect(codes.uniq.size).to be > 1
    end
  end
end
