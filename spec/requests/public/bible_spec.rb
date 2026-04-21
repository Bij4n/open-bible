require "rails_helper"

RSpec.describe "Public::Bible", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let(:author) { create(:user, display_name: "Apollos") }

  def public_note!(body:, featured: false)
    # Each note gets its own author (and thus its own highlight —
    # Highlight uniqueness is scoped to user_id/osis_ref/color).
    user = create(:user)
    highlight = create(:highlight, user: user, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: user, body: "<p>#{body}</p>",
                         visibility: :public_note, featured: featured,
                         featured_at: (featured ? Time.current : nil))
    create(:highlight_note, highlight: highlight, note: note)
    note
  end

  describe "GET /public/bible/:translation/:book/:chapter" do
    it "renders for anonymous visitors" do
      public_note!(body: "Community thought")
      get "/public/bible/kjv/john/3"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("For God so loved the world")
      expect(response.body).to include("Community thought")
    end

    it "excludes hidden notes from anonymous view" do
      hidden = public_note!(body: "Bad content")
      hidden.update!(hidden_at: Time.current)
      get "/public/bible/kjv/john/3"
      expect(response.body).not_to include("Bad content")
    end

    it "includes hidden notes when viewed by an admin" do
      hidden = public_note!(body: "Under review")
      hidden.update!(hidden_at: Time.current)
      admin = create(:user, admin: true)
      sign_in admin
      get "/public/bible/kjv/john/3"
      expect(response.body).to include("Under review")
    end

    it "redirects signed-out visitors from /bible to /public/bible" do
      get "/bible/kjv/john/3"
      expect(response).to redirect_to("/public/bible/kjv/john/3")
    end

    it "301-redirects case-mismatched paths to lowercase canonical" do
      get "/public/bible/KJV/John/3"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to end_with("/public/bible/kjv/john/3")
    end

    it "404s on unknown translations" do
      get "/public/bible/xyz/john/3"
      expect(response).to have_http_status(:not_found)
    end

    it "orders notes: featured first, then popular, then newest" do
      plain_old = public_note!(body: "OLD PLAIN")
      plain_old.update!(created_at: 2.days.ago)
      popular = public_note!(body: "POPULAR")
      2.times { create(:upvote, note: popular) }
      pinned = public_note!(body: "PINNED", featured: true)

      get "/public/bible/kjv/john/3"
      body = response.body
      expect(body.index("PINNED")).to be < body.index("POPULAR")
      expect(body.index("POPULAR")).to be < body.index("OLD PLAIN")
    end
  end

  describe "translation picker on /public/bible/:translation/:book/:chapter" do
    it "is not rendered when only one translation is installed" do
      get "/public/bible/kjv/john/3"
      expect(response.body).not_to include('data-controller="translation-picker"')
    end

    it "renders the picker when two translations are installed, with options pointing at the same chapter in each translation and the current one marked selected" do
      rv1909 = create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es")
      rv_book = create(:book, :john, translation: rv1909)
      rv_chapter = create(:chapter, book: rv_book, number: 3)
      create(:verse, chapter: rv_chapter, number: 16,
                     body_text: "Porque de tal manera amó Dios al mundo",
                     body_html: "Porque de tal manera amó Dios al mundo",
                     red_letter_ranges: [],
                     osis_ref: "Bible.RV1909.John.3.16")

      get "/public/bible/kjv/john/3"
      expect(response.body).to include('data-controller="translation-picker"')
      expect(response.body).to include(%(value="/public/bible/kjv/john/3"))
      expect(response.body).to include(%(value="/public/bible/rv1909/john/3"))
      expect(response.body).to match(%r{<option[^>]*value="/public/bible/kjv/john/3"[^>]*selected}i)
    end
  end

  describe "GET / (root) for signed-out users" do
    it "renders the home page with a Read the Bible CTA" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/public/bible/kjv/gen/1")
    end
  end
end
