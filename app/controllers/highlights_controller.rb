class HighlightsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_highlight, only: %i[update destroy]

  # Create/update/destroy return minimal responses. The reader view
  # re-renders highlights server-side on navigation, so after a mutation
  # the Stimulus controller calls `Turbo.visit(window.location.href)` to
  # pick up the change. Could be refined to in-place Turbo Stream frames
  # later, but the full-chapter re-render via Turbo visit is cheap and
  # correct for Sprint 3.

  def create
    translation = resolve_translation(highlight_params[:osis_ref])
    return head :unprocessable_content unless translation

    highlight = current_user.highlights.build(highlight_params.merge(translation: translation))
    if highlight.save
      respond_with_highlight(highlight, status: :created)
    else
      respond_with_errors(highlight)
    end
  rescue ArgumentError
    # Rails enum raises on unknown values before hitting validation.
    head :unprocessable_content
  end

  def update
    if @highlight.update(update_params)
      respond_with_highlight(@highlight)
    else
      respond_with_errors(@highlight)
    end
  rescue ArgumentError
    head :unprocessable_content
  end

  def destroy
    @highlight.destroy
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html         { head :no_content }
      format.json         { head :no_content }
    end
  end

  private

  # Members-only ownership: look up through current_user.highlights so
  # other users' records 404 (doesn't leak existence via 403).
  def load_highlight
    @highlight = current_user.highlights.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def highlight_params
    params.require(:highlight).permit(:osis_ref, :color)
  end

  def update_params
    params.require(:highlight).permit(:color)
  end

  # The OsisRef carries the translation code; resolve to a DB record so
  # the client doesn't have to pass a redundant translation_id.
  def resolve_translation(osis_ref)
    ref = OsisRef.parse(osis_ref)
    Translation.find_by("lower(code) = ?", ref.translation_code.downcase)
  rescue OsisRef::ParseError
    nil
  end

  def respond_with_highlight(highlight, status: :ok)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: "", status: status }
      format.html         { head status }
      format.json         { render json: highlight_payload(highlight), status: status }
    end
  end

  def respond_with_errors(highlight)
    respond_to do |format|
      format.turbo_stream { head :unprocessable_content }
      format.html         { head :unprocessable_content }
      format.json         { render json: { errors: highlight.errors }, status: :unprocessable_content }
    end
  end

  def highlight_payload(highlight)
    { id: highlight.id, osis_ref: highlight.osis_ref, color: highlight.color }
  end
end
