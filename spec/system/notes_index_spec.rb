require "rails_helper"

# My Notes index — authenticated list of the signed-in user's notes,
# newest first. rack_test driver — pure HTML, no JS-driven surfaces.
RSpec.describe "Notes index", type: :system do
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

  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  let!(:highlight) do
    create(:highlight, user: user, translation: translation,
                       osis_ref: "Bible.KJV.Gen.1.1!0-Bible.KJV.Gen.1.1!2",
                       color: "gold")
  end

  def make_note(u, visibility: "private_note", body: "<p>A note.</p>")
    n = create(:note, user: u, body: body, visibility: visibility)
    create(:highlight_note, highlight: highlight, note: n)
    n
  end

  describe "access control" do
    it "redirects guests to sign-in" do
      visit notes_path
      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "when signed in" do
    before { sign_in user }

    context "with notes" do
      let!(:private_note) { make_note(user, visibility: "private_note", body: "<p>My private thought.</p>") }
      let!(:public_note)  { make_note(user, visibility: "public_note",  body: "<p>My public thought.</p>") }

      it "shows the page heading" do
        visit notes_path
        expect(page).to have_content(I18n.t("notes.my_notes"))
      end

      it "shows the current user's notes" do
        visit notes_path
        expect(page).to have_content("My private thought")
        expect(page).to have_content("My public thought")
      end

      it "does not show other users' notes" do
        other_note = create(:note, user: other, body: "<p>Someone else's note.</p>", visibility: "public_note")
        visit notes_path
        expect(page).not_to have_content("Someone else's note")
      end

      it "shows the Private badge on a private note" do
        visit notes_path
        expect(page).to have_content(I18n.t("notes.badge.private_note"))
      end

      it "shows the Public badge on a public note" do
        visit notes_path
        expect(page).to have_content(I18n.t("notes.badge.public_note"))
      end

      it "links to the note edit page" do
        visit notes_path
        expect(page).to have_link(I18n.t("groups.edit"), href: edit_note_path(private_note))
      end
    end

    context "with no notes" do
      it "shows the empty state" do
        visit notes_path
        expect(page).to have_content(I18n.t("notes.empty"))
      end

      it "links to the Bible from the empty state" do
        visit notes_path
        expect(page).to have_link(I18n.t("home.cta_public_bible"))
      end
    end
  end
end
