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

    # The wordmark mark is the brand glyph — a mint disc with two
    # concentric outline rings rendered via CSS on a decorative span
    # next to the wordmark text. aria-hidden so screen readers skip
    # it; the wordmark text carries the brand identity for AT users.
    it "renders the wordmark mark glyph next to the wordmark text" do
      visit "/"
      within("footer") do
        expect(page).to have_css("span.wordmark-mark[aria-hidden='true']")
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

    it "links How it works to /how-it-works" do
      visit "/"
      within("footer") do
        link = find_link(I18n.t("layout.how_it_works_link"))
        expect(link[:href]).to end_with("/how-it-works")
      end
    end

    it "links About to the canonical /about page" do
      visit "/"
      within("footer") do
        link = find_link(I18n.t("layout.about_link"))
        expect(link[:href]).to end_with("/about")
      end
    end

    # Active-state is the "you are here" cue: links pointing at the
    # current route render in mint accent instead of the idle surface
    # tone. About now points at /about (canonical page) so the
    # nav_active? helper can mark it active when on /about, just like
    # Donate + Settings.
    describe "active-state styling" do
      before { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

      it "marks the Donate link active when on /donate" do
        visit "/donate"
        within("footer") do
          link = find_link(I18n.t("layout.donate_link"))
          expect(link[:class]).to include("decoration-accent-700/40")
        end
      end

      it "does not mark the Donate link active on /" do
        visit "/"
        within("footer") do
          link = find_link(I18n.t("layout.donate_link"))
          expect(link[:class]).not_to include("decoration-accent-700/40")
        end
      end

      it "marks the How it works link active when on /how-it-works" do
        visit "/how-it-works"
        within("footer") do
          link = find_link(I18n.t("layout.how_it_works_link"))
          expect(link[:class]).to include("decoration-accent-700/40")
        end
      end

      it "does not mark the About link active on /" do
        visit "/"
        within("footer") do
          link = find_link(I18n.t("layout.about_link"))
          expect(link[:class]).not_to include("decoration-accent-700/40")
        end
      end

      it "marks the About link active when on /about" do
        visit "/about"
        within("footer") do
          link = find_link(I18n.t("layout.about_link"))
          expect(link[:class]).to include("decoration-accent-700/40")
        end
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

  describe "language toggle" do
    it "renders EN and ES buttons in the footer" do
      visit "/"
      within("footer") do
        expect(page).to have_content("EN")
        expect(page).to have_content("ES")
      end
    end

    it "marks the active locale" do
      visit "/"
      within("footer") do
        # EN is active by default — it carries aria-current="true"
        expect(page).to have_css("[aria-current='true']", text: "EN")
        expect(page).not_to have_css("[aria-current='true']", text: "ES")
      end
    end
  end
end
