require "rails_helper"

# Sprint 23.4 — end-to-end email invitation flow. Owner sends an
# invite from the group page; recipient clicks the email link and
# joins. JS-tagged (Trix-free path is fine for these flows but we
# need ActionMailer + email-link clicks).
RSpec.describe "Group invitations — end-to-end", type: :system, js: true do
  let(:owner) { create(:user, display_name: "Apollos") }
  let(:group) { create(:group, name: "Tuesday Study", owner: owner) }
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :genesis, translation: translation) }

  before do
    ActionMailer::Base.deliveries.clear
  end

  it "owner sends an invitation, recipient signs up + auto-joins on click" do
    sign_in owner
    visit group_path(group)

    fill_in "group_invitation_email", with: "friend@example.com"
    click_on I18n.t("group_invitations.invite_button")

    expect(page).to have_content("Invitation sent to friend@example.com")
    expect(page).to have_content("friend@example.com") # appears in pending list
    perform_enqueued_jobs

    mail = ActionMailer::Base.deliveries.last
    expect(mail).to be_present
    expect(mail.to).to eq([ "friend@example.com" ])

    accept_url = mail.body.decoded[%r{/group_invitations/[A-Za-z0-9_-]+}]
    expect(accept_url).to be_present

    click_button "Sign out"
    visit accept_url

    # Signed-out → redirect to sign-in
    expect(page).to have_current_path(new_user_session_path)
    click_link "Sign up"

    fill_in "Email", with: "friend@example.com"
    fill_in "Password", with: "correct horse battery staple"
    fill_in "Password confirmation", with: "correct horse battery staple"
    find('input[type="submit"][value*="Sign up"]').click

    # Sign-up triggers Devise's stored_location → back to the accept URL,
    # which now sees a signed-in user and accepts the invitation.
    expect(page).to have_current_path(group_bible_chapter_path(group, translation: "kjv", book: "gen", chapter: 1))
    expect(group.reload.member?(User.find_by(email: "friend@example.com"))).to be(true)
  end

  it "owner cancels a pending invitation" do
    sign_in owner
    create(:group_invitation, group: group, invited_by: owner, email: "future@example.com")
    visit group_path(group)

    expect(page).to have_content("future@example.com")

    accept_confirm do
      within("li", text: "future@example.com") do
        click_button I18n.t("group_invitations.cancel")
      end
    end

    expect(page).to have_content("Cancelled invitation to future@example.com")
    expect(group.group_invitations.pending.count).to eq(0)
  end
end
