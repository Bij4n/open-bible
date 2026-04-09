require "rails_helper"

RSpec.describe "Semantic search", type: :system do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let(:query_vector) { [ 1.0, 0.0 ] + Array.new(382, 0.0) }

  before do
    create(:verse_embedding, verse: verse, embedding: query_vector)
  end

  it "switches from keyword to concept mode and shows similarity badge" do
    allow(EmbeddingService).to receive_messages(
      healthy?: true,
      embed_texts: { "embeddings" => [ query_vector ], "model_version" => "all-MiniLM-L6-v2" }
    )

    visit "/search?q=divine+love"
    # Default mode is keyword — no match on "divine" so no hit.
    expect(page).not_to have_content("100% match")

    choose I18n.t("search.modes.semantic")
    find("input[type='submit'][value='#{I18n.t('search.submit')}']").click

    expect(page).to have_content("John 3:16")
    expect(page).to have_content("100% match")
    expect(page).to have_content(I18n.t("search.semantic_explanation"))
  end

  it "shows the fallback banner when the embedding service is down" do
    allow(EmbeddingService).to receive(:healthy?).and_return(false)

    visit "/search?q=loved&mode=semantic"
    expect(page).to have_content(I18n.t("search.semantic_unavailable"))
    # Keyword results still render beneath the banner.
    expect(page).to have_content("John 3:16")
  end

  it "warns when scope=notes + mode=semantic" do
    allow(EmbeddingService).to receive_messages(
      healthy?: true,
      embed_texts: { "embeddings" => [ query_vector ], "model_version" => "all-MiniLM-L6-v2" }
    )

    visit "/search?q=divine+love&mode=semantic&scope=notes"
    expect(page).to have_content(I18n.t("search.semantic_notes_pending"))
  end
end
