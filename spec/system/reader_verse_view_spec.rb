require "rails_helper"

# Design-v3 verse-view toggle: continuous prose (default) vs
# one-verse-per-block "study mode". Pure view-layer preference,
# persisted in localStorage.
RSpec.describe "Reader verse view toggle", type: :system, js: true do
  let(:user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:book) { create(:book, :john, translation: translation) }
  let(:chapter) { create(:chapter, book: book, number: 3) }

  before do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
    sign_in user
  end

  it "toggles verse-per-block layout and persists across reload" do
    visit "/bible/kjv/john/3"

    expect(page).to have_css(".chapter-body")
    expect(page).not_to have_css(".chapter-body.verse-blocks")

    find("[data-action='reader-prefs#toggleVerseBlocks']").click
    expect(page).to have_css(".chapter-body.verse-blocks")
    expect(page).to have_css("[data-action='reader-prefs#toggleVerseBlocks'][aria-pressed='true']")

    visit "/bible/kjv/john/3"
    expect(page).to have_css(".chapter-body.verse-blocks")

    find("[data-action='reader-prefs#toggleVerseBlocks']").click
    expect(page).not_to have_css(".chapter-body.verse-blocks")
  end
end
