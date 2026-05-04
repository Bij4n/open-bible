require "rails_helper"

# Sprint 22.2 — homepage hero verse card. Renders only when an admin
# has featured a public note (Note.public_visible.featured); otherwise
# the hero degrades to the single-column text-only layout.
RSpec.describe "Homepage hero verse card", type: :request do
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

  describe "GET / with no featured public notes" do
    it "renders the hero text without a verse card" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("home.welcome_html"))
      expect(response.body).not_to include("Apollos")
    end

    it "leaves the hero text-only when a non-featured public note exists (note still surfaces in community section, just not the hero)" do
      note = create(:note, user: author, body: "<p>The hinge of the gospel.</p>", visibility: :public_note)
      highlight = create(:highlight, user: author, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7",
                                     color: "gold")
      create(:highlight_note, highlight: highlight, note: note)

      get "/"
      expect(response).to have_http_status(:ok)
      # Hero stays single-column (no md:grid-cols-[1.1fr_1fr] signature)
      expect(response.body).not_to include("md:grid-cols-[1.1fr_1fr]")
      # The note IS in the page (community section), just not the hero
      expect(response.body).to include("hinge of the gospel")
    end
  end

  describe "GET / with a featured public note" do
    let!(:note) do
      n = create(:note, user: author,
                        body: "<p>The hinge of the gospel.</p>",
                        visibility: :public_note,
                        featured: true,
                        featured_at: 1.minute.ago)
      hl = create(:highlight, user: author, translation: translation,
                              osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7",
                              color: "gold")
      create(:highlight_note, highlight: hl, note: n)
      n
    end

    it "renders the verse card with author + body + verse text" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Apollos")
      expect(response.body).to include("hinge of the gospel")
      # render_verse_with_highlights splits "For God so loved the world"
      # into fragments around the highlight span, so we check fragments
      # individually rather than the whole string.
      expect(response.body).to include("For ")
      expect(response.body).to include("highlight-gold")
      expect(response.body).to include(">God<")
      expect(response.body).to include(" so loved the world")
      expect(response.body).to include("John 3 · 16")
    end

    it "links the card to the verse's public bible chapter" do
      get "/"
      expect(response.body).to include('href="/public/bible/kjv/john/3"')
    end

    it "skips a hidden featured note (admin-moderated)" do
      note.update!(hidden_at: Time.current)
      get "/"
      expect(response.body).not_to include("hinge of the gospel")
    end

    it "picks the most-recently-featured note when multiple exist" do
      newer = create(:user, display_name: "Priscilla")
      newer_hl = create(:highlight, user: newer, translation: translation,
                                    osis_ref: "Bible.KJV.John.3.16!11-Bible.KJV.John.3.16!16",
                                    color: "rose")
      newer_note = create(:note, user: newer,
                                 body: "<p>Newer thought.</p>",
                                 visibility: :public_note,
                                 featured: true,
                                 featured_at: Time.current)
      create(:highlight_note, highlight: newer_hl, note: newer_note)

      get "/"
      # Newer featured note wins the hero spot. Older one drops down
      # to the community section (still visible, not gone).
      expect(response.body).to include("Priscilla")
      expect(response.body).to include("Newer thought")
      expect(response.body).to include("Apollos")
      expect(response.body).to include("hinge of the gospel")
      # Hero card is the newer note's. Sanity-check that Priscilla's
      # ref appears before Apollos's in the document order (hero is
      # rendered before the community section).
      expect(response.body.index("Priscilla")).to be < response.body.index("Apollos")
    end
  end
end
