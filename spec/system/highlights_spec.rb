require "rails_helper"

RSpec.describe "Highlights", type: :system, js: true do
  let(:user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:book) { create(:book, :john, translation: translation) }
  let(:chapter) { create(:chapter, book: book, number: 3) }

  before do
    # Known, small body_text so offset math is deterministic.
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
    create(:verse, chapter: chapter, number: 17,
                   body_text: "For God sent not his Son",
                   body_html: "For God sent not his Son",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.17")
    sign_in user
  end

  # Programmatically install a selection so we don't depend on fragile
  # mouse-drag simulation. The JS here finds the text node inside the
  # target verse that begins with `anchor_text` and selects
  # `anchor_text.length` characters from the given char offset.
  def select_within_verse(verse_id, anchor_text, start_offset: 0, length: nil)
    length ||= anchor_text.length
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
          if (soFar + textNode.textContent.length > #{start_offset}) break;
          soFar += textNode.textContent.length;
        }
        const localStart = #{start_offset} - soFar;
        const range = document.createRange();
        range.setStart(textNode, localStart);
        range.setEnd(textNode, Math.min(localStart + #{length}, textNode.textContent.length));
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      })()
    JS
  end

  # Select across two sibling text nodes in different verses.
  def select_across_verses(start_verse_id, start_offset, end_verse_id, end_offset)
    page.execute_script(<<~JS)
      (() => {
        function firstTextNode(verseId) {
          const verse = document.querySelector(`[data-verse-id="${verseId}"]`);
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
          return walker.nextNode();
        }
        const range = document.createRange();
        range.setStart(firstTextNode("#{start_verse_id}"), #{start_offset});
        range.setEnd(firstTextNode("#{end_verse_id}"), #{end_offset});
        const sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
      })()
    JS
  end

  it "creates a single-verse highlight that survives reload" do
    v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
    visit "/bible/kjv/john/3"

    select_within_verse(v16.id, "God", start_offset: 4, length: 3)

    find("[data-highlight-target='toolbar'] [data-color='gold']", visible: :all).click

    # Turbo.visit reloads the chapter — wait for the highlight span to appear.
    expect(page).to have_css("span.highlight-gold", text: "God")

    saved = Highlight.find_by(user: user, osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7")
    expect(saved).to be_present
    expect(saved.color).to eq("gold")
  end

  it "creates a cross-verse highlight with the correct per-verse boundaries" do
    v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
    v17 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.17")
    visit "/bible/kjv/john/3"

    # From offset 24 in verse 16 ("world") through offset 7 in verse 17 ("For God")
    select_across_verses(v16.id, 21, v17.id, 7)
    find("[data-highlight-target='toolbar'] [data-color='sage']", visible: :all).click

    expect(page).to have_css("span.highlight-sage", count: 2)
    saved = Highlight.find_by(user: user, color: "sage")
    expect(saved.osis_ref).to eq("Bible.KJV.John.3.16!21-Bible.KJV.John.3.17!7")
  end

  it "preserves Jesus-words styling underneath a highlight" do
    v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
    v16.update!(
      body_text: "For God so loved the world",
      body_html: "For God so loved the world",
      red_letter_ranges: [ [ 0, 26 ] ]
    )
    visit "/bible/kjv/john/3"
    select_within_verse(v16.id, "loved", start_offset: 11, length: 5)
    find("[data-highlight-target='toolbar'] [data-color='rose']", visible: :all).click

    expect(page).to have_css("span.jesus-words.highlight-rose", text: "loved")
    # Red-letter context around the highlight should remain italic red.
    expect(page).to have_css("span.jesus-words", text: /For God so/)
  end

  it "the × button dismisses the toolbar without destroying any highlight" do
    # Sprint 16.5 PR B regression-protect: the × used to call
    # highlight#remove (DELETE the highlight); it's now bound to
    # highlight#dismiss (hide toolbar + collapse selection only).
    # Removal is moving to the color-swatch toggle in PR C — no other
    # UI path destroys highlights between PR B merge and PR C merge.
    v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
    highlight = create(:highlight, user: user, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!3",
                                   color: "gold")
    visit "/bible/kjv/john/3"
    expect(page).to have_css("span.highlight-gold", text: "For")

    select_within_verse(v16.id, "For", start_offset: 0, length: 3)
    find("[data-highlight-target='toolbar'] [data-action='highlight#dismiss']", visible: :all).click

    # Toolbar hidden, highlight unchanged in DB and DOM, selection cleared.
    expect(page).to have_css("[data-highlight-target='toolbar']", visible: :hidden)
    expect(Highlight.exists?(highlight.id)).to be true
    expect(page).to have_css("span.highlight-gold", text: "For")
    expect(page.evaluate_script("window.getSelection().rangeCount")).to eq(0)

    # Active-state lifecycle: after × dismisses (and clears the active
    # ring on the gold swatch), re-selecting in plain text on a verse
    # without highlights opens a fresh toolbar with all swatches
    # un-pressed. Confirms the active-state from the prior selection
    # didn't leak through dismiss. Locks lifecycle behavior down before
    # PRs C/D/E build on top of it.
    v17 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.17")
    select_within_verse(v17.id, "For", start_offset: 0, length: 3)
    Highlight::COLORS.each do |c|
      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='#{c}'][aria-pressed='false']", visible: :all)
    end
  end

  it "does not show the toolbar for signed-out visitors" do
    sign_out user
    visit "/bible/kjv/john/3"

    # The toolbar target is not rendered when signed out, so it simply
    # isn't in the DOM.
    expect(page).not_to have_css("[data-highlight-target='toolbar']", visible: :all)
  end

  describe "active-state on toolbar swatches" do
    # When the toolbar opens over an existing highlight, the swatch
    # matching that highlight's color renders as visually-pressed
    # (aria-pressed="true" + an inset ink ring). This is the
    # discoverability hint for the toggle-to-remove pattern shipping in
    # PR C of the Sprint 16.5 cluster — the active swatch is the lever
    # the user clicks to remove the highlight.
    #
    # Detection is ANCHOR-BASED, not boundary-fuzzy: the active state
    # surfaces iff the selection's start container sits inside a
    # [data-highlight-ids] span. A selection that starts in plain text
    # and extends into a highlight produces NO active state. This is a
    # deliberate behavior choice — partial selections that don't begin
    # inside a highlight aren't "the active highlight," and the toggle
    # contract should match the user's mental anchor (where they
    # started selecting), not the selection's geometric extent.

    it "marks the matching swatch as aria-pressed when selection is inside an existing highlight" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      create(:highlight, user: user, translation: translation,
                         osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!11",
                         color: "gold")
      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-gold", text: "For God so")

      select_within_verse(v16.id, "God", start_offset: 4, length: 3)

      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='true']", visible: :all)
      Highlight::COLORS.reject { |c| c == "gold" }.each do |c|
        expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='#{c}'][aria-pressed='false']", visible: :all)
      end
    end

    it "marks no swatch as aria-pressed when the selection is in plain (un-highlighted) text" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      visit "/bible/kjv/john/3"

      # No highlights anywhere on this verse — plain selection.
      select_within_verse(v16.id, "God", start_offset: 4, length: 3)

      Highlight::COLORS.each do |c|
        expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='#{c}'][aria-pressed='false']", visible: :all)
      end
    end

    it "marks no swatch as aria-pressed when selection STARTS in plain text and extends into a highlight" do
      # Codifies the anchor-based detection contract. A selection that
      # begins in plain text and crosses into a highlighted span does
      # NOT surface the highlight's color as active. Future-readers:
      # this is intentional, not incidental — the active state follows
      # the user's selection START (their mental anchor), not the
      # selection's geometric extent.
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      # Highlight covers offsets 4..10 ("God so").
      create(:highlight, user: user, translation: translation,
                         osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!10",
                         color: "rose")
      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-rose", text: "God so")

      # Select from offset 0 ("For ", PLAIN text) through into the
      # highlighted "God" span.
      select_within_verse(v16.id, "For God", start_offset: 0, length: 7)

      Highlight::COLORS.each do |c|
        expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='#{c}'][aria-pressed='false']", visible: :all)
      end
    end
  end
end
