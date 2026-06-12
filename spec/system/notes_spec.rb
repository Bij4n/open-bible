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

  describe "friend picker (Sprint R6)" do
    let(:friend)   { create(:user, display_name: "Lydia") }
    let(:stranger) { create(:user, display_name: "Demetrius") }

    before do
      user.follow!(friend)
      friend.follow!(user)
      user.follow!(stranger) # one-way: not a friend, must not appear
      sign_in user
    end

    it "lists mutual friends as checkboxes in the Specific people section" do
      visit "/notes/#{note.id}/edit"

      expect(page).to have_css("input[type='checkbox'][name='note[user_ids][]'][value='#{friend.id}']", visible: :all)
      expect(page).to have_text("Lydia")
      expect(page).not_to have_css("input[type='checkbox'][name='note[user_ids][]'][value='#{stranger.id}']", visible: :all)
      # The email input survives as the invite-by-email fallback.
      expect(page).to have_css("input[name='note[user_emails]']", visible: :all)
    end

    it "pre-checks friends the note is already shared with" do
      create(:note_share, note: note, shareable: friend)
      visit "/notes/#{note.id}/edit"

      expect(page).to have_css("input[name='note[user_ids][]'][value='#{friend.id}'][checked]", visible: :all)
    end
  end

  it "renders the email share field with inputmode=email for mobile keyboards" do
    sign_in user
    visit "/notes/#{note.id}/edit"
    expect(page).to have_css("input[name='note[user_emails]'][inputmode='email']")
  end

  it "renders visibility radio labels as large touch-friendly rows inside the Post-to menu" do
    sign_in user
    visit "/notes/#{note.id}/edit"
    # Each label must carry the touch-target class so tapping anywhere
    # on the row hits the radio — not just the 16px input itself. The
    # rows live inside the (closed-by-default) Post-to details menu.
    expect(page).to have_css("[data-note-panel-target='postMenu'] label.touch-target-row", minimum: 4, visible: :all)
  end

  describe "post-save flash", js: true do
    it "shows a status flash after saving from the reader page" do
      sign_in user
      visit "/bible/kjv/john/3"

      # Load the note form into the turbo frame and open the panel.
      # Disable transition so Capybara doesn't race the 150ms slide.
      execute_script(<<~JS)
        document.getElementById('note-panel-container').style.transition = 'none';
        document.body.dataset.notePanelOpen = 'true';
        document.getElementById('note_panel').setAttribute('src', '/notes/#{note.id}/edit');
      JS

      expect(page).to have_css("trix-editor", visible: :all, wait: 5)
      click_button "Save note"

      expect(page).to have_css("#flash_container [role='status']", wait: 5)
    end
  end

  describe "public visibility confirmation", js: true do
    # The note panel runs inside a turbo-frame that lives in the main
    # layout. Visiting /notes/:id/edit directly returns just the partial
    # (no layout, no Stimulus). Instead we load the form into the frame
    # from the reader page, which carries the full layout + Stimulus JS.
    before do
      sign_in user
      visit "/bible/kjv/john/3"
      page.execute_script(<<~JS)
        document.getElementById('note-panel-container').style.transition = 'none';
        document.body.dataset.notePanelOpen = 'true';
        document.getElementById('note_panel').src = '/notes/#{note.id}/edit';
      JS
      expect(page).to have_css("input[name='note[visibility]'][value='public_note']", visible: :all)
    end

    it "shows an inline warning when Public is selected instead of a browser confirm dialog" do
      expect(page).to have_css("[data-note-panel-target='publicWarning']", visible: false)
      find("[data-note-panel-target='postMenu'] summary").click
      choose "Public"
      expect(page).to have_css("[data-note-panel-target='publicWarning']", visible: true)
    end

    it "reverts to Private when the user cancels the public warning" do
      find("[data-note-panel-target='postMenu'] summary").click
      choose "Public"
      expect(page).to have_css("[data-note-panel-target='publicWarning']", visible: true)

      click_button "Go back"

      expect(page).to have_css("[data-note-panel-target='publicWarning']", visible: false)
      expect(page).to have_field("note[visibility]", with: "private_note", visible: :all)
    end

    it "keeps Public selected when the user confirms" do
      find("[data-note-panel-target='postMenu'] summary").click
      choose "Public"
      click_button "Make it public"

      expect(page).to have_css("[data-note-panel-target='publicWarning']", visible: false)
      expect(page).to have_field("note[visibility]", with: "public_note", visible: :all)
    end
  end
end
