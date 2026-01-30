require "rails_helper"

RSpec.describe "Notes", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:highlight) { create(:highlight, user: user, translation: translation) }

  describe "POST /notes" do
    it "requires authentication" do
      post "/notes", params: { note: { body: "A thought", highlight_ids: [ highlight.id ] } }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when signed in" do
      before { sign_in user }

      it "creates a note and links it to the highlights" do
        expect {
          post "/notes", params: { note: { body: "<p>A thought</p>", highlight_ids: [ highlight.id ] } }
        }.to change(Note, :count).by(1).and change(HighlightNote, :count).by(1)

        note = Note.last
        expect(note.highlights).to include(highlight)
        expect(note.user).to eq(user)
        expect(note.visibility).to eq("private_note")
        expect(note.body.to_s).to include("A thought")
      end

      it "defaults visibility to private_note even if something else is submitted (Sprint 3 scope)" do
        post "/notes", params: { note: { body: "A thought", highlight_ids: [ highlight.id ], visibility: "public_note" } }
        expect(Note.last.visibility).to eq("private_note")
      end

      it "rejects creation when body is blank" do
        post "/notes", params: { note: { body: "", highlight_ids: [ highlight.id ] } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(Note.count).to eq(0)
      end

      it "rejects creation when highlight_ids reference another user's highlights" do
        other_highlight = create(:highlight, user: other_user, translation: translation, osis_ref: "Bible.KJV.John.3.17")
        expect {
          post "/notes", params: { note: { body: "A thought", highlight_ids: [ other_highlight.id ] } }
        }.not_to change(Note, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /notes/:id" do
    let(:note) { create(:note, user: user) }

    before { create(:highlight_note, highlight: highlight, note: note) }

    it "404s for anonymous visitors (private)" do
      get "/notes/#{note.id}"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows the note to its owner" do
      sign_in user
      get "/notes/#{note.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(note.body.to_s.strip)
    end

    it "404s for other users while the note is private" do
      sign_in other_user
      get "/notes/#{note.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /notes/:id" do
    let(:note) { create(:note, user: user) }

    it "updates the owner's note" do
      sign_in user
      patch "/notes/#{note.id}", params: { note: { body: "Refined" } }
      expect(note.reload.body.to_s).to include("Refined")
    end

    it "404s for other users" do
      sign_in other_user
      patch "/notes/#{note.id}", params: { note: { body: "hijack" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /notes/:id" do
    let!(:note) { create(:note, user: user) }

    it "destroys the owner's note" do
      sign_in user
      expect {
        delete "/notes/#{note.id}"
      }.to change(Note, :count).by(-1)
    end

    it "404s for other users" do
      sign_in other_user
      delete "/notes/#{note.id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
