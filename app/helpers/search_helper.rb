module SearchHelper
  # Canonical citation for a verse — "John 3:16" in English or "Juan 3:16"
  # in Spanish. Reused by both verse and note result partials.
  def verse_citation(verse)
    book = verse.chapter.book
    name = I18n.locale == :es ? book.name_es : book.name_en
    "#{name} #{verse.chapter.number}:#{verse.number}"
  end

  # For the note result preview: take a plain-text slice of the Action
  # Text body and wrap every occurrence of each query term in <mark>.
  # Plain text + controlled escaping means we never slice through HTML
  # tags the way ts_headline can on a rich body.
  def highlight_terms(text, query, window: 180)
    return h(text.to_s.truncate(window)) if query.blank?

    terms = query.split(/\s+/).reject(&:blank?)
    slice = focus_window(text.to_s, terms, window)
    escaped = h(slice)
    terms.each do |term|
      escaped = escaped.gsub(/#{Regexp.escape(h(term))}/i) { |match| "<mark>#{match}</mark>" }
    end
    escaped.html_safe
  end

  # Returns the `window`-character slice of `text` centered around the
  # first occurrence of any query term, with "…" on either side when
  # truncated. Falls back to the leading chunk when no term matches.
  def focus_window(text, terms, window)
    return text.truncate(window) if terms.empty?

    idx = terms.filter_map { |t| text.downcase.index(t.downcase) }.min
    return text.truncate(window) unless idx

    half   = window / 2
    start  = [ idx - half, 0 ].max
    finish = [ start + window, text.length ].min
    leading  = start > 0 ? "…" : ""
    trailing = finish < text.length ? "…" : ""
    leading + text[start...finish] + trailing
  end
end
