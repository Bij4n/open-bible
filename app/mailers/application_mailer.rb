class ApplicationMailer < ActionMailer::Base
  # Resend is verified for the send.bible-together.org subdomain only;
  # changing this requires adding DNS records for whatever domain you
  # switch to. Devise uses config.mailer_sender in
  # config/initializers/devise.rb, which must match this value.
  default from: "noreply@send.bible-together.org"
  layout "mailer"
end
