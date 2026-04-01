require "rails_helper"

RSpec.describe "Search", type: :system do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end

  it "finds a verse from the search page (anonymous visitor)" do
    visit "/search"
    fill_in "q", with: "loved"
    find("input[type='submit'][value='#{I18n.t('search.submit')}']").click

    expect(page).to have_content("John 3:16")
    expect(page).to have_content("loved")
  end

  it "surfaces a public note by author" do
    author = create(:user, display_name: "Apollos")
    create(:note, user: author, visibility: :public_note,
                  body: "<p>A reflection on grace and mercy.</p>")

    visit "/search?q=grace"
    expect(page).to have_content("Apollos")
    expect(page).to have_content(/grace/i)
  end

  it "filters to verses only" do
    author = create(:user, display_name: "Hiddenauthor")
    create(:note, user: author, visibility: :public_note,
                  body: "<p>love note content.</p>")

    visit "/search?q=love&scope=verses"
    expect(page).to have_content("John 3:16")
    expect(page).not_to have_content("Hiddenauthor")
  end

  it "shows the suggestions panel on an empty search page" do
    visit "/search"
    expect(page).to have_content(I18n.t("search.empty_hint"))
    expect(page).to have_link("love")
  end
end
