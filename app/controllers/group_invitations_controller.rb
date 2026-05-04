class GroupInvitationsController < ApplicationController
  # Sprint 23.2 stub — wired so the route helper `group_invitation_url`
  # resolves for the GroupInvitationMailer. Sprint 23.3 fleshes out the
  # accept-via-token flow (sign-in-and-join, or sign-up-then-auto-join
  # via session-stashed token) plus #create / #destroy for the owner's
  # send-and-cancel actions.
  def show
    head :not_implemented
  end
end
