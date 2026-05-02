module Public
  # The community-facing reader. Shows scripture + public notes
  # (with highlights from those notes rendered inline) to anyone,
  # signed-in or not. Admins additionally see hidden notes so they
  # can moderate from the same UI.
  class BibleController < ApplicationController
    def show
      canonical_translation = params[:translation].downcase
      canonical_book        = params[:book].downcase
      if params[:translation] != canonical_translation || params[:book] != canonical_book
        redirect_to public_bible_chapter_path(translation: canonical_translation,
                                              book: canonical_book,
                                              chapter: params[:chapter]),
                    status: :moved_permanently
        return
      end

      @translation = Translation.where("lower(code) = ?", canonical_translation).first!
      @book        = @translation.books.where("lower(osis_code) = ?", canonical_book).first!
      @chapter     = @book.chapters.find_by!(number: params[:chapter].to_i)
      @verses      = @chapter.verses.order(:number)

      prefix = "Bible.#{@translation.code}.#{@book.osis_code}.#{@chapter.number}."

      @public_notes = public_notes_for(prefix)
      @highlights   = highlights_for(@public_notes)
    end

    private

    def public_notes_for(prefix)
      scope = Note.public_visible
      scope = scope.or(Note.where(visibility: Note.visibilities[:public_note])) if current_user&.admin?
      scope
        .joins(:highlights)
        .where(highlights: { osis_ref: osis_refs_for(prefix) })
        .includes(:user, :highlights)
        .sorted_for_public
        .distinct
    end

    def highlights_for(notes)
      ids = notes.flat_map(&:highlights).map(&:id).uniq
      # includes(:notes) — render_verse_with_highlights reads
      # highlight.notes.size to emit data-note-count on the dominant
      # highlight span (Sprint 16.5 PR C). Same eager-load guard as
      # the signed-in reader so the renderer's contract is uniform.
      Highlight.where(id: ids).includes(:notes).to_a
    end

    def osis_refs_for(prefix)
      Verse
        .joins(chapter: :book)
        .where(books: { translation_id: @translation.id, osis_code: @book.osis_code },
               chapters: { number: @chapter.number })
        .pluck(:osis_ref)
    end
  end
end
