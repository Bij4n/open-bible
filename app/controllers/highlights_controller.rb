class HighlightsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_highlight, only: %i[update destroy]

  # Sprint 16.5 PR D — surgical-stream verse rendering. Create / update /
  # destroy return turbo_streams that replace the affected verse partials
  # in place; the JS controller no longer Turbo.visits the page on
  # mutation. The toolbar persists across the response per hybrid-C, and
  # the broadcast layer (Highlight#after_create_commit etc) is untouched —
  # group bible streams continue to fire from the model independently.

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
    # Sprint 16.5 PR C — color-toggle removal. The "always attached"
    # note-vs-highlight invariant in the spec doesn't hold without
    # this cascade: dependent: :destroy on highlight.highlight_notes
    # only removes the join rows, leaving the note orphaned in the DB.
    # Eager-load :notes BEFORE destroy because the cascade clears
    # highlight_notes out from under us; without the to_a snapshot the
    # post-destroy reload would return zero. Wrapped in a transaction
    # so a note destroy failure rolls back the whole operation
    # (atomic delete-or-don't).
    #
    # Sprint 16.5 PR D — affected_verses snapshotted before destroy
    # too, so the turbo_stream response can re-render those verses in
    # the post-destroy state (highlight gone from data-highlight-ids,
    # data-note-count gone, classes adjusted by render_verse_with_
    # highlights).
    affected_verses_snapshot = @highlight.affected_verses.to_a
    ActiveRecord::Base.transaction do
      notes_to_check = @highlight.notes.to_a
      @highlight.destroy
      notes_to_check.each { |n| n.destroy if n.highlight_notes.reload.empty? }
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: verse_replace_streams(affected_verses_snapshot) }
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
    affected = highlight.affected_verses.to_a
    respond_to do |format|
      format.turbo_stream { render turbo_stream: verse_replace_streams(affected), status: status }
      format.html         { head status }
      format.json         { render json: highlight_payload(highlight), status: status }
    end
  end

  # Builds the array of <turbo-stream action="replace"> tags targeting
  # each affected verse's dom_id, rendering the bible/reader/verse
  # partial with the freshly-loaded chapter highlights set + cross-
  # translation map. Both create and destroy paths feed through here so
  # the rendered shape matches the initial reader-page render byte-for-
  # byte (data-highlight-ids, data-note-count, highlight-{color} class).
  def verse_replace_streams(verses)
    chapters = verses.map(&:chapter).uniq
    chapter_locals_cache = chapters.each_with_object({}) do |chapter, acc|
      prefix = "Bible.#{chapter.book.translation.code}.#{chapter.book.osis_code}.#{chapter.number}."
      cross_map = current_user.highlights.from_other_translations_in_chapter(
        translation_code: chapter.book.translation.code,
        book:             chapter.book.osis_code,
        chapter:          chapter.number
      ).each_with_object({}) do |h, m|
        h.affected_verses.each { |v| m[v.number] ||= h.translation.code }
      end
      acc[chapter.id] = {
        highlights: current_user.highlights.includes(:notes).for_chapter(prefix).to_a,
        cross_translation_highlights: cross_map
      }
    end

    verses.map do |verse|
      ctx = chapter_locals_cache[verse.chapter.id]
      turbo_stream.replace(
        ActionView::RecordIdentifier.dom_id(verse),
        partial: "bible/reader/verse",
        locals: {
          verse: verse,
          highlights: ctx[:highlights],
          cross_translation_highlights: ctx[:cross_translation_highlights],
          chapter_opener: false
        }
      )
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
