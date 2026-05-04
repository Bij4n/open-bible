require "rails_helper"

RSpec.describe "GroupInvitations", type: :request do
  let(:owner) { create(:user, display_name: "Apollos") }
  let(:non_owner) { create(:user) }
  let(:group) { create(:group, owner: owner) }

  describe "POST /groups/:group_id/invitations" do
    context "as the group owner" do
      before { sign_in owner }

      it "creates a pending invitation and queues the mailer" do
        expect {
          post group_invitations_path(group), params: { group_invitation: { email: "friend@example.com" } }
        }.to change { group.group_invitations.pending.count }.by(1)
         .and change { ActionMailer::Base.deliveries.count }.by_at_least(0) # delivery is queued, may be sync
         .and have_enqueued_mail(GroupInvitationMailer, :invite)

        expect(response).to redirect_to(group_path(group))
        follow_redirect!
        expect(response.body).to include("Invitation sent to friend@example.com")
      end

      it "redirects with an alert when the email already belongs to a member" do
        already_in = create(:user, email: "already@example.com")
        group.memberships.create!(user: already_in, role: :member)

        expect {
          post group_invitations_path(group), params: { group_invitation: { email: "already@example.com" } }
        }.not_to change(GroupInvitation, :count)

        expect(response).to redirect_to(group_path(group))
        follow_redirect!
        expect(response.body).to include("already a member of this group")
      end

      it "redirects with the validation message on bad email" do
        post group_invitations_path(group), params: { group_invitation: { email: "not-an-email" } }
        expect(response).to redirect_to(group_path(group))
        follow_redirect!
        expect(response.body.downcase).to include("email")
      end

      it "rejects a duplicate pending invite" do
        create(:group_invitation, group: group, invited_by: owner, email: "friend@example.com")

        expect {
          post group_invitations_path(group), params: { group_invitation: { email: "friend@example.com" } }
        }.not_to change(GroupInvitation, :count)
      end
    end

    context "as a non-owner of the group" do
      before { sign_in non_owner }

      it "404s — owner-only action; existence of the route is not advertised" do
        post group_invitations_path(group), params: { group_invitation: { email: "friend@example.com" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "signed out" do
      it "redirects to the sign-in page" do
        post group_invitations_path(group), params: { group_invitation: { email: "friend@example.com" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /groups/:group_id/invitations/:id" do
    let!(:invitation) { create(:group_invitation, group: group, invited_by: owner, email: "friend@example.com") }

    context "as the group owner" do
      before { sign_in owner }

      it "destroys the invitation" do
        expect {
          delete group_invitation_path(group, invitation)
        }.to change(GroupInvitation, :count).by(-1)

        expect(response).to redirect_to(group_path(group))
        follow_redirect!
        expect(response.body).to include("Cancelled invitation to friend@example.com")
      end
    end

    context "as a non-owner" do
      before { sign_in non_owner }

      it "404s — does not destroy" do
        expect {
          delete group_invitation_path(group, invitation)
        }.not_to change(GroupInvitation, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /group_invitations/:token (accept-via-token)" do
    let(:invitation) { create(:group_invitation, group: group, invited_by: owner, email: "friend@example.com") }

    context "with a valid token, signed-in user" do
      let(:user) { create(:user) }
      before { sign_in user }

      it "accepts the invitation and redirects to the group bible reader" do
        translation = create(:translation, :kjv)
        create(:book, :genesis, translation: translation)

        expect {
          get accept_group_invitation_path(invitation.token)
        }.to change { group.memberships.where(user: user).count }.by(1)

        expect(invitation.reload).to be_accepted
        expect(response).to redirect_to(group_bible_chapter_path(group, translation: "kjv", book: "gen", chapter: 1))
      end
    end

    context "with a valid token, signed-out user" do
      it "stashes the show URL via Devise's stored_location and redirects to sign-in" do
        get accept_group_invitation_path(invitation.token)
        expect(response).to redirect_to(new_user_session_path)
        expect(session["user_return_to"]).to eq(accept_group_invitation_path(invitation.token))
      end
    end

    context "with an expired token" do
      let(:invitation) do
        create(:group_invitation, :expired, group: group, invited_by: owner, email: "friend@example.com")
      end

      it "renders the expired view with status 410 Gone" do
        sign_in create(:user)
        get accept_group_invitation_path(invitation.token)
        expect(response).to have_http_status(:gone)
        expect(response.body).to include("has expired")
      end
    end

    context "with an unknown token" do
      it "renders the expired view (we don't reveal whether the token ever existed)" do
        sign_in create(:user)
        get accept_group_invitation_path("not-a-real-token")
        expect(response).to have_http_status(:gone)
      end
    end

    context "with a token that's already accepted" do
      let(:invitation) do
        create(:group_invitation, :accepted, group: group, invited_by: owner, email: "friend@example.com")
      end

      it "redirects a signed-in user to the group" do
        translation = create(:translation, :kjv)
        create(:book, :genesis, translation: translation)
        sign_in create(:user)
        get accept_group_invitation_path(invitation.token)
        expect(response).to redirect_to(group_bible_chapter_path(group, translation: "kjv", book: "gen", chapter: 1))
      end
    end
  end
end
