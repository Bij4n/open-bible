require "rails_helper"

RSpec.describe "Memberships", type: :request do
  let(:owner)   { create(:user) }
  let(:outsider) { create(:user, email: "friend@open-bible.test") }
  let(:group)   { create(:group, owner: owner) }

  describe "POST /groups/:group_id/memberships" do
    context "as the owner" do
      before { sign_in owner }

      it "adds an existing user by email" do
        expect {
          post "/groups/#{group.id}/memberships", params: { email: outsider.email }
        }.to change { group.members.include?(outsider) }.from(false).to(true)
        expect(response).to redirect_to(group_path(group))
      end

      it "rejects unknown emails" do
        post "/groups/#{group.id}/memberships", params: { email: "ghost@open-bible.test" }
        expect(response).to redirect_to(group_path(group))
        expect(flash[:alert]).to be_present
      end

      it "is idempotent on existing members" do
        create(:membership, user: outsider, group: group, role: :member)
        expect {
          post "/groups/#{group.id}/memberships", params: { email: outsider.email }
        }.not_to change(Membership, :count)
      end
    end

    context "as a non-owner member" do
      before do
        create(:membership, user: outsider, group: group, role: :member)
        sign_in outsider
      end

      it "404s" do
        post "/groups/#{group.id}/memberships", params: { email: "anyone@open-bible.test" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /groups/:group_id/memberships/:id" do
    let(:member) { create(:user) }
    let!(:membership) { create(:membership, user: member, group: group, role: :member) }

    it "lets the owner remove a member" do
      sign_in owner
      expect {
        delete "/groups/#{group.id}/memberships/#{membership.id}"
      }.to change { group.members.include?(member) }.from(true).to(false)
    end

    it "404s for non-owners trying to remove someone else" do
      third = create(:user)
      create(:membership, user: third, group: group, role: :member)
      sign_in third
      delete "/groups/#{group.id}/memberships/#{membership.id}"
      expect(response).to have_http_status(:not_found)
      expect(Membership.exists?(membership.id)).to be true
    end
  end
end
