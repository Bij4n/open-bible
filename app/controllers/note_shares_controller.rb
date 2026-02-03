class NoteSharesController < ApplicationController
  before_action :authenticate_user!

  VALID_SHAREABLE_TYPES = %w[User Group].freeze

  def create
    note = current_user.notes.find(params.dig(:note_share, :note_id))

    share_params = params.require(:note_share).permit(:shareable_type, :shareable_id)
    unless VALID_SHAREABLE_TYPES.include?(share_params[:shareable_type])
      return head :unprocessable_content
    end

    share = note.note_shares.find_or_create_by!(
      shareable_type: share_params[:shareable_type],
      shareable_id:   share_params[:shareable_id]
    )
    respond_to do |format|
      format.turbo_stream { head :created }
      format.html         { redirect_back fallback_location: root_path }
      format.json         { render json: { id: share.id }, status: :created }
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  def destroy
    share = NoteShare.find(params[:id])
    # Only the note's author can unshare.
    unless share.note.user_id == current_user.id
      return head :not_found
    end

    share.destroy!
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html         { redirect_back fallback_location: root_path }
      format.json         { head :no_content }
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
