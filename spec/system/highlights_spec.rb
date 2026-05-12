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
        function walker() {
          return document.createTreeWalker(verse, NodeFilter.SHOW_TEXT, {
            acceptNode(n) {
              let p = n.parentElement;
              while (p && p !== verse) {
                if (p.dataset?.ignoreSelection !== undefined) return NodeFilter.FILTER_REJECT;
                p = p.parentElement;
              }
              return NodeFilter.FILTER_ACCEPT;
            }
          });
        }
        // Walk text nodes once, locating both the start and end text
        // nodes so the range can span highlight-introduced fragmentation
        // (e.g. selecting "For God" across plain "For " + highlighted
        // "God so" text nodes — Sprint 16.6 requires cross-fragment
        // ranges for the new range-intersection active-state contract).
        const startTarget = #{start_offset};
        const endTarget = startTarget + #{length};
        const w = walker();
        let n, soFar = 0;
        let startNode = null, startLocal = 0, endNode = null, endLocal = 0;
        while (n = w.nextNode()) {
          const len = n.textContent.length;
          if (startNode === null && soFar + len > startTarget) {
            startNode = n;
            startLocal = startTarget - soFar;
          }
          if (startNode !== null && soFar + len >= endTarget) {
            endNode = n;
            endLocal = endTarget - soFar;
            break;
          }
          soFar += len;
        }
        if (endNode === null) {
          endNode = startNode;
          endLocal = startNode.textContent.length;
        }
        const range = document.createRange();
        range.setStart(startNode, startLocal);
        range.setEnd(endNode, endLocal);
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

  describe "color-toggle removes the active highlight" do
    # Sprint 16.5 PR C — clicking the swatch that's already pressed
    # (active) DELETEs the dominant highlight under selection.
    # Q1 Option A: auto-destroy orphaned notes with a confirmation
    # gate when noteCount > 0; skip the dialog for noteCount == 0.

    it "removes the highlight on a single swatch click when noteCount is 0" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      highlight = create(:highlight, user: user, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!3",
                                     color: "gold")
      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-gold", text: "For")

      select_within_verse(v16.id, "For", start_offset: 0, length: 3)
      # Swatch is now aria-pressed=true (PR A); clicking it triggers
      # the toggle-remove branch in apply().
      find("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='true']", visible: :all).click

      expect(page).not_to have_css("span.highlight-gold")
      expect(Highlight.exists?(highlight.id)).to be false
    end

    it "asks for confirmation when noteCount > 0 and removes both highlight and note on accept" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      highlight = create(:highlight, user: user, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!3",
                                     color: "gold")
      note = create(:note, user: user, body: "test")
      create(:highlight_note, highlight: highlight, note: note)

      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-gold", text: "For")

      select_within_verse(v16.id, "For", start_offset: 0, length: 3)

      # Capybara's accept_confirm captures and accepts the
      # window.confirm dialog; the message includes the note count
      # via the bilingual I18n template's %{count} interpolation.
      page.accept_confirm(/1 note/) do
        find("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='true']", visible: :all).click
      end

      expect(page).not_to have_css("span.highlight-gold")
      expect(Highlight.exists?(highlight.id)).to be false
      expect(Note.exists?(note.id)).to be false
    end

    it "preserves both highlight and note when the user cancels the confirm" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      highlight = create(:highlight, user: user, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!3",
                                     color: "gold")
      note = create(:note, user: user, body: "test")
      create(:highlight_note, highlight: highlight, note: note)

      visit "/bible/kjv/john/3"
      select_within_verse(v16.id, "For", start_offset: 0, length: 3)

      page.dismiss_confirm do
        find("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='true']", visible: :all).click
      end

      # Both survive the cancel — atomic preserve-or-cascade contract.
      expect(page).to have_css("span.highlight-gold", text: "For")
      expect(Highlight.exists?(highlight.id)).to be true
      expect(Note.exists?(note.id)).to be true
    end
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

    # Sprint 16.6 — contract inversion. PR A's codified anchor-based
    # detection ("selection STARTS in plain text and extends into a
    # highlight → no active state") was deliberately deleted because
    # production friction showed it was wrong for the dominant use
    # case (overshoot-by-one-character when retargeting an existing
    # highlight). The new contract is range-intersection: any
    # [data-highlight-ids] span the selection range touches
    # participates; dominant is Math.max across all touched ids
    # (consistent with renderer + removeViaToggle's existing target).
    it "marks the highlight color when selection starts in plain text and extends into a single highlight" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      # Highlight covers offsets 4..10 ("God so").
      create(:highlight, user: user, translation: translation,
                         osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!10",
                         color: "rose")
      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-rose", text: "God so")

      # Select from offset 0 ("For ", PLAIN text) through into the
      # highlighted "God so" span. Pre-Sprint-16.6 this asserted
      # all swatches stay aria-pressed=false; post-inversion the
      # rose swatch is active (selection intersects the rose span).
      select_within_verse(v16.id, "For God", start_offset: 0, length: 7)

      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='rose'][aria-pressed='true']", visible: :all)
      Highlight::COLORS.reject { |c| c == "rose" }.each do |c|
        expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='#{c}'][aria-pressed='false']", visible: :all)
      end
    end

    it "marks the highest-id (dominant) highlight color when selection covers two highlights of different colors" do
      # Sprint 16.6 edge case: selection spans two non-overlapping
      # highlights of different colors. Per renderer's highest-id-wins
      # precedence and removeViaToggle's Math.max destroy target, the
      # active swatch reflects the higher-id highlight (latest-created).
      # The lower-id highlight is invisible to the active-state UI in
      # this scenario — accepted ambiguity until Sprint 19+ public
      # community highlights raise the two-color-overlap frequency.
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      # Lower-id gold on "God" (offsets 4..7), higher-id sage on
      # "loved" (offsets 11..16). Selecting "God so loved" intersects
      # both; sage (higher id) wins.
      create(:highlight, user: user, translation: translation,
                         osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7",
                         color: "gold")
      create(:highlight, user: user, translation: translation,
                         osis_ref: "Bible.KJV.John.3.16!11-Bible.KJV.John.3.16!16",
                         color: "sage")
      visit "/bible/kjv/john/3"
      expect(page).to have_css("span.highlight-gold", text: "God")
      expect(page).to have_css("span.highlight-sage", text: "loved")

      select_within_verse(v16.id, "God so loved", start_offset: 4, length: 12)

      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='sage'][aria-pressed='true']", visible: :all)
      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='false']", visible: :all)
    end
  end

  # Sprint 16.5 PR D — toolbar persistence + click-outside dismiss +
  # selection restoration across surgical streams. The end-state DOM
  # after a mutation matches the pre-PR-D end-state (highlight span
  # exists with right class + data-highlight-ids), but the route to
  # get there is now a turbo_stream replace instead of a full
  # Turbo.visit reload. Toolbar stays open, scroll preserved, active
  # state reflects the just-applied color.
  describe "toolbar persistence + click-outside dismiss" do
    it "keeps the toolbar visible after color apply (no full reload)" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      visit "/bible/kjv/john/3"
      select_within_verse(v16.id, "God", start_offset: 4, length: 3)

      find("[data-highlight-target='toolbar'] button[data-color='gold']", visible: :all).click

      # After PR D: stream replaces the verse, toolbar stays visible,
      # the just-applied gold swatch is now aria-pressed=true.
      expect(page).to have_css("span.highlight-gold", text: "God")
      expect(page).to have_css("[data-highlight-target='toolbar']:not([hidden])", visible: :all)
      expect(page).to have_css("[data-highlight-target='toolbar'] button[data-color='gold'][aria-pressed='true']", visible: :all)
    end

    it "dismisses the toolbar when the user clicks outside both the toolbar and the chapter" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      visit "/bible/kjv/john/3"
      select_within_verse(v16.id, "God", start_offset: 4, length: 3)
      expect(page).to have_css("[data-highlight-target='toolbar']:not([hidden])", visible: :all)

      # Click on the footer — definitively outside the toolbar AND
      # outside the chapter container. pointerdown listener fires
      # hideToolbar (covers both mouse and touch).
      find("footer").click

      expect(page).to have_css("[data-highlight-target='toolbar']", visible: :hidden)
    end

    it "re-anchors the toolbar to a new selection in a different verse" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      v17 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.17")
      visit "/bible/kjv/john/3"

      select_within_verse(v16.id, "God", start_offset: 4, length: 3)
      # data-anchor-verse-id is the deterministic wait target.
      # showToolbarAt sets it on the toolbar element after positioning;
      # have_css with attribute selector waits up to default_max_wait
      # for the rAF/syncSelection chain to settle. Avoids the
      # pixel-position math timing trap from PR D's first attempt
      # (evaluate_script is synchronous and reads stale layout before
      # rAF fires).
      expect(page).to have_css(%([data-highlight-target="toolbar"][data-anchor-verse-id="#{v16.id}"]), visible: :all)

      select_within_verse(v17.id, "God", start_offset: 4, length: 3)
      expect(page).to have_css(%([data-highlight-target="toolbar"][data-anchor-verse-id="#{v17.id}"]), visible: :all)
    end

    it "restores the selection across the turbo_stream replace on apply (same-verse)" do
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      visit "/bible/kjv/john/3"
      select_within_verse(v16.id, "God", start_offset: 4, length: 3)

      find("[data-highlight-target='toolbar'] button[data-color='gold']", visible: :all).click
      expect(page).to have_css("span.highlight-gold", text: "God")

      # Selection should be restored (Strategy 2). rangeCount > 0
      # AND toString matches the original snapshot text.
      range_count = page.evaluate_script("window.getSelection().rangeCount")
      expect(range_count).to be >= 1
      selected_text = page.evaluate_script("window.getSelection().toString()")
      expect(selected_text).to eq("God")
    end

    it "restores cross-verse selection across the turbo_stream replace" do
      # Cross-verse selection is a real user pattern — full sentences
      # often cross verse boundaries. Snapshot tracks both endpoints'
      # verse ids; restoration walks both verses. Risk-flag #7 from the
      # PR D plan asserted this would work via computeOffset re-use; this
      # spec is the verification that turns the assumption into a
      # contract.
      v16 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      v17 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.17")
      visit "/bible/kjv/john/3"

      # Select from "world" tail in v16 across into "For" head of v17.
      select_across_verses(v16.id, 21, v17.id, 7)
      find("[data-highlight-target='toolbar'] button[data-color='sage']", visible: :all).click

      expect(page).to have_css("span.highlight-sage", count: 2)

      range_count = page.evaluate_script("window.getSelection().rangeCount")
      expect(range_count).to be >= 1
      selected_text = page.evaluate_script("window.getSelection().toString()")
      # Selection should still span both verses — text contains a
      # substring from v16 ("world") and from v17 ("For God").
      expect(selected_text).to include("world")
      expect(selected_text).to include("For God")
    end
  end
end
