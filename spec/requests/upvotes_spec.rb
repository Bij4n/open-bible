require "rails_helper"

RSpec.describe "Upvotes", type: :request do
  let(:voter)  { create(:user) }
  let(:author) { create(:user) }
  let(:note)   { create(:note, user: author, visibility: :public_note) }

  describe "POST /upvotes" do
    it "requires sign-in" do
      post "/upvotes", params: { note_id: note.id }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when signed in" do
      before { sign_in voter }

      it "creates an upvote on a visible note" do
        expect {
          post "/upvotes", params: { note_id: note.id }
        }.to change(Upvote, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include("upvoted" => true, "count" => 1)
      end

      it "is idempotent when already upvoted" do
        create(:upvote, user: voter, note: note)
        expect {
          post "/upvotes", params: { note_id: note.id }
        }.not_to change(Upvote, :count)
        expect(response.parsed_body).to include("upvoted" => true, "count" => 1)
      end

      it "404s when the note isn't visible to the voter" do
        private_note = create(:note, user: author, visibility: :private_note)
        post "/upvotes", params: { note_id: private_note.id }
        expect(response).to have_http_status(:not_found)
        expect(Upvote.count).to eq(0)
      end
    end
  end

  describe "DELETE /upvotes/:note_id" do
    before { sign_in voter }

    it "removes an existing upvote" do
      create(:upvote, user: voter, note: note)
      expect {
        delete "/upvotes/#{note.id}"
      }.to change(Upvote, :count).by(-1)
      expect(response.parsed_body).to include("upvoted" => false, "count" => 0)
    end

    it "is idempotent when no upvote exists" do
      expect {
        delete "/upvotes/#{note.id}"
      }.not_to change(Upvote, :count)
      expect(response.parsed_body).to include("upvoted" => false, "count" => 0)
    end
  end
end
