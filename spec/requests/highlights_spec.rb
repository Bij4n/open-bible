require "rails_helper"

RSpec.describe "Highlights", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let!(:translation) { create(:translation, :kjv) }

  describe "POST /highlights" do
    it "requires authentication" do
      post "/highlights", params: { highlight: { osis_ref: "Bible.KJV.John.3.16", color: "gold" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    context "when signed in" do
      before { sign_in user }

      it "creates a highlight and responds with turbo_stream" do
        expect {
          post "/highlights",
               params: { highlight: { osis_ref: "Bible.KJV.John.3.16", color: "gold" } },
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Highlight, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "infers the translation from the osis_ref" do
        post "/highlights",
             params: { highlight: { osis_ref: "Bible.KJV.John.3.16", color: "gold" } }
        expect(Highlight.last.translation).to eq(translation)
      end

      it "rejects malformed osis_ref" do
        post "/highlights",
             params: { highlight: { osis_ref: "not-a-ref", color: "gold" } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(Highlight.count).to eq(0)
      end

      it "rejects cross-chapter refs" do
        post "/highlights",
             params: { highlight: { osis_ref: "Bible.KJV.John.3.16-Bible.KJV.John.4.1", color: "gold" } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "rejects an unknown color" do
        post "/highlights",
             params: { highlight: { osis_ref: "Bible.KJV.John.3.16", color: "neon" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /highlights/:id" do
    let(:highlight) { create(:highlight, user: user, translation: translation) }

    it "requires authentication" do
      patch "/highlights/#{highlight.id}", params: { highlight: { color: "sage" } }
      expect(response).to redirect_to(new_user_session_path)
    end

    it "updates the color when signed in as owner" do
      sign_in user
      patch "/highlights/#{highlight.id}", params: { highlight: { color: "sage" } }
      expect(highlight.reload.color).to eq("sage")
    end

    it "404s when another user tries to update" do
      sign_in other_user
      patch "/highlights/#{highlight.id}", params: { highlight: { color: "sage" } }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /highlights/:id" do
    let!(:highlight) { create(:highlight, user: user, translation: translation) }

    it "destroys the highlight when signed in as owner" do
      sign_in user
      expect {
        delete "/highlights/#{highlight.id}"
      }.to change(Highlight, :count).by(-1)
    end

    it "404s when another user tries to delete" do
      sign_in other_user
      delete "/highlights/#{highlight.id}"
      expect(response).to have_http_status(:not_found)
      expect(Highlight.exists?(highlight.id)).to be true
    end

    # Sprint 16.5 PR C — orphan-note cascade. The "always attached"
    # spec invariant doesn't hold without server-side cleanup:
    # dependent: :destroy on highlight.highlight_notes only removes
    # the join rows, leaving the note orphaned. Q1 Option A:
    # auto-destroy the orphan in the same transaction as the
    # highlight destroy (the user-facing confirm dialog is the gate;
    # the server is the executor).
    describe "orphan-note cascade" do
      it "destroys an attached note when the last highlight referencing it is deleted" do
        sign_in user
        note = create(:note, user: user, body: "anchored")
        create(:highlight_note, highlight: highlight, note: note)
        expect(Note.exists?(note.id)).to be true

        delete "/highlights/#{highlight.id}"

        expect(response).to have_http_status(:no_content)
        expect(Highlight.exists?(highlight.id)).to be false
        expect(Note.exists?(note.id)).to be false
      end

      it "preserves a note that's still attached to a different highlight" do
        sign_in user
        other_highlight = create(:highlight, user: user, translation: translation,
                                              osis_ref: "Bible.KJV.John.1.1!0-Bible.KJV.John.1.1!4",
                                              color: "rose")
        note = create(:note, user: user, body: "shared across two highlights")
        create(:highlight_note, highlight: highlight, note: note)
        create(:highlight_note, highlight: other_highlight, note: note)

        delete "/highlights/#{highlight.id}"

        expect(Highlight.exists?(highlight.id)).to be false
        expect(Highlight.exists?(other_highlight.id)).to be true
        # Note still has a join row pointing at other_highlight; not orphaned.
        expect(Note.exists?(note.id)).to be true
      end
    end
  end
end
