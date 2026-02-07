require "rails_helper"

RSpec.describe "Groups::Bible", type: :request do
  let(:owner)     { create(:user) }
  let(:member)    { create(:user) }
  let(:outsider)  { create(:user) }
  let!(:translation) { create(:translation, :kjv) }
  let(:book)      { create(:book, :john, translation: translation) }
  let!(:chapter)  { create(:chapter, book: book, number: 3) }
  let!(:verse16)  do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let(:group) { create(:group, owner: owner) }

  before { create(:membership, user: member, group: group, role: :member) }

  describe "GET /groups/:group_id/bible/:translation/:book/:chapter" do
    it "requires sign-in" do
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "404s for non-members" do
      sign_in outsider
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response).to have_http_status(:not_found)
    end

    it "renders for owner" do
      sign_in owner
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("For God so loved the world")
    end

    it "subscribes the page to the group bible cable channel" do
      sign_in owner
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response.body).to include(%(channel="GroupBibleChannel"))
      expect(response.body).to match(%r{<turbo-cable-stream-source[^>]*signed-stream-name})
    end

    it "renders for member with breadcrumb" do
      sign_in member
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(group.name)
    end

    it "shows notes shared with the group, attributed to their author" do
      highlight = create(:highlight, user: owner, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16",
                                     color: "gold")
      note = create(:note, user: owner, body: "<p>A thought</p>", visibility: :shared_groups)
      create(:highlight_note, highlight: highlight, note: note)
      create(:note_share, note: note, shareable: group)

      owner.update!(display_name: "Apollos")

      sign_in member
      get "/groups/#{group.id}/bible/kjv/john/3"

      expect(response.body).to include("A thought")
      expect(response.body).to include("Apollos")
      expect(response.body).to include("span class=\"highlight-gold\"")
    end

    it "doesn't show notes shared only with other groups" do
      other = create(:group, owner: outsider)
      highlight = create(:highlight, user: outsider, translation: translation,
                                     osis_ref: "Bible.KJV.John.3.16",
                                     color: "sage")
      note = create(:note, user: outsider, body: "<p>Private thought</p>", visibility: :shared_groups)
      create(:highlight_note, highlight: highlight, note: note)
      create(:note_share, note: note, shareable: other)

      sign_in member
      get "/groups/#{group.id}/bible/kjv/john/3"
      expect(response.body).not_to include("Private thought")
    end
  end
end
