module Bible
  class ReaderController < ApplicationController
    def show
      canonical_translation = params[:translation].downcase
      canonical_book        = params[:book].downcase
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
  end
end
