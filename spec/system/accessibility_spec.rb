require "rails_helper"
require "axe-rspec"

# Baselines the accessibility posture of every major surface. axe-core
# runs WCAG 2.1 AA rule checks against the rendered DOM under a real
# headless browser. Surfaces that fail here should either get fixed or
# have a documented, time-boxed exception.
RSpec.describe "Accessibility (WCAG 2.1 AA)", type: :system, js: true do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end

  it "home page is axe-clean" do
    visit "/"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end

  it "public bible reader is axe-clean" do
    visit "/public/bible/kjv/john/3"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end

  it "signed-in reader is axe-clean" do
    sign_in create(:user)
    visit "/bible/kjv/john/3"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end

  it "search page is axe-clean" do
    visit "/search"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end

  it "sign-in page is axe-clean" do
    visit "/users/sign_in"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end

  it "settings page is axe-clean" do
    sign_in create(:user)
    visit "/settings"
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa)
  end
end
