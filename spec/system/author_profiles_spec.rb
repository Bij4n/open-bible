require "rails_helper"

# Author profiles — /authors/:id. Publicly accessible. Shows only
# public_note visibility notes. Private and shared notes are not exposed.
# rack_test driver — static HTML page, no JS required.
RSpec.describe "Author profiles", type: :system do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :genesis, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 1) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 1,
                   body_text: "In the beginning",
                   body_html: "In the beginning",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.Gen.1.1")
  end

  let(:author)   { create(:user, display_name: "Jane Doe") }
  let!(:highlight) do
    create(:highlight, user: author, translation: translation,
                       osis_ref: "Bible.KJV.Gen.1.1",
                       color: "gold")
  end

  let!(:public_note) do
    n = create(:note, user: author, body: "<p>The opening chord.</p>", visibility: "public_note")
    create(:highlight_note, highlight: highlight, note: n)
    n
  end

  let!(:private_note) do
    create(:note, user: author, body: "<p>A private thought.</p>", visibility: "private_note")
  end

  let!(:shared_note) do
    create(:note, user: author, body: "<p>A shared thought.</p>", visibility: "shared_users")
  end

  describe "guest access" do
    it "renders the profile page without authentication" do
      visit author_path(author)
      expect(page).to have_content("Jane Doe")
    end

    it "shows public notes" do
      visit author_path(author)
      expect(page).to have_content("The opening chord")
    end

    it "does not show private notes" do
      visit author_path(author)
      expect(page).not_to have_content("A private thought")
    end

    it "does not show shared_users notes" do
      visit author_path(author)
      expect(page).not_to have_content("A shared thought")
    end

    it "returns 404 for a non-existent user" do
      visit author_path(id: 99999999)
      expect(page.status_code).to eq(404)
    end
  end

  describe "empty state" do
    let!(:no_notes_author) { create(:user, display_name: "Silent Reader") }

    it "shows the empty state when the author has no public notes" do
      visit author_path(no_notes_author)
      expect(page).to have_content(I18n.t("authors.no_public_notes"))
    end
  end

  describe "author link from public bible" do
    it "links the author name on the public bible note to the author profile" do
      visit public_bible_chapter_path(translation: "kjv", book: "gen", chapter: 1)
      expect(page).to have_link("Jane Doe", href: author_path(author))
    end
  end
end
