require "rails_helper"

RSpec.describe Note, "moderation + public surface" do
  let(:admin)  { create(:user, admin: true) }
  let(:author) { create(:user) }

  describe ".public_visible" do
    it "includes public, non-hidden notes" do
      n = create(:note, user: author, visibility: :public_note)
      expect(Note.public_visible).to include(n)
    end

    it "excludes private notes" do
      n = create(:note, user: author, visibility: :private_note)
      expect(Note.public_visible).not_to include(n)
    end

    it "excludes hidden notes" do
      n = create(:note, user: author, visibility: :public_note, hidden_at: Time.current)
      expect(Note.public_visible).not_to include(n)
    end
  end

  describe ".featured" do
    it "returns only notes with featured: true" do
      yes = create(:note, user: author, visibility: :public_note, featured: true)
      no  = create(:note, user: author, visibility: :public_note, featured: false)
      expect(Note.featured).to include(yes)
      expect(Note.featured).not_to include(no)
    end
  end

  describe ".sorted_for_public" do
    it "ranks featured first, then most-upvoted, then newest" do
      t_old = 2.days.ago
      t_new = 1.hour.ago

      plain_old = create(:note, user: author, visibility: :public_note, created_at: t_old)
      plain_new = create(:note, user: author, visibility: :public_note, created_at: t_new)
      popular   = create(:note, user: author, visibility: :public_note, created_at: t_old)
      2.times { create(:upvote, note: popular) }
      pinned    = create(:note, user: author, visibility: :public_note, featured: true, created_at: t_old)

      ordered = Note.public_visible.sorted_for_public.to_a
      expect(ordered.first).to eq(pinned)
      expect(ordered[1]).to eq(popular)
      expect(ordered.last(2)).to contain_exactly(plain_old, plain_new)
      expect(ordered.index(plain_new)).to be < ordered.index(plain_old)
    end
  end

  describe "#hide! / #unhide!" do
    it "stamps hidden_at and hidden_by on hide" do
      note = create(:note, user: author, visibility: :public_note)
      note.hide!(admin)
      expect(note.hidden_at).to be_present
      expect(note.hidden_by).to eq(admin)
    end

    it "clears both on unhide" do
      note = create(:note, user: author, visibility: :public_note, hidden_at: Time.current, hidden_by: admin)
      note.unhide!
      expect(note.hidden_at).to be_nil
      expect(note.hidden_by).to be_nil
    end

    it "#hidden? reflects the state" do
      note = create(:note, user: author, visibility: :public_note)
      expect(note).not_to be_hidden
      note.hide!(admin)
      expect(note).to be_hidden
    end
  end

  describe "#feature! / #unfeature!" do
    it "stamps featured, featured_at, featured_by on feature" do
      note = create(:note, user: author, visibility: :public_note)
      note.feature!(admin)
      expect(note.featured).to be true
      expect(note.featured_at).to be_present
      expect(note.featured_by).to eq(admin)
    end

    it "clears all three on unfeature" do
      note = create(:note, user: author, visibility: :public_note, featured: true,
                           featured_at: Time.current, featured_by: admin)
      note.unfeature!
      expect(note.featured).to be false
      expect(note.featured_at).to be_nil
      expect(note.featured_by).to be_nil
    end
  end
end
