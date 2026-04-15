module Bible
  class ReaderController < ApplicationController
    # /bible -> the user's default translation if they've set one, else
    # KJV Genesis 1. Signed-out visitors fall through to the public
    # bible at the same default.
    def entry
      code = resolved_default_translation_code
      if user_signed_in?
        redirect_to bible_chapter_path(translation: code.downcase, book: "gen", chapter: 1)
      else
        redirect_to public_bible_chapter_path(translation: code.downcase, book: "gen", chapter: 1)
      end
    end

    def show
      canonical_translation = params[:translation].downcase
      canonical_book        = params[:book].downcase

      # /bible/... is the signed-in personal reader. Anonymous visitors
      # get sent to the public bible view so they land on something
      # populated (scripture + community notes) instead of an empty
      # reader that can't show their nonexistent highlights.
      unless user_signed_in?
        redirect_to public_bible_chapter_path(translation: canonical_translation,
                                              book: canonical_book,
                                              chapter: params[:chapter])
        return
      end

      if params[:translation] != canonical_translation || params[:book] != canonical_book
        redirect_to bible_chapter_path(translation: canonical_translation, book: canonical_book, chapter: params[:chapter]),
                    status: :moved_permanently
        return
      end

      @translation = Translation.where("lower(code) = ?", canonical_translation).first!
      @book        = @translation.books.where("lower(osis_code) = ?", canonical_book).first!
      @chapter     = @book.chapters.find_by!(number: params[:chapter].to_i)
      @verses      = @chapter.verses.order(:number)
      @highlights  = load_highlights_for_chapter
      @cross_translation_highlighted_verse_numbers = load_cross_translation_highlight_verse_numbers
    end

    private

    # Prefix LIKE against the indexed osis_ref column. Every highlight's
    # ref starts with "Bible.<TRANS>.<Book>.<Chapter>." by the
    # same-chapter constraint, so this catches every highlight that
    # touches the current chapter in one indexed query.
    def load_highlights_for_chapter
      return [] unless user_signed_in?

      prefix = "Bible.#{@translation.code}.#{@book.osis_code}.#{@chapter.number}."
      current_user.highlights.for_chapter(prefix).to_a
    end

    def resolved_default_translation_code
      user_signed_in? && current_user.default_translation&.code || "KJV"
    end

    # Returns the Set of verse numbers in the current chapter that have
    # at least one highlight from a different translation. Used by the
    # verse partial to render a bridge badge.
    def load_cross_translation_highlight_verse_numbers
      return Set.new unless user_signed_in?

      cross = current_user.highlights.from_other_translations_in_chapter(
        translation_code: @translation.code,
        book:             @book.osis_code,
        chapter:          @chapter.number
      )

      numbers = Set.new
      cross.each do |h|
        h.parsed_ref.verse_osis_refs.each do |ref|
          numbers << ref.split(".").last.to_i
        end
      rescue OsisRef::ParseError
        # Shouldn't happen — validators gate on parse — but a stale row
        # with a malformed ref shouldn't break the reader.
        next
      end
      numbers
    end
  end
end
