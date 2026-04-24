require "rails_helper"

# Covers the send-reset-instructions half of the Devise password-reset
# flow. The edit/update half (user clicks the link, sets a new password)
# is exercised by Devise's own test suite and by the existing auth
# system specs; what's worth asserting at this repo level is that the
# delivery plumbing wired up in config/environments/production.rb
# actually fires a mail with a usable token — which it didn't before
# this sprint, because no SMTP provider was configured and Action
# Mailer silently dropped the delivery.
RSpec.describe "Devise password reset flow", type: :request do
  let!(:user) { create(:user, email: "scribe@open-bible.test") }

  it "delivers a reset-password email and stores a token on the user" do
    expect {
      post user_password_path, params: { user: { email: user.email } }
    }.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ user.email ])
    # Regression guard: Resend only accepts mail from the verified
    # send.bible-together.org subdomain. A placeholder here would
    # silently 550 in production the first time a real user submits
    # a reset. Devise's sender comes from config.mailer_sender in
    # config/initializers/devise.rb; ApplicationMailer#default from
    # must match.
    expect(mail.from).to eq([ "noreply@send.bible-together.org" ])
    expect(mail.subject).to match(/password|reset/i)

    body = [ mail.body, *mail.parts.map(&:body) ].map(&:to_s).join(" ")
    expect(body).to include("reset_password_token=")
    expect(user.reload.reset_password_token).to be_present
  end
end
