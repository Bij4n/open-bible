require "rails_helper"

RSpec.describe "Admin::Flags", type: :request do
  let(:admin)  { create(:user, admin: true) }
  let(:member) { create(:user) }
  let!(:flag)  { create(:flag, user: member) }

  describe "GET /admin/flags" do
    it "requires admin" do
      get "/admin/flags"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s for non-admin members" do
      sign_in member
      get "/admin/flags"
      expect(response).to have_http_status(:not_found)
    end

    it "lists unresolved flags for admin" do
      sign_in admin
      get "/admin/flags"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(flag.reason)
    end

    it "hides already-resolved flags" do
      flag.update!(resolved_at: Time.current, resolved_by: admin)
      sign_in admin
      get "/admin/flags"
      expect(response.body).not_to include(flag.details) if flag.details.present?
    end
  end

  describe "PATCH /admin/flags/:id/resolve" do
    it "stamps resolved_at / resolved_by" do
      sign_in admin
      patch "/admin/flags/#{flag.id}/resolve"
      expect(flag.reload.resolved_at).to be_present
      expect(flag.resolved_by).to eq(admin)
    end

    it "404s for non-admins" do
      sign_in member
      patch "/admin/flags/#{flag.id}/resolve"
      expect(response).to have_http_status(:not_found)
      expect(flag.reload.resolved_at).to be_nil
    end
  end
end
