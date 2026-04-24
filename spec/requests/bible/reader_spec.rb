require "rails_helper"

RSpec.describe "Bible::Reader", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book) do
    create(:book, :john, translation: translation, osis_code: "John", position: 43)
  end
  let!(:chapter) { create(:chapter, book: book, number: 3) }

  before do
    # /bible/... is the signed-in personal reader as of Sprint 7.
    sign_in create(:user)

    create(:verse,
           chapter: chapter,
           number: 16,
           body_text: "For God so loved the world...",
           body_html: %(<span class="jesus-words">For God so loved the world...</span>),
           red_letter_ranges: [ [ 0, 30 ] ],
           osis_ref: "Bible.KJV.John.3.16")
    create(:verse,
           chapter: chapter,
           number: 17,
           body_text: "For God sent not his Son...",
           body_html: "For God sent not his Son...",
           red_letter_ranges: [],
           osis_ref: "Bible.KJV.John.3.17")
  end

  describe "GET /bible/:translation/:book/:chapter" do
    it "renders the chapter with verse bodies" do
      get "/bible/kjv/john/3"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("For God so loved the world")
      expect(response.body).to include(%(<span class="jesus-words">))
    end

    it "404s on unknown translation" do
      get "/bible/nope/john/3"
      expect(response).to have_http_status(:not_found)
    end

    it "404s on unknown book" do
      get "/bible/kjv/unknown/3"
      expect(response).to have_http_status(:not_found)
    end

    it "404s on unknown chapter" do
      get "/bible/kjv/john/99"
      expect(response).to have_http_status(:not_found)
    end

    it "301-redirects case-mismatched paths to the canonical lowercase form" do
      get "/bible/KJV/John/3"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to end_with("/bible/kjv/john/3")
    end

    it "matches books with multi-character osis codes case-insensitively" do
      create(:book, translation: translation, osis_code: "1Kgs", name_en: "1 Kings", name_es: "1 Reyes", position: 11, testament: :old)
      chap = create(:chapter, book: Book.find_by(osis_code: "1Kgs"), number: 1)
      create(:verse, chapter: chap, number: 1, body_text: "Now king David", body_html: "Now king David", osis_ref: "Bible.KJV.1Kgs.1.1")

      get "/bible/kjv/1kgs/1"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now king David")
    end
  end

  describe "GET /bible" do
    it "redirects a signed-in user with no default to KJV Gen 1" do
      get "/bible"
      expect(response).to redirect_to("/bible/kjv/gen/1")
    end

    it "honors the user's default_translation on entry" do
      rv = create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es")
      user = create(:user, default_translation: rv)
      sign_in user

      get "/bible"
      expect(response).to redirect_to("/bible/rv1909/gen/1")
    end

    it "redirects signed-out visitors to the public bible at KJV Gen 1" do
      sign_out :user
      get "/bible"
      expect(response).to redirect_to("/public/bible/kjv/gen/1")
    end
  end

  describe "translation picker in the reader" do
    it "shows the picker when more than one translation exists" do
      create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es")
      get "/bible/kjv/john/3"
      expect(response.body).to include(%(aria-label="Translation"))
      expect(response.body).to include("Reina-Valera 1909")
    end

    it "omits the picker when only one translation exists" do
      get "/bible/kjv/john/3"
      expect(response.body).not_to include(%(aria-label="Translation"))
    end

    it "picker options preserve book and chapter across translations" do
      rv = create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es")
      create(:book, osis_code: "John", translation: rv, name_en: "John", name_es: "Juan", position: 43, testament: :new)

      get "/bible/kjv/john/3"
      expect(response.body).to include(%(data-url="/bible/rv1909/john/3"))
    end
  end

  describe "cross-translation highlight badge" do
    let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }
    let!(:rv_book) do
      create(:book, osis_code: "John", translation: rv1909,
                    name_en: "John", name_es: "Juan", position: 43, testament: :new)
    end
    let!(:rv_chapter) { create(:chapter, book: rv_book, number: 3) }
    let!(:rv_verse) do
      create(:verse, chapter: rv_chapter, number: 16,
                     body_text: "Porque de tal manera amó Dios al mundo",
                     body_html: "Porque de tal manera amó Dios al mundo",
                     osis_ref: "Bible.RV1909.John.3.16")
    end

    it "badges verses the current user highlighted in another translation" do
      current = User.last
      current.highlights.create!(translation: translation,
                                 osis_ref: "Bible.KJV.John.3.16", color: "gold")

      get "/bible/rv1909/john/3"
      expect(response.body).to include("cross-translation-badge")
    end

    it "does not badge verses with no cross-translation highlights" do
      get "/bible/rv1909/john/3"
      expect(response.body).not_to include("cross-translation-badge")
    end

    it "renders the badge as a link to the other translation's chapter" do
      current = User.last
      current.highlights.create!(translation: translation,
                                 osis_ref: "Bible.KJV.John.3.16", color: "gold")

      get "/bible/rv1909/john/3"
      # Attribute order in Rails link_to output isn't guaranteed, so
      # match on both pieces separately rather than asserting a full tag.
      expect(response.body).to include("cross-translation-badge")
      expect(response.body).to include(%(href="/bible/kjv/john/3"))
    end

    it "interpolates the source translation code into the badge tooltip" do
      current = User.last
      current.highlights.create!(translation: translation,
                                 osis_ref: "Bible.KJV.John.3.16", color: "gold")

      get "/bible/rv1909/john/3"
      # The rendered HTML escapes the apostrophe in "You've"; match on
      # the unique middle substring that won't be re-encoded.
      expect(response.body).to include("annotated this verse in KJV")
    end
  end
end
