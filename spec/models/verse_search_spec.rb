require "rails_helper"

RSpec.describe Verse, ".search_text" do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }

  let!(:love_verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world, that he gave his only begotten Son",
                   body_html: "For God so loved...",
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let!(:faith_verse) do
    create(:verse, chapter: chapter, number: 17,
                   body_text: "But without faith it is impossible to please God",
                   body_html: "But without faith...",
                   osis_ref: "Bible.KJV.John.3.17")
  end

  it "finds verses containing the search term" do
    results = Verse.search_text("love")
    expect(results).to include(love_verse)
    expect(results).not_to include(faith_verse)
  end

  it "is case-insensitive" do
    expect(Verse.search_text("LOVE")).to include(love_verse)
  end

  it "supports partial-word prefix matches" do
    # "lov" matches "loved" via tsearch prefix
    expect(Verse.search_text("lov")).to include(love_verse)
  end

  it "returns an empty relation for a no-match query" do
    expect(Verse.search_text("zzzzzzz")).to be_empty
  end

  it "exposes a highlight method that wraps matches in <mark>" do
    hit = Verse.search_text("love").with_pg_search_highlight.first
    expect(hit.pg_search_highlight).to include("<mark>")
    expect(hit.pg_search_highlight).to include("</mark>")
  end
end
