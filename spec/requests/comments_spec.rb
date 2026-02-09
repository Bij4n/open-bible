require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:author)    { create(:user) }
  let(:commenter) { create(:user) }
  let(:outsider)  { create(:user) }

  describe "POST /comments" do
    it "requires sign-in" do
      note = create(:note, user: author)
      post "/comments", params: { comment: { note_id: note.id, body: "hi" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "on a note the user can see" do
      let(:note) { create(:note, user: author, visibility: :shared_users) }
      before do
        create(:note_share, note: note, shareable: commenter)
        sign_in commenter
      end

      it "creates a top-level comment" do
        expect {
          post "/comments", params: { comment: { note_id: note.id, body: "First" } }
        }.to change(Comment, :count).by(1)
        comment = Comment.last
        expect(comment.body).to eq("First")
        expect(comment.parent).to be_nil
        expect(comment.user).to eq(commenter)
      end

      it "creates a reply under its parent" do
        parent = create(:comment, note: note, user: author, body: "Parent")
        expect {
          post "/comments", params: { comment: { note_id: note.id, parent_id: parent.id, body: "Child" } }
        }.to change(Comment, :count).by(1)
        expect(Comment.last.parent).to eq(parent)
      end

      it "siblingizes replies beyond MAX_DEPTH" do
        d0 = create(:comment, note: note, user: author)
        d1 = create(:comment, note: note, user: author, parent: d0)
        d2 = create(:comment, note: note, user: author, parent: d1)
        d3 = create(:comment, note: note, user: author, parent: d2)

        post "/comments", params: { comment: { note_id: note.id, parent_id: d3.id, body: "Sibling" } }
        sibling = Comment.last
        expect(sibling.parent).to eq(d2)
        expect(sibling.depth).to eq(3)
      end

      it "rejects blank bodies" do
        expect {
          post "/comments", params: { comment: { note_id: note.id, body: "" } }
        }.not_to change(Comment, :count)
      end
    end

    it "404s when commenting on a note the user can't see" do
      note = create(:note, user: author, visibility: :private_note)
      sign_in outsider
      post "/comments", params: { comment: { note_id: note.id, body: "sneaky" } }
      expect(response).to have_http_status(:not_found)
      expect(Comment.count).to eq(0)
    end
  end

  describe "PATCH /comments/:id" do
    let(:note) { create(:note, user: author, visibility: :private_note) }
    let(:comment) { create(:comment, note: note, user: author, body: "Original") }

    it "lets the author edit" do
      sign_in author
      patch "/comments/#{comment.id}", params: { comment: { body: "Edited" } }
      expect(comment.reload.body).to eq("Edited")
    end

    it "404s for other users" do
      sign_in outsider
      patch "/comments/#{comment.id}", params: { comment: { body: "hijack" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /comments/:id" do
    let(:note) { create(:note, user: author, visibility: :private_note) }
    let!(:comment) { create(:comment, note: note, user: author) }

    it "lets the author delete" do
      sign_in author
      expect {
        delete "/comments/#{comment.id}"
      }.to change(Comment, :count).by(-1)
    end

    it "404s for other users" do
      sign_in outsider
      delete "/comments/#{comment.id}"
      expect(response).to have_http_status(:not_found)
      expect(Comment.exists?(comment.id)).to be true
    end
  end
end
