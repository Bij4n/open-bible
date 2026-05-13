require "rails_helper"

# One end-to-end note spec — the Sprint 3 note UI is a server-side
# Turbo Frame fetch of /notes/:id, no in-page note editor yet (the
# Action Text editor in a side panel lands Sprint 4 alongside sharing).
# We still want to cover the "note anchored to a highlight, survives
# reload, visible on click" lifecycle end-to-end.
RSpec.describe "Notes", type: :system, js: true do
  let(:user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:book) { create(:book, :john, translation: translation) }
  let(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let!(:highlight) do
    create(:highlight, user: user, translation: translation,
                       osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7",
                       color: "gold")
  end
  let!(:note) do
    n = create(:note, user: user, body: "<p>The hinge of the gospel.</p>")
    create(:highlight_note, highlight: highlight, note: n)
    n
  end

  it "shows a saved note via the Turbo Frame endpoint" do
    sign_in user
    visit "/notes/#{note.id}"
    expect(page).to have_content("The hinge of the gospel")
    expect(page).to have_content(/Bible\.KJV\.John\.3\.16!4-Bible\.KJV\.John\.3\.16!7/i)
  end

  it "shows a human citation in the note edit panel header" do
    sign_in user
    visit "/notes/#{note.id}/edit"
    expect(page).to have_content("John 3:16")
    expect(page).not_to have_content("Bible.KJV.John.3.16!")
  end

  it "renders the email share field with inputmode=email for mobile keyboards" do
    sign_in user
    visit "/notes/#{note.id}/edit"
    expect(page).to have_css("input[name='note[user_emails]'][inputmode='email']")
  end

  it "renders visibility radio labels as large touch-friendly rows" do
    sign_in user
    visit "/notes/#{note.id}/edit"
    # Each label must carry the touch-target class so tapping anywhere
    # on the row hits the radio — not just the 16px input itself.
    expect(page).to have_css("label.touch-target-row", minimum: 4)
  end

  describe "post-save flash", js: true do
    it "shows a status flash after saving from the reader page" do
      sign_in user
      visit "/bible/kjv/john/3"

      # Load the note form into the turbo frame and force the panel visible
      # so Capybara can interact with it (the aside starts off-screen via
      # translate-x-full, which in Tailwind v4 uses the CSS translate
      # property — a separate axis from transform).
      execute_script(<<~JS)
        document.getElementById('note_panel').setAttribute('src', '/notes/#{note.id}/edit');
        const c = document.getElementById('note-panel-container');
        c.classList.remove('translate-x-full');
        c.style.translate = '0 0';
        c.style.transition = 'none';
      JS

      expect(page).to have_css("trix-editor", visible: :all, wait: 5)
      click_button "Save note"

      expect(page).to have_css("#flash_container [role='status']", wait: 5)
    end
  end
end
