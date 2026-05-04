require "rails_helper"

RSpec.describe GroupInvitationMailer, type: :mailer do
  let(:owner) { create(:user, display_name: "Apollos", ui_locale: "en") }
  let(:group) { create(:group, name: "Tuesday Study", description: "We meet on Tuesdays.", owner: owner) }
  let(:invitation) { create(:group_invitation, group: group, invited_by: owner, email: "friend@example.com") }

  describe "#invite (en)" do
    let(:mail) { described_class.invite(invitation) }

    it "sends to the invitation email" do
      expect(mail.to).to eq([ "friend@example.com" ])
    end

    it "uses the configured sender" do
      expect(mail.from).to include("noreply@send.bible-together.org")
    end

    it "subject names the inviter and group" do
      expect(mail.subject).to include("Apollos")
      expect(mail.subject).to include("Tuesday Study")
    end

    it "HTML body has the heading + accept link with the token" do
      html = mail.html_part.body.to_s
      expect(html).to include("Apollos")
      expect(html).to include("Tuesday Study").or include("with you")
      expect(html).to include("/group_invitations/#{invitation.token}")
      expect(html).to include("Accept the invitation")
    end

    it "plaintext body includes the accept URL" do
      text = mail.text_part.body.to_s
      expect(text).to include("/group_invitations/#{invitation.token}")
      expect(text).to include("Apollos")
    end

    it "includes the group description when present" do
      html = mail.html_part.body.to_s
      expect(html).to include("We meet on Tuesdays.")
    end

    it "renders an expiration line" do
      html = mail.html_part.body.to_s
      expect(html).to match(/expires in \d+ days/i)
    end
  end

  describe "#invite (es)" do
    before { owner.update!(ui_locale: "es") }
    let(:mail) { described_class.invite(invitation) }

    it "renders subject + body in Spanish per inviter's locale" do
      expect(mail.subject).to include("te invitó")
      html = mail.html_part.body.to_s
      expect(html).to include("Aceptar la invitación")
      expect(html).to include("contigo")
    end
  end

  describe "locale isolation" do
    it "doesn't change the global I18n.locale" do
      I18n.locale = :en
      owner.update!(ui_locale: "es")
      described_class.invite(invitation).deliver_now
      expect(I18n.locale).to eq(:en)
    end
  end
end
