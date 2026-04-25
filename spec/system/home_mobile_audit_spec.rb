require "rails_helper"

# Programmatic mobile-width audit. Renders the homepage at a 375px
# viewport (the long-time iPhone SE / "design floor" width) and asserts
# nothing horizontally overflows the body. Catches structural breakage
# — fixed-width tables, oversized images, untruncated long URLs — but
# does NOT replace human visual review on a real phone. Spec covers
# the structural contract; the aesthetic feel is still the human's
# job after each homepage-touching merge.
RSpec.describe "Home mobile audit", type: :system, js: true do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :genesis, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 1) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 1,
                   body_text: "In the beginning",
                   body_html: "In the beginning",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.Gen.1.1")
  end

  before do
    @original_window_size = page.driver.browser.manage.window.size
    page.driver.browser.manage.window.resize_to(375, 800)
  end

  after do
    page.driver.browser.manage.window.resize_to(@original_window_size.width, @original_window_size.height)
  end

  it "does not horizontally overflow at 375px width" do
    visit "/"

    # documentElement.scrollWidth is the total horizontal size of all
    # rendered content. clientWidth is the visible viewport. If
    # scrollWidth > clientWidth + small rounding margin, something is
    # bleeding past the right edge — the user has to side-scroll to
    # see it, which is the bug the spec catches.
    document_width = page.evaluate_script("document.documentElement.scrollWidth")
    viewport_width = page.evaluate_script("document.documentElement.clientWidth")
    expect(document_width).to be <= viewport_width + 1
  end
end
