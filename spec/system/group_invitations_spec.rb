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

  # Run deliver_later inline so the mailer fires synchronously during
  # the spec — avoids pulling in ActiveJob::TestHelper just for one
  # perform_enqueued_jobs call.
  around do |example|
    prior = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    ActionMailer::Base.deliveries.clear
    example.run
    ActiveJob::Base.queue_adapter = prior
  end

  it "owner sends an invitation, recipient signs up + auto-joins on click" do
    sign_in owner
    visit group_path(group)

    fill_in "group_invitation_email", with: "friend@example.com"
    click_on I18n.t("group_invitations.invite_button")

    expect(page).to have_content("Invitation sent to friend@example.com")
    expect(page).to have_content("friend@example.com") # appears in pending list

    mail = ActionMailer::Base.deliveries.last
    expect(mail).to be_present
    expect(mail.to).to eq([ "friend@example.com" ])

    body = mail.html_part&.body&.to_s.to_s + mail.text_part&.body&.to_s.to_s
    accept_url = body[%r{/group_invitations/[A-Za-z0-9_\-=]+}]
    expect(accept_url).to be_present, "expected accept URL in mail body, got:\n#{body[0..400]}"

    open_account_menu
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
