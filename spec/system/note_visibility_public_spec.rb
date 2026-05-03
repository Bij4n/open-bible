require "rails_helper"

# Sprint 22.1 — public_note enabled. The form's 4 visibilities all
# render now (the "Coming in Sprint 7" disabled stub is gone). The
# Public radio carries a confirm-on-change handler in the
# note_panel_controller so users can't accidentally publish to the
# public bible reader.
#
# End-to-end "anonymous visitor sees the new public note" is already
# covered by spec/requests/public/bible_spec.rb (the existing
# public_note! helper creates the note directly + asserts visibility);
# this spec covers the form-side gate that was blocking creation.
RSpec.describe "Note visibility — public", type: :system, js: true do
  let(:user) { create(:user, display_name: "Apollos") }
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)    { create(:book, :john, translation: translation) }
  let!(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end

  before { sign_in user }

  def select_within(verse_id, offset, length)
    page.execute_script(<<~JS)
      (() => {
        const verse = document.querySelector('[data-verse-id="#{verse_id}"]');
        const walker = document.createTreeWalker(verse, NodeFilter.SHOW_TEXT, {
          acceptNode(n) {
            let p = n.parentElement;
            while (p && p !== verse) {
              if (p.dataset?.ignoreSelection !== undefined) return NodeFilter.FILTER_REJECT;
              p = p.parentElement;
            }
            return NodeFilter.FILTER_ACCEPT;
          }
        });
        let textNode, soFar = 0;
        while (textNode = walker.nextNode()) {
          if (soFar + textNode.textContent.length > #{offset}) break;
          soFar += textNode.textContent.length;
        }
        const localStart = #{offset} - soFar;
        const range = document.createRange();
        range.setStart(textNode, localStart);
        range.setEnd(textNode, Math.min(localStart + #{length}, textNode.textContent.length));
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      })()
    JS
  end

  def open_note_panel
    visit "/bible/kjv/john/3"
    select_within(verse.id, 4, 3) # "God"
    find("[data-highlight-target='toolbar'] [data-action='highlight#note']", visible: :all).click
    expect(page).to have_selector("trix-editor", visible: :all)
  end

  it "renders all four visibility radios (no disabled Sprint-7 stub)" do
    open_note_panel
    %w[private_note shared_users shared_groups public_note].each do |v|
      expect(page).to have_selector(%(input[name="note[visibility]"][value="#{v}"]:not([disabled])), visible: :all)
    end
    expect(page).to have_no_content("Coming in Sprint 7")
  end

  it "persists a public note when the user confirms the public-publish dialog" do
    open_note_panel
    page.accept_confirm do
      find('input[name="note[visibility]"][value="public_note"]', visible: :all).click
    end
    page.execute_script("document.querySelector('trix-editor').editor.insertString('A community thought.')")
    find('form[action="/notes"] input[type="submit"]').click

    expect(page).to have_no_selector(%(body[data-note-panel-open="true"]))
    persisted = Note.last
    expect(persisted.user).to eq(user)
    expect(persisted.visibility).to eq("public_note")
    expect(persisted.body.to_plain_text).to include("A community thought")
  end

  it "reverts to private_note when the user declines the public-publish dialog" do
    open_note_panel
    page.dismiss_confirm do
      find('input[name="note[visibility]"][value="public_note"]', visible: :all).click
    end
    expect(page).to have_selector('input[name="note[visibility]"][value="private_note"]:checked', visible: :all)
    expect(page).to have_no_selector('input[name="note[visibility]"][value="public_note"]:checked', visible: :all)
  end
end
