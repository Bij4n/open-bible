require "rails_helper"

RSpec.describe "Groups", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe "GET /groups" do
    it "requires sign-in" do
      get "/groups"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "lists the user's groups" do
      sign_in user
      group = create(:group, owner: user, name: "My Study")
      not_mine = create(:group, owner: other_user, name: "Theirs")

      get "/groups"
      expect(response.body).to include("My Study")
      expect(response.body).not_to include("Theirs")
      _ = not_mine
    end
  end

  describe "POST /groups" do
    before { sign_in user }

    it "creates a group with the current user as owner" do
      expect {
        post "/groups", params: { group: { name: "Sunday Study", privacy: "invite_only" } }
      }.to change(Group, :count).by(1)
      group = Group.last
      expect(group.owner).to eq(user)
      expect(group.members).to include(user)
    end

    it "rejects blank name" do
      post "/groups", params: { group: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /groups/:id" do
    let(:group) { create(:group, owner: user) }

    it "requires membership" do
      sign_in other_user
      get "/groups/#{group.id}"
      expect(response).to have_http_status(:not_found)
    end

    it "shows the group to its owner" do
      sign_in user
      get "/groups/#{group.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(group.name)
    end

    it "shows the group to a member" do
      sign_in other_user
      create(:membership, user: other_user, group: group, role: :member)
      get "/groups/#{group.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /groups/:id" do
    let(:group) { create(:group, owner: user) }

    it "allows the owner to update" do
      sign_in user
      patch "/groups/#{group.id}", params: { group: { name: "Renamed" } }
      expect(group.reload.name).to eq("Renamed")
    end

    it "404s for non-owner members" do
      sign_in other_user
      create(:membership, user: other_user, group: group, role: :member)
      patch "/groups/#{group.id}", params: { group: { name: "Hostile" } }
      expect(response).to have_http_status(:not_found)
      expect(group.reload.name).not_to eq("Hostile")
    end
  end

  describe "DELETE /groups/:id" do
    let!(:group) { create(:group, owner: user) }

    it "allows the owner to destroy" do
      sign_in user
      expect {
        delete "/groups/#{group.id}"
      }.to change(Group, :count).by(-1)
    end

    it "404s for non-owners" do
      sign_in other_user
      create(:membership, user: other_user, group: group, role: :member)
      delete "/groups/#{group.id}"
      expect(response).to have_http_status(:not_found)
      expect(Group.exists?(group.id)).to be true
    end
  end

  describe "POST /groups/join" do
    let!(:group) { create(:group, :with_invitation_code, owner: other_user, invitation_code: "JOIN42") }

    before { sign_in user }

    it "adds the user as a member when the code matches" do
      expect {
        post "/groups/join", params: { invitation_code: "JOIN42" }
      }.to change { group.members.include?(user) }.from(false).to(true)
      expect(response).to redirect_to(group_path(group))
    end

    it "rejects unknown codes" do
      post "/groups/join", params: { invitation_code: "NOPE99" }
      expect(response).to redirect_to(groups_path)
      expect(flash[:alert]).to be_present
    end

    it "is idempotent when the user is already a member" do
      create(:membership, user: user, group: group, role: :member)
      expect {
        post "/groups/join", params: { invitation_code: "JOIN42" }
      }.not_to change(Membership, :count)
      expect(response).to redirect_to(group_path(group))
    end
  end

  describe "DELETE /groups/:id/leave" do
    let(:group) { create(:group, owner: other_user) }
    before do
      create(:membership, user: user, group: group, role: :member)
      sign_in user
    end

    it "removes the user's membership" do
      expect {
        delete "/groups/#{group.id}/leave"
      }.to change { group.members.include?(user) }.from(true).to(false)
    end

    it "blocks the last owner from leaving" do
      sign_out user
      sign_in other_user
      delete "/groups/#{group.id}/leave"
      expect(response).to redirect_to(group_path(group))
      expect(flash[:alert]).to be_present
      expect(group.members).to include(other_user)
    end
  end
end
