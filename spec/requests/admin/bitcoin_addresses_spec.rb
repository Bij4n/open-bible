require "rails_helper"

RSpec.describe "Admin::BitcoinAddresses", type: :request do
  describe "non-admin access" do
    it "404s GET /admin/bitcoin_addresses for signed-out visitors" do
      get admin_bitcoin_addresses_path
      expect(response).to have_http_status(:not_found)
    end

    it "404s GET /admin/bitcoin_addresses for non-admin signed-in users" do
      sign_in create(:user)
      get admin_bitcoin_addresses_path
      expect(response).to have_http_status(:not_found)
    end

    it "404s POST /admin/bitcoin_addresses for non-admin signed-in users" do
      sign_in create(:user)
      post admin_bitcoin_addresses_path, params: { bitcoin_address: { address: "bc1qexampletestaddressforspecs0001" } }
      expect(response).to have_http_status(:not_found)
      expect(BitcoinAddress.count).to eq(0)
    end
  end

  describe "admin access" do
    let(:admin) { create(:user, admin: true) }
    before { sign_in admin }

    describe "GET /admin/bitcoin_addresses" do
      it "renders an empty state when no addresses exist" do
        get admin_bitcoin_addresses_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No addresses yet")
      end

      it "lists existing addresses with active first by recency" do
        old = create(:bitcoin_address, :archived, address: "bc1qarchivedoldaddressforspecs0001")
        active = create(:bitcoin_address, :active, address: "bc1qactivenewaddressforspecs00001")
        _ = old

        get admin_bitcoin_addresses_path
        expect(response.body).to include(active.address)
        expect(response.body).to include("Active")
      end
    end

    describe "GET /admin/bitcoin_addresses/new" do
      it "renders the new-address form" do
        get new_admin_bitcoin_address_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Bitcoin address")
        expect(response.body).to include(%(name="bitcoin_address[address]"))
      end
    end

    describe "POST /admin/bitcoin_addresses" do
      it "creates the new address as active and redirects" do
        expect {
          post admin_bitcoin_addresses_path, params: {
            bitcoin_address: { address: "bc1qfreshrotationtargetforspecs01", notes: "trezor / acct 0" }
          }
        }.to change { BitcoinAddress.count }.by(1)

        expect(response).to redirect_to(admin_bitcoin_addresses_path)
        expect(BitcoinAddress.current.address).to eq("bc1qfreshrotationtargetforspecs01")
        expect(BitcoinAddress.current.notes).to eq("trezor / acct 0")
      end

      it "archives the previous active address when a new one is created" do
        previous = create(:bitcoin_address, :active, address: "bc1qpreviousactivebeforerotation1")

        post admin_bitcoin_addresses_path, params: {
          bitcoin_address: { address: "bc1qfreshrotationtargetforspecs02" }
        }

        expect(previous.reload.active).to be false
        expect(previous.archived_at).to be_present
        expect(BitcoinAddress.current.address).to eq("bc1qfreshrotationtargetforspecs02")
      end

      it "re-renders the form with errors on validation failure and leaves the previous active alone" do
        previous = create(:bitcoin_address, :active, address: "bc1qpreviousactivebeforerotation2")

        post admin_bitcoin_addresses_path, params: {
          bitcoin_address: { address: "tooShort" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Address is too short")
        expect(previous.reload.active).to be true
        expect(previous.archived_at).to be_nil
      end
    end
  end
end
