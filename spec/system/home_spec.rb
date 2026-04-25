require "rails_helper"

# The homepage is the front door — every CTA on it must land where it
# claims. This spec asserts the hero CTA, every feature-card link, and
# the bottom donate-CTA point at the URLs the copy promises. rack_test
# driver — page is plain HTML, no JS-driven surfaces in the homepage
# content itself.
RSpec.describe "Home page", type: :system do
  # Real translation/book/chapter/verse for the public reader so the
  # CTAs that land on /public/bible/kjv/gen/1 actually render rather
  # than 404-ing on a missing record.
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

  it "renders the new hero copy" do
    visit "/"

    expect(page).to have_css("h1", text: I18n.t("home.welcome"))
    expect(page).to have_content(I18n.t("home.subhead"))
    expect(page).to have_content(I18n.t("home.tertiary"))
  end

  it "renders the bottom Donate CTA when an active address exists" do
    BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l")
    visit "/"

    expect(page).to have_content(I18n.t("home.donate_cta.heading"))
    expect(page).to have_content(I18n.t("home.donate_cta.body"))
  end

  it "hides the bottom Donate CTA when no active address exists" do
    visit "/"

    expect(page).not_to have_content(I18n.t("home.donate_cta.heading"))
    expect(page).not_to have_css("[data-section='donate-cta']")
  end

  it "renders all 7 feature cards but not the cut hygiene-level features" do
    visit "/"

    expect(page).to have_content(I18n.t("home.features.highlights.title"))
    expect(page).to have_content(I18n.t("home.features.notes.title"))
    expect(page).to have_content(I18n.t("home.features.groups.title"))
    expect(page).to have_content(I18n.t("home.features.public.title"))
    expect(page).to have_content(I18n.t("home.features.bilingual.title"))
    expect(page).to have_content(I18n.t("home.features.keyword_search.title"))
    expect(page).to have_content(I18n.t("home.features.semantic_search.title"))

    # Semantic search is explicitly labelled (English) on the card —
    # RV1909 has no embeddings yet, so the parenthetical is the
    # honest claim. When the multilingual model swap ships in
    # Sprint 16+, drop the parenthetical.
    expect(page).to have_content("Semantic search (English)")

    # Hygiene-level expectations — dark mode + bilingual UI — are
    # NOT cards. They show up implicitly (the navbar already lets
    # you toggle theme + language), but they're not headline
    # features and they don't have natural destinations.
    expect(page).not_to have_content("Dark mode")
    expect(page).not_to have_content("Bilingual UI")
  end

  it "groups feature cards into 'For yourself' and 'With others' subgroups" do
    visit "/"

    # Each subgroup gets its own H3 — the grid splits at the heading.
    expect(page).to have_css("h3", text: I18n.t("home.features.for_yourself"))
    expect(page).to have_css("h3", text: I18n.t("home.features.with_others"))

    # "For yourself" group contains the personal-experience cards
    # (read, mark, find), "With others" contains the shared/relational
    # cards (groups, public, bilingual). Bilingual lands in "With
    # others" because of the heart-language framing in its body.
    within(:xpath, "//section//div[.//h3[contains(text(),'#{I18n.t('home.features.for_yourself')}')]]") do
      expect(page).to have_content(I18n.t("home.features.highlights.title"))
      expect(page).to have_content(I18n.t("home.features.notes.title"))
      expect(page).to have_content(I18n.t("home.features.keyword_search.title"))
      expect(page).to have_content(I18n.t("home.features.semantic_search.title"))
    end

    within(:xpath, "//section//div[.//h3[contains(text(),'#{I18n.t('home.features.with_others')}')]]") do
      expect(page).to have_content(I18n.t("home.features.groups.title"))
      expect(page).to have_content(I18n.t("home.features.public.title"))
      expect(page).to have_content(I18n.t("home.features.bilingual.title"))
    end
  end

  it "renders the softened public-notes card without specific archetype examples" do
    visit "/"

    # The earlier draft listed specific archetypes ("the widow who lost
    # her husband", "the kid finding their faith") that read as real-
    # user examples when they were hypothetical. v2 softens to a
    # generic frame ("someone whose life looks nothing like yours")
    # which keeps the testimony tone without manufacturing testimony.
    expect(page).to have_content("someone whose life looks nothing like yours")
    expect(page).not_to have_content("widow who lost her husband")
    expect(page).not_to have_content("kid finding their faith")
  end

  it "lands the hero CTA on the public reader" do
    visit "/"

    click_on I18n.t("home.cta_public_bible"), match: :first
    expect(page).to have_current_path("/public/bible/kjv/gen/1")
  end

  it "lands every feature-card link on its claimed destination" do
    expected_destinations = {
      "highlights"      => "/public/bible/kjv/gen/1",
      "notes"           => "/public/bible/kjv/gen/1",
      "groups"          => "/groups",
      "public"          => "/public/bible/kjv/gen/1",
      "bilingual"       => "/public/bible/rv1909/gen/1",
      "keyword_search"  => "/search",
      "semantic_search" => "/search"
    }

    expected_destinations.each do |key, path|
      visit "/"

      title = I18n.t("home.features.#{key}.title")
      link = find_link(title)
      expect(link[:href]).to eq(path), "expected feature card '#{title}' to link to #{path}, was #{link[:href]}"
    end
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

    # v2 hides the footer "Donate" link on the homepage specifically
    # — the bottom donate-CTA card is the homepage's pitch, and
    # stacking the muted footer link below it reads as redundancy.
    # Footer link stays visible on every other page.
    it "hides the footer Donate link on the homepage even with an active address" do
      visit "/"

      expect(page).not_to have_css("footer a", text: I18n.t("layout.donate_link"))
    end

    it "still shows the footer Donate link on a non-homepage surface" do
      visit "/public/bible/kjv/gen/1"

      within("footer") do
        expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
      end
    end
  end
end
