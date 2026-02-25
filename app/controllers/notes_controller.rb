class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_note, only: %i[show update destroy]

  def show
    respond_to do |format|
      format.html         { render :show }
      format.turbo_stream { render :show }
    end
  end

  def create
    highlight_ids = Array(params.dig(:note, :highlight_ids)).map(&:to_i).reject(&:zero?)

    # Scope highlight lookup to the current user so cross-user references
    # 404 instead of silently attaching a note to someone else's record.
    highlights = current_user.highlights.where(id: highlight_ids)
    if highlights.size != highlight_ids.size
      return head :not_found
    end

    note = current_user.notes.build(note_params)
    note.visibility = :private_note # Sprint 3 scope — other values stubbed

    if note.save
      highlights.each { |h| note.highlight_notes.create!(highlight: h) }
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :created }
        format.html         { head :created }
        format.json         { render json: note_payload(note), status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :unprocessable_content }
        format.html         { head :unprocessable_content }
        format.json         { render json: { errors: note.errors }, status: :unprocessable_content }
      end
    end
  end

  def update
    if @note.update(note_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :ok }
        format.html         { head :ok }
        format.json         { render json: note_payload(@note) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: "", status: :unprocessable_content }
        format.html         { head :unprocessable_content }
        format.json         { render json: { errors: @note.errors }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @note.destroy
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html         { head :no_content }
      format.json         { head :no_content }
    end
  end

  private

  def load_note
    @note = current_user.notes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def note_params
    # Visibility is stripped in Sprint 3 — always private. Sprint 4 will
    # move this into permit once sharing UX lands.
    params.require(:note).permit(:body)
  end

  def note_payload(note)
    { id: note.id, body: note.body.to_s, visibility: note.visibility }
  end
end
