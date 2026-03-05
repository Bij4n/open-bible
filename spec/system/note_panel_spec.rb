require "rails_helper"

RSpec.describe "Note editor panel", type: :system, js: true do
  let(:user) { create(:user) }
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

  it "slides the panel in when the Note toolbar button is clicked" do
    visit "/bible/kjv/john/3"
    select_within(verse.id, 4, 3) # "God"
    find("[data-highlight-target='toolbar'] [data-action='highlight#note']", visible: :all).click

    expect(page).to have_selector(%(body[data-note-panel-open="true"]))
    expect(page).to have_selector("trix-editor", visible: :all)
    expect(page).to have_selector("form[action='/notes']", visible: :all)
    expect(Highlight.where(user: user, color: "gold").count).to eq(1)
  end
end
