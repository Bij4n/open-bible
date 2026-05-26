require "rails_helper"

# Homepage is now hero-only: verse card (or empty-state), community notes,
# and donate CTA. Features / how-it-works / about moved to /how-it-works.
RSpec.describe "Home page", type: :system do
  let!(:translation_kjv) { create(:translation, :kjv) }
  let!(:translation_rv1909) { create(:translation, :rv1909) }
  let!(:book_genesis_kjv) { create(:book, :genesis, translation: translation_kjv) }
  let!(:chapter_kjv)     { create(:chapter, book: book_genesis_kjv, number: 1) }
  let!(:verse_kjv) do
    create(:verse, chapter: chapter_kjv, number: 1,
                   body_text: "In the beginning",
                   body_html: "In the beginning",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.Gen.1.1")
  end
  let!(:book_genesis_rv) { create(:book, :genesis, translation: translation_rv1909) }
  let!(:chapter_rv)      { create(:chapter, book: book_genesis_rv, number: 1) }
  let!(:verse_rv) do
    create(:verse, chapter: chapter_rv, number: 1,
                   body_text: "En el principio",
                   body_html: "En el principio",
                   red_letter_ranges: [],
                   osis_ref: "Bible.RV1909.Gen.1.1")
  end

  it "shows the hero empty-state verse card when no featured note exists" do
    visit "/"
    expect(page).to have_css("[data-testid='hero-empty-state']")
    expect(page).to have_content(I18n.t("home.hero_empty_state.cta"))
    expect(page).to have_content("John 3")
  end

  it "renders the hero copy" do
    visit "/"

    expect(page).to have_css("h1", text: "Where verses meet voices.")
    expect(page).to have_content(I18n.t("home.subhead"))
    expect(page).to have_content(I18n.t("home.tertiary"))
  end

  it "does not render the features section or how-it-works section on the homepage" do
    visit "/"

    expect(page).not_to have_content(I18n.t("home.features.highlights.title"))
    expect(page).not_to have_content(I18n.t("home.how.step_1_body"))
    expect(page).not_to have_css("section#about")
  end

  it "links 'See how it works' to /how-it-works" do
    visit "/"

    link = find_link(I18n.t("home.cta_how_it_works"))
    expect(link[:href]).to eq("/how-it-works")
  end

  it "renders the bottom Donate CTA when an active address exists" do
    BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l")
    visit "/"

    expect(page).to have_content(I18n.t("home.donate_cta.heading"))
    expect(page).to have_content(I18n.t("home.donate_cta.body"))

    within("section[data-section='donate-cta']") do
      expect(page).to have_content("keep it open for whoever comes next")
      expect(page).not_to have_content("donations keep it open")
    end
  end

  it "hides the bottom Donate CTA when no active address exists" do
    visit "/"

    expect(page).not_to have_content(I18n.t("home.donate_cta.heading"))
    expect(page).not_to have_css("[data-section='donate-cta']")
  end

  it "lands the hero CTA on the public reader" do
    visit "/"

    click_on I18n.t("home.cta_public_bible"), match: :first
    expect(page).to have_current_path("/public/bible/kjv/gen/1")
  end

  it "lands the bottom donate-CTA button on /donate" do
    BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l")
    visit "/"

    within("section[data-section='donate-cta']") do
      click_on I18n.t("home.donate_cta.button")
    end
    expect(page).to have_current_path("/donate")
  end

  context "when an active BitcoinAddress exists" do
    before { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

    it "shows the footer Donate link on the homepage" do
      visit "/"

      within("footer") do
        expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
      end
    end
  end
end
