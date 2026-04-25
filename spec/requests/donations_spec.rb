require "rails_helper"

RSpec.describe "Donations", type: :request do
  describe "GET /donate" do
    context "with an active BitcoinAddress" do
      let!(:address) { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

      it "renders the address, a QR code, and the report form" do
        get "/donate"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(address.address)
        # Inline SVG QR is rendered, not a base64/png/external asset.
        expect(response.body).to match(%r{<svg[^>]*>}i)
        # Honeypot field is present and labelled with the canonical bot-bait name.
        expect(response.body).to include('name="website"')
        # Form posts to the confirmation endpoint.
        expect(response.body).to include('action="/donate/confirm"')
      end
    end

    context "without an active BitcoinAddress" do
      it "renders the unavailable explainer (200, not 404)" do
        get "/donate"

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to match(%r{<svg[^>]*class="[^"]*qr})
        # Explainer copy comes from the i18n key — assert via its English value.
        expect(response.body).to include(I18n.t("donations.unavailable.heading"))
      end
    end
  end

  describe "POST /donate/confirm" do
    context "with an active BitcoinAddress" do
      let!(:address) { BitcoinAddress.rotate_to!(address: "bc1qfzfen6peqgqmc03gj2jsu0zc96s49dwgahvu2l") }

      it "silently redirects without persisting when the honeypot is filled" do
        expect {
          post "/donate/confirm", params: {
            donation_report: { email: "real@example.com", message: "thanks" },
            website: "http://spammer.example/"
          }
        }.not_to change(DonationReport, :count)

        expect(response).to redirect_to("/donate/thank_you")
      end

      it "persists a DonationReport with email + message when the honeypot is empty" do
        expect {
          post "/donate/confirm", params: {
            donation_report: { email: "donor@example.com", message: "Glad to help" },
            website: ""
          }
        }.to change(DonationReport, :count).by(1)

        report = DonationReport.last
        expect(report.email).to eq("donor@example.com")
        expect(report.message).to eq("Glad to help")
        expect(response).to redirect_to("/donate/thank_you")
      end

      it "persists a DonationReport even when email and message are blank" do
        expect {
          post "/donate/confirm", params: {
            donation_report: { email: "", message: "" },
            website: ""
          }
        }.to change(DonationReport, :count).by(1)

        report = DonationReport.last
        expect(report.email).to be_blank
        expect(report.message).to be_blank
      end
    end

    context "without an active BitcoinAddress" do
      it "returns 404 (donation flow is gated on a current wallet)" do
        post "/donate/confirm", params: { donation_report: { email: "x@y.z" }, website: "" }

        expect(response).to have_http_status(:not_found)
        expect(DonationReport.count).to eq(0)
      end
    end
  end

  describe "GET /donate/thank_you" do
    it "renders the thank-you page" do
      get "/donate/thank_you"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("donations.thank_you.heading"))
    end
  end
end
