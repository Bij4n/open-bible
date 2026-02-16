require "rails_helper"

RSpec.describe SearchHelper, type: :helper do
  describe "#verse_citation" do
    let(:translation) { create(:translation, :kjv) }
    let(:book) { create(:book, :john, translation: translation) }
    let(:chapter) { create(:chapter, book: book, number: 3) }
    let(:verse) do
      create(:verse, chapter: chapter, number: 16,
                     body_text: "For God so loved the world",
                     body_html: "For God so loved the world",
                     osis_ref: "Bible.KJV.John.3.16")
    end

    it "renders the English name for :en locale" do
      I18n.with_locale(:en) do
        expect(helper.verse_citation(verse)).to eq("John 3:16")
      end
    end

    it "renders the Spanish name for :es locale" do
      I18n.with_locale(:es) do
        expect(helper.verse_citation(verse)).to eq("Juan 3:16")
      end
    end
  end

  describe "#highlight_terms" do
    it "wraps every query term in <mark> tags, case-insensitive" do
      out = helper.highlight_terms("Love is patient, love is kind", "love")
      expect(out).to include("<mark>Love</mark>")
      expect(out).to include("<mark>love</mark>")
    end

    it "escapes HTML in the source text to prevent XSS" do
      out = helper.highlight_terms("<script>alert('x')</script> love", "love")
      expect(out).not_to include("<script>")
      expect(out).to include("&lt;script&gt;")
      expect(out).to include("<mark>love</mark>")
    end

    it "truncates plain text when the query is blank" do
      long = "word " * 100
      out  = helper.highlight_terms(long, "")
      expect(out.length).to be < long.length
    end

    it "centers the window around the first matched term" do
      lead = "prefix " * 60
      text = "#{lead}needle tail"
      out  = helper.highlight_terms(text, "needle", window: 60)
      expect(out).to include("<mark>needle</mark>")
      expect(out).to start_with("…")
    end
  end
end
