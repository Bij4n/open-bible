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
  end
end
