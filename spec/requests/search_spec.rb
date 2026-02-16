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
      expect(response.body).to include(I18n.t("search.empty_hint"))
    end
  end
end
