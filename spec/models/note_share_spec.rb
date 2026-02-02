require "rails_helper"

RSpec.describe NoteShare, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:shareable) }
  end

  describe "validations" do
    it "allows shareable_type User or Group" do
      user = create(:user)
      group = create(:group)
      note = create(:note)
      expect(NoteShare.new(note: note, shareable: user)).to be_valid
      expect(NoteShare.new(note: note, shareable: group)).to be_valid
    end

    it "disallows duplicate shares of the same note + shareable" do
      share = create(:note_share)
      dup = NoteShare.new(note: share.note, shareable: share.shareable)
      expect(dup).not_to be_valid
    end

    it "allows sharing the same note with different targets" do
      note = create(:note)
      u1 = create(:user); u2 = create(:user)
      create(:note_share, note: note, shareable: u1)
      expect(NoteShare.new(note: note, shareable: u2)).to be_valid
    end
  end
end
