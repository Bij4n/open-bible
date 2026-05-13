require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#osis_citation" do
    let(:translation) { create(:translation, :kjv) }
    let!(:book) { create(:book, :john, translation: translation) }

    it "formats a single-verse ref as 'John 3:16'" do
      I18n.with_locale(:en) do
        expect(helper.osis_citation("Bible.KJV.John.3.16")).to eq("John 3:16")
      end
    end

    it "formats a character-offset span on one verse as 'John 3:16'" do
      I18n.with_locale(:en) do
        expect(helper.osis_citation("Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7")).to eq("John 3:16")
      end
    end

    it "formats a multi-verse span in the same chapter as 'John 3:16–17'" do
      I18n.with_locale(:en) do
        expect(helper.osis_citation("Bible.KJV.John.3.16-Bible.KJV.John.3.17")).to eq("John 3:16–17")
      end
    end

    it "uses the Spanish book name for :es locale" do
      I18n.with_locale(:es) do
        expect(helper.osis_citation("Bible.KJV.John.3.16")).to eq("Juan 3:16")
      end
    end

    it "falls back to the raw OSIS string when the book is not in the DB" do
      raw = "Bible.KJV.Rev.22.21"
      expect(helper.osis_citation(raw)).to eq(raw)
    end
  end
end
