require "rails_helper"

RSpec.describe "Search", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end

  describe "GET /search" do
    it "renders the search form for anonymous visitors" do
      get "/search"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("name=\"q\"")
    end

    it "returns verse matches" do
      get "/search", params: { q: "loved" }
      expect(response).to have_http_status(:ok)
      # pg_search_highlight wraps matched terms in <mark>, so assert on the
      # surrounding phrase plus the highlighted term separately.
      expect(response.body).to include("For God so")
      expect(response.body).to include("<mark>loved</mark>")
      expect(response.body).to include("the world")
    end

    it "returns note matches for public notes when anonymous" do
      author = create(:user, display_name: "Apollos")
      create(:note, user: author, visibility: :public_note,
                    body: "<p>A thought on love and grace.</p>")
      get "/search", params: { q: "grace" }
      expect(response.body).to include("Apollos")
    end

    it "doesn't leak private notes to anonymous visitors" do
      author = create(:user)
      create(:note, user: author, visibility: :private_note,
                    body: "<p>Private love musings.</p>")
      get "/search", params: { q: "musings" }
      expect(response.body).not_to include("Private love musings")
    end

    it "respects scope=verses (notes excluded)" do
      author = create(:user, display_name: "Skipthis")
      create(:note, user: author, visibility: :public_note,
                    body: "<p>Love note content.</p>")
      get "/search", params: { q: "love", scope: "verses" }
      expect(response.body).to include("For God so")
      expect(response.body).to include("<mark>love")
      expect(response.body).not_to include("Skipthis")
    end

    it "respects scope=notes (verses excluded)" do
      author = create(:user, display_name: "Noteauthor")
      create(:note, user: author, visibility: :public_note,
                    body: "<p>Love note content.</p>")
      get "/search", params: { q: "love", scope: "notes" }
      expect(response.body).to include("Noteauthor")
      expect(response.body).not_to include("For God so loved the world")
    end

    it "shows an empty-query hint when q is blank" do
      get "/search"
      # Compare against the HTML-escaped form since ERB <%= escapes
      # apostrophes/quotes in the i18n string by default.
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("search.empty_hint")))
    end

    describe "mode=semantic" do
      let(:query_vector) { [ 1.0, 0.0 ] + Array.new(382, 0.0) }

      before do
        create(:verse_embedding, verse: verse, embedding: query_vector)
        allow(EmbeddingService).to receive_messages(
          healthy?: true,
          embed_texts: { "embeddings" => [ query_vector ], "model_version" => "all-MiniLM-L6-v2" }
        )
      end

      it "renders semantic verse results with the citation and similarity badge" do
        get "/search", params: { q: "divine love", mode: "semantic" }
        expect(response.body).to include("John 3:16")
        expect(response.body).to include("100% match")
      end

      it "falls back to keyword results and shows a banner when the service is down" do
        allow(EmbeddingService).to receive(:healthy?).and_return(false)
        get "/search", params: { q: "loved", mode: "semantic" }
        expect(response.body).to include(I18n.t("search.semantic_unavailable"))
        expect(response.body).to include("<mark>loved</mark>")
      end

      it "warns when scope=notes + mode=semantic (notes semantic search pending)" do
        get "/search", params: { q: "divine love", mode: "semantic", scope: "notes" }
        expect(response.body).to include(I18n.t("search.semantic_notes_pending"))
      end

      it "ignores unknown mode values and defaults to keyword" do
        get "/search", params: { q: "loved", mode: "nonsense" }
        expect(response.body).to include("<mark>loved</mark>")
      end
    end

    describe "translations scope" do
      let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }
      let!(:rv_john) do
        create(:book, osis_code: "John", translation: rv1909,
                      name_en: "John", name_es: "Juan", position: 43, testament: :new)
      end
      let!(:rv_chapter) { create(:chapter, book: rv_john, number: 3) }
      let!(:rv_verse) do
        create(:verse, chapter: rv_chapter, number: 16,
                       body_text: "Porque de tal manera amó Dios al mundo, loved",
                       body_html: "Porque de tal manera amó Dios al mundo, loved",
                       osis_ref: "Bible.RV1909.John.3.16")
      end

      it "defaults to KJV only (current translation)" do
        get "/search", params: { q: "loved" }
        expect(response.body).to include("For God so")
        expect(response.body).not_to include("Porque de tal manera")
      end

      it "scopes to the passed translation_code when translations=current" do
        get "/search", params: { q: "loved", translations: "current", translation_code: "RV1909" }
        expect(response.body).to include("Porque de tal manera")
        expect(response.body).not_to include("For God so")
      end

      it "spans every translation when translations=all" do
        get "/search", params: { q: "loved", translations: "all" }
        expect(response.body).to include("For God so")
        expect(response.body).to include("Porque de tal manera")
      end

      it "shows the translations radio group when multiple translations exist" do
        get "/search"
        expect(response.body).to include(I18n.t("search.translations.current"))
        expect(response.body).to include(I18n.t("search.translations.all"))
      end
    end
  end
end
