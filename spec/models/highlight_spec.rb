require "rails_helper"

RSpec.describe Highlight, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:translation) }
  end

  describe "color enum" do
    it "accepts each supported color" do
      %w[gold rose sage lavender sky].each do |c|
        expect(build(:highlight, color: c)).to be_valid
      end
    end

    it "rejects colors outside the enum" do
      expect { build(:highlight, color: "neon") }.to raise_error(ArgumentError)
    end
  end

  describe "osis_ref validation" do
    it "requires osis_ref" do
      h = build(:highlight, osis_ref: nil)
      expect(h).not_to be_valid
      expect(h.errors[:osis_ref]).to be_present
    end

    it "rejects malformed refs" do
      h = build(:highlight, osis_ref: "not-a-ref")
      expect(h).not_to be_valid
      expect(h.errors[:osis_ref]).to be_present
    end

    it "rejects cross-chapter refs (same_chapter scope)" do
      h = build(:highlight, osis_ref: "Bible.KJV.John.3.16-Bible.KJV.John.4.1")
      expect(h).not_to be_valid
      expect(h.errors[:osis_ref]).to be_present
    end

    it "accepts a same-chapter verse span" do
      expect(build(:highlight, osis_ref: "Bible.KJV.John.3.16-Bible.KJV.John.3.17")).to be_valid
    end

    it "accepts a character range within a verse" do
      expect(build(:highlight, osis_ref: "Bible.KJV.John.3.16!12-Bible.KJV.John.3.16!45")).to be_valid
    end
  end

  describe "uniqueness" do
    it "disallows two highlights from the same user with the same osis_ref + color" do
      user = create(:user)
      translation = create(:translation, :kjv)
      create(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "gold")
      dup = build(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "gold")
      expect(dup).not_to be_valid
    end

    it "allows a different color at the same ref" do
      user = create(:user)
      translation = create(:translation, :kjv)
      create(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "gold")
      other = build(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "sage")
      expect(other).to be_valid
    end

    it "allows another user to highlight the same ref" do
      translation = create(:translation, :kjv)
      u1 = create(:user); u2 = create(:user)
      create(:highlight, user: u1, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "gold")
      other = build(:highlight, user: u2, translation: translation, osis_ref: "Bible.KJV.John.3.16", color: "gold")
      expect(other).to be_valid
    end
  end

  describe "#parsed_ref" do
    it "returns an OsisRef parsed under the same-chapter strict mode" do
      h = build(:highlight, osis_ref: "Bible.KJV.John.3.16")
      expect(h.parsed_ref).to be_a(OsisRef)
      expect(h.parsed_ref.to_s).to eq("Bible.KJV.John.3.16")
    end
  end

  describe "scopes" do
    it ".for_chapter returns highlights whose osis_ref starts with the given prefix" do
      user = create(:user)
      translation = create(:translation, :kjv)
      in_chapter = create(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.3.16")
      _other_chapter = create(:highlight, user: user, translation: translation, osis_ref: "Bible.KJV.John.4.1", color: "rose")
      expect(Highlight.for_chapter("Bible.KJV.John.3.")).to include(in_chapter)
      expect(Highlight.for_chapter("Bible.KJV.John.3.")).not_to include(_other_chapter)
    end

    describe ".from_other_translations_in_chapter" do
      let(:user) { create(:user) }
      let!(:kjv)    { create(:translation, :kjv) }
      let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }

      let!(:kjv_highlight) do
        create(:highlight, user: user, translation: kjv,
                           osis_ref: "Bible.KJV.John.3.16", color: "gold")
      end
      let!(:rv_highlight) do
        create(:highlight, user: user, translation: rv1909,
                           osis_ref: "Bible.RV1909.John.3.16", color: "rose")
      end
      let!(:kjv_other_chapter) do
        create(:highlight, user: user, translation: kjv,
                           osis_ref: "Bible.KJV.John.4.1", color: "sage")
      end

      it "returns highlights from other translations touching the same chapter" do
        scope = Highlight.from_other_translations_in_chapter(
          translation_code: "RV1909", book: "John", chapter: 3
        )
        expect(scope).to include(kjv_highlight)
        expect(scope).not_to include(rv_highlight, kjv_other_chapter)
      end

      it "excludes highlights in the same translation as the viewer" do
        scope = Highlight.from_other_translations_in_chapter(
          translation_code: "KJV", book: "John", chapter: 3
        )
        expect(scope).not_to include(kjv_highlight)
        expect(scope).to include(rv_highlight)
      end

      it "filters out highlights in other chapters of the same book" do
        scope = Highlight.from_other_translations_in_chapter(
          translation_code: "RV1909", book: "John", chapter: 3
        )
        expect(scope).not_to include(kjv_other_chapter)
      end
    end
  end
end
