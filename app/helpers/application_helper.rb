module ApplicationHelper
  # True when the current request is on the given path. Used by the
  # header and footer nav to mark the link pointing at the current
  # route in mint accent — the "you are here" cue.
  #
  # `check_parameters: false` ignores query strings, so a route like
  # /search?q=love still matches /search. Hash fragments like /#about
  # are ignored by Rails' current_page? regardless, which is why this
  # helper deliberately is NOT used on the footer About link — that
  # link points at /#about, which would erroneously match `/` and mark
  # About active on the homepage. About stays unstyled-active.
  def nav_active?(path)
    current_page?(path, check_parameters: false)
  end

  # Human-readable citation for an OSIS ref string, e.g.:
  #   "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7" → "John 3:16"
  #   "Bible.KJV.John.3.16-Bible.KJV.John.3.17"     → "John 3:16–17"
  # Falls back to the raw string if the book can't be resolved.
  def osis_citation(osis_ref_string)
    ref = OsisRef.parse(osis_ref_string.to_s)
    start_book = Book.find_by(osis_code: ref.start_book)
    return osis_ref_string unless start_book

    name = I18n.locale == :es ? start_book.name_es : start_book.name_en

    if ref.same_chapter? && ref.start_verse == ref.end_verse
      "#{name} #{ref.start_chapter}:#{ref.start_verse}"
    elsif ref.same_chapter?
      "#{name} #{ref.start_chapter}:#{ref.start_verse}–#{ref.end_verse}"
    else
      end_book = Book.find_by(osis_code: ref.end_book)
      end_name = end_book ? (I18n.locale == :es ? end_book.name_es : end_book.name_en) : ref.end_book
      "#{name} #{ref.start_chapter}:#{ref.start_verse}–#{end_name} #{ref.end_chapter}:#{ref.end_verse}"
    end
  rescue OsisRef::ParseError
    osis_ref_string
  end
end
