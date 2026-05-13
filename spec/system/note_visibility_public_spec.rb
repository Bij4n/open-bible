require "rails_helper"

# Sprint 22.1 — public_note enabled. The form's 4 visibilities all
# render now (the "Coming in Sprint 7" disabled stub is gone). The
# Public radio shows an inline amber warning panel (Sprint 25 PR #100,
# replaced the earlier window.confirm() approach) so users can't
# accidentally publish to the public bible reader.
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

  # The radios and warning-panel buttons live inside the slide-in note
  # panel (#note-panel-container) which has overflow-y-auto. Direct
  # `find(el).click` fails under headless Firefox because Selenium's
  # pre-click "scroll into view" step doesn't reliably reach into a
  # fixed-position panel's inner scroll container. Use JS dispatch
  # instead — triggers Stimulus actions exactly as a real user click
  # would, without relying on Selenium's positioning logic.
  def trigger_public_radio_change
    page.execute_script(<<~JS)
      const radio = document.querySelector('input[name="note[visibility]"][value="public_note"]');
      radio.checked = true;
      radio.dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end

  def click_accept_public
    page.execute_script(<<~JS)
      document.querySelector('[data-action="note-panel#acceptPublic"]').click();
    JS
  end

  def click_cancel_public
    page.execute_script(<<~JS)
      document.querySelector('[data-action="note-panel#cancelPublic"]').click();
    JS
  end

  it "persists a public note when the user confirms the public-publish dialog" do
    open_note_panel
    trigger_public_radio_change
    expect(page).to have_css("[data-note-panel-target='publicWarning']:not([hidden])", visible: :all)
    click_accept_public
    page.execute_script("document.querySelector('trix-editor').editor.insertString('A community thought.')")

    expect {
      page.execute_script("document.querySelector('form[action=\"/notes\"]').requestSubmit()")
      Timeout.timeout(Capybara.default_max_wait_time) do
        sleep 0.05 until Note.exists?
      end
    }.to change(Note, :count).by(1)

    persisted = Note.last
    expect(persisted.user).to eq(user)
    expect(persisted.visibility).to eq("public_note")
    expect(persisted.body.to_plain_text).to include("A community thought")
  end

  it "reverts to private_note when the user declines the public-publish dialog" do
    open_note_panel
    trigger_public_radio_change
    expect(page).to have_css("[data-note-panel-target='publicWarning']:not([hidden])", visible: :all)
    click_cancel_public
    expect(page).to have_selector('input[name="note[visibility]"][value="private_note"]:checked', visible: :all)
    expect(page).to have_no_selector('input[name="note[visibility]"][value="public_note"]:checked', visible: :all)
  end
end
