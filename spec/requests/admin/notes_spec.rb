require "rails_helper"

RSpec.describe "Admin::Notes", type: :request do
  let(:admin)  { create(:user, admin: true) }
  let(:member) { create(:user) }
  let(:author) { create(:user) }
  let!(:note)  { create(:note, user: author, visibility: :public_note) }

  describe "GET /admin/notes" do
    it "requires sign-in" do
      get "/admin/notes"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s for non-admin members" do
      sign_in member
      get "/admin/notes"
      expect(response).to have_http_status(:not_found)
    end

    it "renders for admins" do
      sign_in admin
      get "/admin/notes"
      expect(response).to have_http_status(:ok)
    end

    it "filters to flagged when filter=flagged" do
      author2 = create(:user)
      flagged = create(:note, user: author2, body: "<p>THIS ONE IS FLAGGED</p>", visibility: :public_note)
      create(:flag, user: member, flaggable: flagged)
      create(:note, user: author2, body: "<p>UNFLAGGED NOTE BODY</p>", visibility: :public_note)

      sign_in admin
      get "/admin/notes", params: { filter: "flagged" }
      expect(response.body).to include("THIS ONE IS FLAGGED")
      expect(response.body).not_to include("UNFLAGGED NOTE BODY")
    end
  end

  describe "PATCH /admin/notes/:id/feature" do
    it "features a note and stamps featured_by" do
      sign_in admin
      patch "/admin/notes/#{note.id}/feature"
      expect(note.reload.featured).to be true
      expect(note.featured_by).to eq(admin)
    end

    it "404s for non-admins" do
      sign_in member
      patch "/admin/notes/#{note.id}/feature"
      expect(response).to have_http_status(:not_found)
      expect(note.reload.featured).to be false
    end
  end

  describe "PATCH /admin/notes/:id/unfeature" do
    it "unfeatures and clears stamps" do
      note.update!(featured: true, featured_at: Time.current, featured_by: admin)
      sign_in admin
      patch "/admin/notes/#{note.id}/unfeature"
      expect(note.reload.featured).to be false
      expect(note.featured_by).to be_nil
    end
  end

  describe "PATCH /admin/notes/:id/hide" do
    it "hides a note" do
      sign_in admin
      patch "/admin/notes/#{note.id}/hide"
      expect(note.reload.hidden_at).to be_present
      expect(note.hidden_by).to eq(admin)
    end

    it "404s for non-admins" do
      sign_in member
      patch "/admin/notes/#{note.id}/hide"
      expect(response).to have_http_status(:not_found)
      expect(note.reload.hidden_at).to be_nil
    end
  end

  describe "PATCH /admin/notes/:id/unhide" do
    it "unhides a note" do
      note.update!(hidden_at: Time.current, hidden_by: admin)
      sign_in admin
      patch "/admin/notes/#{note.id}/unhide"
      expect(note.reload.hidden_at).to be_nil
      expect(note.hidden_by).to be_nil
    end
  end
end
