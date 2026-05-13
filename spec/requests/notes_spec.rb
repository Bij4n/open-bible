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

      it "accepts a visibility from the form and falls back to private_note for unknown values" do
        post "/notes",
             params: { note: { body: "A thought", highlight_ids: [ highlight.id ], visibility: "shared_users" } }
        expect(Note.last.visibility).to eq("shared_users")

        post "/notes",
             params: { note: { body: "Another", highlight_ids: [ highlight.id ], visibility: "confetti" } }
        expect(Note.last.visibility).to eq("private_note")
      end

      it "creates shares for submitted user_ids and member-group_ids" do
        friend = create(:user)
        group = create(:group, owner: user)
        post "/notes",
             params: { note: { body: "Shared", highlight_ids: [ highlight.id ],
                               visibility: "shared_users",
                               user_ids: [ friend.id ],
                               group_ids: [ group.id ] } }
        note = Note.last
        expect(note.shared_users).to include(friend)
        expect(note.shared_groups).to include(group)
      end

      it "silently drops group_ids the user isn't a member of" do
        other_owner = create(:user)
        stranger_group = create(:group, owner: other_owner)
        post "/notes",
             params: { note: { body: "Attempt", highlight_ids: [ highlight.id ],
                               visibility: "shared_groups",
                               group_ids: [ stranger_group.id ] } }
        note = Note.last
        expect(note.shared_groups).not_to include(stranger_group)
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

    describe "Turbo Stream response" do
      let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

      before { sign_in user }

      it "returns a turbo-stream that replaces flash_container on success" do
        patch "/notes/#{note.id}",
              params: { note: { body: "Updated", visibility: "private_note" } },
              headers: turbo_headers

        expect(response.content_type).to include("turbo-stream")
        expect(response.body).to include('target="flash_container"')
        expect(response.body).to match(/Note saved/i)
      end

      it "includes a sharing count when sharing with users" do
        friend = create(:user)
        patch "/notes/#{note.id}",
              params: { note: { body: "Updated", visibility: "shared_users",
                                user_ids: [ friend.id ] } },
              headers: turbo_headers

        expect(response.body).to match(/Shared with 1 person/i)
      end

      it "includes a group count when sharing with groups" do
        group = create(:group, owner: user)
        patch "/notes/#{note.id}",
              params: { note: { body: "Updated", visibility: "shared_groups",
                                group_ids: [ group.id ] } },
              headers: turbo_headers

        expect(response.body).to match(/Shared with 1 group/i)
      end

      it "clears the note_panel frame" do
        patch "/notes/#{note.id}",
              params: { note: { body: "Updated", visibility: "private_note" } },
              headers: turbo_headers

        expect(response.body).to include('target="note_panel"')
      end
    end
  end

  describe "POST /notes — Turbo Stream response" do
    let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

    before { sign_in user }

    it "returns a turbo-stream flash on successful create" do
      post "/notes",
           params: { note: { body: "<p>A thought</p>", highlight_ids: [ highlight.id ],
                             visibility: "private_note" } },
           headers: turbo_headers

      expect(response.content_type).to include("turbo-stream")
      expect(response.body).to include('target="flash_container"')
      expect(response.body).to match(/Note saved/i)
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
