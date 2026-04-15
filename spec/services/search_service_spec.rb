require "rails_helper"

RSpec.describe SearchService do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:love_verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let!(:faith_verse) do
    create(:verse, chapter: chapter, number: 17,
                   body_text: "But without faith none can please Him",
                   body_html: "But without faith none can please Him",
                   osis_ref: "Bible.KJV.John.3.17")
  end

  let(:author) { create(:user) }
  let!(:love_note) do
    create(:note, user: author, visibility: :public_note,
                  body: "<p>A note on love and grace.</p>")
  end
  let!(:private_love_note) do
    create(:note, user: author, visibility: :private_note,
                  body: "<p>Private thought on love.</p>")
  end
  let!(:hidden_public_note) do
    create(:note, user: author, visibility: :public_note,
                  body: "<p>A hidden love note.</p>",
                  hidden_at: Time.current)
  end

  describe "#call with scope: 'all'" do
    it "returns both verse and note matches for anonymous visitors" do
      results = described_class.new(query: "love").call
      expect(results[:verses]).to include(love_verse)
      expect(results[:notes]).to include(love_note)
    end

    it "excludes notes the anonymous visitor can't see" do
      results = described_class.new(query: "love").call
      expect(results[:notes]).not_to include(private_love_note)
      expect(results[:notes]).not_to include(hidden_public_note)
    end

    it "includes the current user's private notes when signed in" do
      results = described_class.new(query: "love", user: author).call
      expect(results[:notes]).to include(private_love_note)
    end
  end

  describe "#call with scope: 'verses'" do
    it "returns only verse matches" do
      results = described_class.new(query: "love", scope: "verses").call
      expect(results[:verses]).to include(love_verse)
      expect(results[:notes]).to be_empty
    end
  end

  describe "#call with scope: 'notes'" do
    it "returns only note matches" do
      results = described_class.new(query: "love", scope: "notes").call
      expect(results[:notes]).to include(love_note)
      expect(results[:verses]).to be_empty
    end
  end

  describe "#call with a blank query" do
    it "returns empty result buckets" do
      results = described_class.new(query: "   ").call
      expect(results[:verses]).to be_empty
      expect(results[:notes]).to be_empty
    end
  end

  describe "#call with an unknown scope" do
    it "falls back to empty results rather than raising" do
      results = described_class.new(query: "love", scope: "banana").call
      expect(results[:verses]).to be_empty
      expect(results[:notes]).to be_empty
    end
  end

  describe "result limits" do
    it "caps verse results at VERSE_LIMIT" do
      stub_const("SearchService::VERSE_LIMIT", 1)
      results = described_class.new(query: "the").call
      expect(results[:verses].size).to be <= 1
    end
  end

  describe "translations scope" do
    let!(:rv1909)     { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }
    let!(:rv_john)    { create(:book, osis_code: "John", translation: rv1909, name_en: "John", name_es: "Juan", position: 43, testament: :new) }
    let!(:rv_chapter) { create(:chapter, book: rv_john, number: 3) }
    let!(:rv_love_verse) do
      create(:verse, chapter: rv_chapter, number: 16,
                     body_text: "Porque de tal manera amó love",
                     body_html: "Porque de tal manera amó love",
                     osis_ref: "Bible.RV1909.John.3.16")
    end

    it "defaults to the current translation only (KJV)" do
      results = described_class.new(query: "love", translations: "current", translation_code: "KJV").call
      expect(results[:verses]).to include(love_verse)
      expect(results[:verses]).not_to include(rv_love_verse)
    end

    it "scopes to the passed translation_code when translations: 'current'" do
      results = described_class.new(query: "love", translations: "current", translation_code: "RV1909").call
      expect(results[:verses]).to include(rv_love_verse)
      expect(results[:verses]).not_to include(love_verse)
    end

    it "searches every translation when translations: 'all'" do
      results = described_class.new(query: "love", translations: "all").call
      expect(results[:verses]).to include(love_verse, rv_love_verse)
    end

    it "treats unknown translations values as 'current'" do
      results = described_class.new(query: "love", translations: "banana", translation_code: "KJV").call
      expect(results[:verses]).to include(love_verse)
      expect(results[:verses]).not_to include(rv_love_verse)
    end
  end
end
