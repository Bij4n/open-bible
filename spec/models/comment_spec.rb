require "rails_helper"

RSpec.describe Comment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:parent).class_name("Comment").optional }
    it { is_expected.to have_many(:replies).class_name("Comment").dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_length_of(:body).is_at_most(Comment::BODY_MAX) }

    it "rejects a comment whose parent is itself" do
      comment = create(:comment)
      comment.parent_id = comment.id
      expect(comment).not_to be_valid
      expect(comment.errors[:parent_id]).to be_present
    end
  end

  describe "depth calculation" do
    let(:note) { create(:note) }

    it "sets depth 0 for a top-level comment" do
      comment = create(:comment, note: note, parent: nil)
      expect(comment.depth).to eq(0)
    end

    it "sets depth 1 for a reply to a top-level comment" do
      top = create(:comment, note: note)
      reply = create(:comment, note: note, parent: top)
      expect(reply.depth).to eq(1)
    end

    it "caps depth at MAX_DEPTH (3)" do
      d0 = create(:comment, note: note, parent: nil)
      d1 = create(:comment, note: note, parent: d0)
      d2 = create(:comment, note: note, parent: d1)
      d3 = create(:comment, note: note, parent: d2)
      expect(d3.depth).to eq(3)
    end

    it "siblingizes a reply to a max-depth comment" do
      d0 = create(:comment, note: note)
      d1 = create(:comment, note: note, parent: d0)
      d2 = create(:comment, note: note, parent: d1)
      d3 = create(:comment, note: note, parent: d2)
      # Reply to d3 should instead become a sibling (child of d2).
      sibling = create(:comment, note: note, parent: d3)
      expect(sibling.parent).to eq(d2)
      expect(sibling.depth).to eq(3)
    end
  end

  describe ".top_level" do
    it "returns only comments without a parent" do
      top = create(:comment, parent: nil)
      create(:comment, parent: top)
      expect(Comment.top_level).to include(top)
      expect(Comment.top_level.where.not(id: top.id)).to be_empty
    end
  end

  describe ".ordered_for_display" do
    it "returns comments oldest-first (chronological)" do
      a = create(:comment, created_at: 2.hours.ago)
      b = create(:comment, created_at: 1.hour.ago)
      expect(Comment.ordered_for_display.to_a).to eq([ a, b ])
    end
  end

  describe ".visible_to" do
    let(:alice) { create(:user) }
    let(:bob)   { create(:user) }

    it "includes comments on the user's own notes" do
      note = create(:note, user: alice)
      comment = create(:comment, note: note, user: bob)
      expect(Comment.visible_to(alice)).to include(comment)
    end

    it "includes comments on notes shared directly with the user" do
      note = create(:note, user: bob, visibility: :shared_users)
      create(:note_share, note: note, shareable: alice)
      comment = create(:comment, note: note, user: bob)
      expect(Comment.visible_to(alice)).to include(comment)
    end

    it "includes comments on notes shared with a group the user belongs to" do
      group = create(:group, owner: bob)
      create(:membership, user: alice, group: group, role: :member)
      note = create(:note, user: bob, visibility: :shared_groups)
      create(:note_share, note: note, shareable: group)
      comment = create(:comment, note: note, user: bob)
      expect(Comment.visible_to(alice)).to include(comment)
    end

    it "excludes comments on notes the user can't see" do
      note = create(:note, user: bob, visibility: :private_note)
      comment = create(:comment, note: note, user: bob)
      expect(Comment.visible_to(alice)).not_to include(comment)
    end

    it "returns nothing for anonymous visitors" do
      note = create(:note, user: alice, visibility: :public_note)
      create(:comment, note: note, user: alice)
      expect(Comment.visible_to(nil)).to be_empty
    end
  end
end
