class UpvotesController < ApplicationController
  before_action :authenticate_user!

  # POST /upvotes — toggle-on via idempotent find_or_create. DELETE
  # /upvotes/:note_id — toggle-off via find_by + destroy. Both respond
  # with JSON { upvoted:, count: } so the Stimulus controller can
  # update the button state without parsing HTML.

  def create
    note = Note.visible_to(current_user).find_by(id: params[:note_id])
    return head :not_found unless note

    upvote = Upvote.find_or_create_by!(user: current_user, note: note)
    render json: payload(note, upvoted: true), status: upvote.previously_new_record? ? :created : :ok
  end

  def destroy
    note = Note.visible_to(current_user).find_by(id: params[:id])
    return head :not_found unless note

    Upvote.where(user: current_user, note: note).destroy_all
    render json: payload(note, upvoted: false), status: :ok
  end

  private

  def payload(note, upvoted:)
    { upvoted: upvoted, count: note.reload.upvote_count }
  end
end
