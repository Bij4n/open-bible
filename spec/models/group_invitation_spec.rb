require "rails_helper"

RSpec.describe GroupInvitation, type: :model do
  describe "validations" do
    it "requires a group, invited_by, email, and a non-malformed email format" do
      inv = GroupInvitation.new
      expect(inv).not_to be_valid
      expect(inv.errors[:group]).to be_present
      expect(inv.errors[:invited_by]).to be_present
      expect(inv.errors[:email]).to be_present
    end

    it "rejects malformed emails" do
      inv = build(:group_invitation, email: "not-an-email")
      expect(inv).not_to be_valid
      expect(inv.errors[:email]).to be_present
    end

    it "is unique on (group, email) while pending" do
      inv = create(:group_invitation, email: "friend@example.com")
      dup = build(:group_invitation, group: inv.group, email: "friend@example.com")
      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to be_present
    end

    it "allows a re-invite after the previous was accepted" do
      first = create(:group_invitation, email: "friend@example.com")
      first.update!(accepted_at: Time.current)
      second = build(:group_invitation, group: first.group, email: "friend@example.com")
      expect(second).to be_valid
    end

    it "normalizes email to lowercase + trimmed on validate" do
      inv = create(:group_invitation, email: "  Friend@Example.COM  ")
      expect(inv.email).to eq("friend@example.com")
    end
  end

  describe "token + expiration auto-assignment" do
    it "generates a unique token + 14-day expiration on create" do
      inv = create(:group_invitation)
      expect(inv.token).to be_present
      expect(inv.token.length).to be >= 20
      expect(inv.expires_at).to be_within(5.seconds).of(14.days.from_now)
    end

    it "generates distinct tokens across multiple invitations" do
      a = create(:group_invitation, email: "a@example.com")
      b = create(:group_invitation, email: "b@example.com")
      expect(a.token).not_to eq(b.token)
    end
  end

  describe "lifecycle predicates" do
    it "is pending when accepted_at is nil and expires_at in the future" do
      inv = create(:group_invitation)
      expect(inv).to be_pending
      expect(inv).not_to be_accepted
      expect(inv).not_to be_expired
    end

    it "is accepted after #accept!" do
      inv = create(:group_invitation)
      user = create(:user)
      inv.accept!(user)
      expect(inv.reload).to be_accepted
      expect(inv).not_to be_pending
    end

    it "is expired when expires_at has passed and accepted_at is nil" do
      inv = create(:group_invitation, :expired)
      expect(inv).to be_expired
      expect(inv).not_to be_pending
    end
  end

  describe "#accept!" do
    it "creates a membership for the user in the group" do
      inv = create(:group_invitation)
      user = create(:user)
      expect { inv.accept!(user) }.to change { inv.group.memberships.where(user: user).count }.by(1)
      expect(inv.group.member?(user)).to be(true)
    end

    it "is idempotent when the user is already a member" do
      inv = create(:group_invitation)
      user = create(:user)
      inv.group.memberships.create!(user: user, role: :member)
      expect { inv.accept!(user) }.not_to change { inv.group.memberships.count }
      expect(inv.reload).to be_accepted
    end

    it "raises if the invitation is already accepted" do
      inv = create(:group_invitation, :accepted)
      user = create(:user)
      expect { inv.accept!(user) }.to raise_error("invitation already accepted")
    end

    it "raises if the invitation is expired" do
      inv = create(:group_invitation, :expired)
      user = create(:user)
      expect { inv.accept!(user) }.to raise_error("invitation expired")
    end

    it "raises ArgumentError without a user" do
      inv = create(:group_invitation)
      expect { inv.accept!(nil) }.to raise_error(ArgumentError)
    end
  end

  describe "scopes" do
    let!(:pending_inv) { create(:group_invitation) }
    let!(:accepted_inv) { create(:group_invitation, :accepted, email: "ac@example.com") }
    let!(:expired_inv) { create(:group_invitation, :expired, email: "ex@example.com") }

    it "pending excludes accepted and expired" do
      expect(GroupInvitation.pending).to include(pending_inv)
      expect(GroupInvitation.pending).not_to include(accepted_inv, expired_inv)
    end

    it "accepted scope returns accepted_at-set invitations" do
      expect(GroupInvitation.accepted).to include(accepted_inv)
      expect(GroupInvitation.accepted).not_to include(pending_inv, expired_inv)
    end

    it "expired scope returns past-expiration unaccepted invitations" do
      expect(GroupInvitation.expired).to include(expired_inv)
      expect(GroupInvitation.expired).not_to include(pending_inv, accepted_inv)
    end
  end
end
