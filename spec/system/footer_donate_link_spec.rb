require "rails_helper"

# Site-wide footer donate link, gated on the existence of an active
# BitcoinAddress. rack_test driver — the link is plain HTML, no JS in
# the surface. Two pages cover the "global means global" contract:
# the homepage (no controller setup needed) and a public reader page
# (different layout context, different data setup).
RSpec.describe "Footer donate link", type: :system do
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

  context "when an active BitcoinAddress exists" do
    before { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

    it "shows the donate link in the footer on the home page" do
      visit "/"

      within("footer") do
        expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
      end
    end

    it "shows the donate link in the footer on a public reader page" do
      visit "/public/bible/kjv/gen/1"

      within("footer") do
        expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
      end
    end

    it "shows the donate link on the donate page itself (global means global)" do
      visit "/donate"

      within("footer") do
        expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
      end
    end
  end

  context "when no active BitcoinAddress exists" do
    it "does not render the footer at all on the home page" do
      visit "/"

      expect(page).not_to have_css("footer")
      expect(page).not_to have_link(I18n.t("layout.donate_link"))
    end

    it "does not render the footer on the public reader page" do
      visit "/public/bible/kjv/gen/1"

      expect(page).not_to have_css("footer")
    end
  end
end
