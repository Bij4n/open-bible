class GroupInvitationMailer < ApplicationMailer
  # Sprint 23.2 — sends a tokenized join link to the invited email.
  # Locale: uses the inviter's ui_locale (default :en) since the
  # recipient may not have an account yet. The accept-via-token route
  # `/group_invitations/:token` is wired in Sprint 23.3.
  def invite(invitation)
    @invitation = invitation
    @group      = invitation.group
    @inviter    = invitation.invited_by
    @accept_url = group_invitation_url(invitation.token)
    @expires_in_days = ((invitation.expires_at - Time.current) / 1.day).round

    I18n.with_locale(@inviter.ui_locale.presence || I18n.default_locale) do
      mail(
        to: invitation.email,
        subject: t("group_invitation_mailer.invite.subject",
                   group_name: @group.name, inviter: @inviter.author_name)
      )
    end
  end
end
