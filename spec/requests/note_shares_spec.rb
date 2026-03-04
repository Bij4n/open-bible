require "rails_helper"

RSpec.describe "NoteShares", type: :request do
  let(:author) { create(:user) }
  let(:friend) { create(:user) }
  let(:group)  { create(:group, owner: author) }
  let(:note)   { create(:note, user: author) }

  describe "POST /note_shares" do
    before { sign_in author }

    it "shares a note with a user" do
      expect {
        post "/note_shares", params: { note_share: { note_id: note.id, shareable_type: "User", shareable_id: friend.id } }
      }.to change(NoteShare, :count).by(1)
    end

    it "shares a note with a group" do
      expect {
        post "/note_shares", params: { note_share: { note_id: note.id, shareable_type: "Group", shareable_id: group.id } }
      }.to change(NoteShare, :count).by(1)
    end

    it "404s when the note belongs to another user" do
      other_note = create(:note, user: friend)
      post "/note_shares", params: { note_share: { note_id: other_note.id, shareable_type: "User", shareable_id: author.id } }
      expect(response).to have_http_status(:not_found)
      expect(NoteShare.count).to eq(0)
    end

    it "rejects invalid shareable_type" do
      post "/note_shares", params: { note_share: { note_id: note.id, shareable_type: "Book", shareable_id: 1 } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is idempotent on duplicates" do
      create(:note_share, note: note, shareable: friend)
      expect {
        post "/note_shares", params: { note_share: { note_id: note.id, shareable_type: "User", shareable_id: friend.id } }
      }.not_to change(NoteShare, :count)
    end
  end

  describe "DELETE /note_shares/:id" do
    let!(:share) { create(:note_share, note: note, shareable: friend) }

    it "lets the note author remove the share" do
      sign_in author
      expect {
        delete "/note_shares/#{share.id}"
      }.to change(NoteShare, :count).by(-1)
    end

    it "404s for other users" do
      sign_in friend
      delete "/note_shares/#{share.id}"
      expect(response).to have_http_status(:not_found)
      expect(NoteShare.exists?(share.id)).to be true
    end
  end
end
