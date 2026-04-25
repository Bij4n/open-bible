require "rails_helper"

# /donate is a fully public flow — no sign-in needed. Two parts:
# rack_test for the static-render assertions (QR is in the DOM,
# unavailable state renders without an active address) and a single
# js: true context for the copy-to-clipboard Stimulus interaction,
# which can't be exercised under rack_test.
RSpec.describe "Public donate flow", type: :system do
  let(:address_string) { "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l" }

  describe "with an active address" do
    before { BitcoinAddress.rotate_to!(address: address_string) }

    it "renders the address, an inline-SVG QR, and the report form" do
      visit "/donate"

      expect(page).to have_content(I18n.t("donations.title"))
      expect(page).to have_content(address_string)

      # Inline SVG QR is in the DOM (not <img> or base64 data URL).
      expect(page).to have_css("svg", visible: :all)

      # Honeypot field is present but visually hidden.
      expect(page).to have_css('input[name="website"]', visible: :all)

      # Form action posts to /donate/confirm.
      expect(page).to have_css('form[action="/donate/confirm"]', visible: :all)
    end

    it "submits the form and lands on the thank-you page (rack_test happy path)" do
      visit "/donate"

      fill_in I18n.t("donations.email_label"), with: "rack_test@example.com"
      click_on I18n.t("donations.submit")

      expect(page).to have_current_path("/donate/thank_you")
      expect(page).to have_content(I18n.t("donations.thank_you.heading"))
      expect(DonationReport.last.email).to eq("rack_test@example.com")
    end
  end

  describe "without an active address" do
    it "renders the unavailable explainer instead of the QR / form" do
      visit "/donate"

      expect(page).to have_content(I18n.t("donations.unavailable.heading"))
      expect(page).not_to have_css("svg.qr, form[action='/donate/confirm']", visible: :all)
    end
  end

  describe "the copy button", js: true do
    before { BitcoinAddress.rotate_to!(address: address_string) }

    it "swaps to the copied label after a click" do
      visit "/donate"

      # The button starts with the localized "Copy" label.
      expect(page).to have_button(text: I18n.t("donations.copy"))

      # Click it. Browser permission prompts for clipboard are a real
      # thing under headless Firefox; the controller's catch-block
      # falls back to execCommand-copy so the visible label-swap
      # still happens regardless of clipboard API availability.
      find("[data-action='copy#copy']").click

      expect(page).to have_content(I18n.t("donations.copied"), wait: 2)
    end
  end
end
