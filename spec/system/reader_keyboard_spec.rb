require "rails_helper"

# Design-v3 keyboard verbs (Readwise pattern): j/k move a visible verse
# focus, H highlights the focused verse with the default color, N opens
# the note panel for it. Keys are ignored while typing (inputs, Trix).
RSpec.describe "Reader keyboard verbs", type: :system, js: true do
  let(:user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:book) { create(:book, :john, translation: translation) }
  let(:chapter) { create(:chapter, book: book, number: 3) }

  before do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
    create(:verse, chapter: chapter, number: 17,
                   body_text: "For God sent not his Son",
                   body_html: "For God sent not his Son",
                   osis_ref: "Bible.KJV.John.3.17")
    sign_in user
    visit "/bible/kjv/john/3"
  end

  it "j/k move the verse focus" do
    find("body").send_keys("j")
    expect(page).to have_css(".verse.verse-kbd-focus[data-osis-ref='Bible.KJV.John.3.16']")

    find("body").send_keys("j")
    expect(page).to have_css(".verse.verse-kbd-focus[data-osis-ref='Bible.KJV.John.3.17']")
    expect(page).to have_css(".verse.verse-kbd-focus", count: 1)

    find("body").send_keys("k")
    expect(page).to have_css(".verse.verse-kbd-focus[data-osis-ref='Bible.KJV.John.3.16']")
  end

  it "H highlights the focused verse with the default color" do
    find("body").send_keys("j", "h")

    expect(page).to have_css("span.highlight-yellow")
    saved = Highlight.find_by(user: user, osis_ref: "Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!26")
    expect(saved).to be_present
    expect(saved.color).to eq(Highlight::DEFAULT_COLOR)
  end

  it "N opens the note panel for the focused verse with a default-color highlight" do
    find("body").send_keys("j", "n")

    expect(page).to have_selector("trix-editor", visible: :all)
    expect(Highlight.last.color).to eq(Highlight::DEFAULT_COLOR)
  end

  it "ignores verbs while typing in the note editor" do
    find("body").send_keys("j", "n")
    expect(page).to have_selector("trix-editor", visible: :all)

    find("trix-editor").send_keys("j")

    # Focus must not have advanced to verse 17 — the keystroke went
    # into the editor, not the reader.
    expect(page).to have_css(".verse.verse-kbd-focus[data-osis-ref='Bible.KJV.John.3.16']")
    expect(page).not_to have_css(".verse.verse-kbd-focus[data-osis-ref='Bible.KJV.John.3.17']")
  end
end
