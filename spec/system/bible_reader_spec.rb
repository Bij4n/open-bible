require "rails_helper"

RSpec.describe "Bible reader", type: :system, js: true do
  let(:translation) { create(:translation, :kjv) }
  let(:john)        { create(:book, :john, translation: translation) }
  let!(:john3)      { create(:chapter, book: john, number: 3) }
  let!(:john4)      { create(:chapter, book: john, number: 4) }
  let!(:john5)      { create(:chapter, book: john, number: 5) }

  before do
    create(:verse, chapter: john3, number: 16,
                   body_text: "For God so loved the world, that he gave his only begotten Son...",
                   body_html: %(<span class="jesus-words">For God so loved the world, that he gave his only begotten Son...</span>),
                   red_letter_ranges: [ [ 0, 65 ] ],
                   osis_ref: "Bible.KJV.John.3.16")
    create(:verse, chapter: john3, number: 17,
                   body_text: "For God sent not his Son into the world to condemn the world.",
                   body_html: "For God sent not his Son into the world to condemn the world.",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.17")
    create(:verse, chapter: john4, number: 1,
                   body_text: "When the Lord knew therefore...",
                   body_html: "When the Lord knew therefore...",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.4.1")
  end

  it "renders John 3:16 with Jesus's words styled red" do
    visit "/bible/kjv/john/3"
    expect(page).to have_content("For God so loved the world")
    expect(page).to have_css("span.jesus-words", text: "For God so loved the world")
  end

  it "renders verse numbers as superscripts" do
    visit "/bible/kjv/john/3"
    expect(page).to have_css("sup.verse-number", text: "16")
    expect(page).to have_css("sup.verse-number", text: "17")
  end

  it "navigates to the next chapter via the Next link" do
    visit "/bible/kjv/john/3"
    first("a", text: /next/i).click
    expect(page).to have_current_path("/bible/kjv/john/4")
    expect(page).to have_content("When the Lord knew therefore")
  end

  it "navigates to the previous chapter via the Previous link" do
    visit "/bible/kjv/john/4"
    first("a", text: /previous/i).click
    expect(page).to have_current_path("/bible/kjv/john/3")
  end

  it "jumps to a chapter via the picker dropdown" do
    visit "/bible/kjv/john/3"
    find("select[aria-label='Chapter']").find("option", text: "Chapter 5").select_option
    expect(page).to have_current_path("/bible/kjv/john/5")
  end
end
