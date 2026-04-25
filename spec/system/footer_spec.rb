require "rails_helper"

# Site-wide footer chrome. Renders on every page including the
# homepage. Donate link inside the footer is gated on an active
# BitcoinAddress; everything else (wordmark, tagline, About,
# Settings when signed-in, attribution) renders unconditionally.
# rack_test driver — the footer is plain HTML, no JS-driven surfaces.
RSpec.describe "Footer", type: :system do
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

  describe "renders on every covered surface" do
    %w[/ /public/bible/kjv/gen/1 /donate /search].each do |path|
      it "renders the footer on #{path}" do
        visit path
        expect(page).to have_css("footer")
      end
    end
  end

  describe "branding" do
    it "renders the wordmark on the homepage" do
      visit "/"
      within("footer") do
        expect(page).to have_content(I18n.t("app.name"))
      end
    end

    # Tagline is hidden below the sm breakpoint via `hidden sm:block`
    # — at desktop widths it shows, at mobile widths it's display:none
    # but still in the DOM. rack_test doesn't honor responsive CSS,
    # so we assert the tagline element is present in the DOM
    # regardless of viewport.
    it "includes the tagline element in the DOM" do
      visit "/"
      within("footer") do
        expect(page).to have_content(I18n.t("layout.footer_tagline"), wait: 0)
      end
    end
  end

  describe "navigation links" do
    context "when an active BitcoinAddress exists" do
      before { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

      it "shows the Donate link in the footer on the homepage" do
        visit "/"
        within("footer") do
          expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
        end
      end

      it "shows the Donate link in the footer on a public reader page" do
        visit "/public/bible/kjv/gen/1"
        within("footer") do
          expect(page).to have_link(I18n.t("layout.donate_link"), href: "/donate")
        end
      end
    end

    context "when no active BitcoinAddress exists" do
      it "hides the Donate link but still renders the rest of the footer" do
        visit "/"

        within("footer") do
          expect(page).not_to have_link(I18n.t("layout.donate_link"))
          # Wordmark + About + attribution still render — the chrome
          # justifies itself even when donations are paused.
          expect(page).to have_content(I18n.t("app.name"))
          expect(page).to have_link(I18n.t("layout.about_link"))
        end
      end
    end

    it "links About to the homepage About anchor" do
      visit "/"
      within("footer") do
        link = find_link(I18n.t("layout.about_link"))
        expect(link[:href]).to end_with("#about")
      end
    end

    context "Settings link" do
      it "is hidden when signed out" do
        visit "/"
        within("footer") do
          expect(page).not_to have_link(I18n.t("auth.settings"))
        end
      end

      it "is visible when signed in" do
        sign_in create(:user)
        visit "/"
        within("footer") do
          expect(page).to have_link(I18n.t("auth.settings"), href: "/settings")
        end
      end
    end
  end

  describe "attribution" do
    it "renders the translations attribution and the meta line with current year" do
      visit "/"

      within("footer") do
        expect(page).to have_content(I18n.t("layout.footer_attribution_translations"))
        expect(page).to have_content(I18n.t("layout.footer_attribution_meta", year: Date.current.year))
        # Year is interpolated, so the literal current year shows up
        # in the rendered HTML — confirms the interpolation actually
        # ran rather than rendering "%{year}" as a literal string.
        expect(page).to have_content(Date.current.year.to_s)
      end
    end
  end
end
