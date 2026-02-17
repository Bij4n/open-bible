require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  describe "GET /settings" do
    it "redirects anonymous users to sign in" do
      get "/settings"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders when signed in" do
      sign_in user
      get "/settings"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Language")
    end
  end

  describe "PATCH /settings" do
    before { sign_in user }

    it "updates ui_locale" do
      patch "/settings", params: { user: { ui_locale: "es" } }
      expect(response).to have_http_status(:ok)
      expect(user.reload.ui_locale).to eq("es")
    end

    it "updates theme" do
      patch "/settings", params: { user: { theme: "dark" } }
      expect(user.reload.theme).to eq("dark")
    end

    it "updates default_translation_id" do
      translation = create(:translation, :kjv)
      patch "/settings", params: { user: { default_translation_id: translation.id } }
      expect(user.reload.default_translation_id).to eq(translation.id)
    end

    it "updates display_name" do
      patch "/settings", params: { user: { display_name: "Scribe" } }
      expect(user.reload.display_name).to eq("Scribe")
    end

    it "rejects an invalid ui_locale" do
      original = user.ui_locale
      patch "/settings", params: { user: { ui_locale: "fr" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.ui_locale).to eq(original)
    end

    it "rejects an invalid theme" do
      original = user.theme
      patch "/settings", params: { user: { theme: "plaid" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.theme).to eq(original)
    end

    it "redirects anonymous users" do
      sign_out user
      patch "/settings", params: { user: { theme: "dark" } }
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
