module Bible
  module ReaderHelper
    # Emit verse HTML with highlight overlays layered over red-letter
    # (jesus-words) spans. Character ranges are merged via an event-list
    # sweep: collect every range boundary, sort, emit one span per
    # fragment between consecutive boundaries with the classes that are
    # active at that fragment.
    #
    # Overlap rules:
    #   - Jesus-words is always applied when active (orthogonal to
    #     highlights). A highlight over red letters shows both.
    #   - When multiple highlights cover the same character, the
    #     highest-id (most recent) highlight's color wins; all touching
    #     highlight ids are listed in data-highlight-ids for click
    #     disambiguation.
    def render_verse_with_highlights(verse, highlights)
      text = verse.body_text.to_s
      return "".html_safe if text.empty?

      jesus_ranges     = Array(verse.red_letter_ranges)
      highlight_ranges = Array(highlights)
                         .filter_map { |h| verse_range_for(h, verse) }

      boundaries = Set.new([ 0, text.length ])
      jesus_ranges.each { |s, e| boundaries << s; boundaries << e }
      highlight_ranges.each { |r| boundaries << r[:start]; boundaries << r[:end] }
      sorted = boundaries.to_a.sort

      out = +""
      sorted.each_cons(2) do |from, to|
        next if from == to

        in_jesus = jesus_ranges.any? { |s, e| s <= from && from < e }
        active_highlights = highlight_ranges.select { |r| r[:start] <= from && from < r[:end] }

        fragment = ERB::Util.html_escape(text[from...to])

        if !in_jesus && active_highlights.empty?
          out << fragment
          next
        end

        classes = []
        classes << "jesus-words" if in_jesus

        if active_highlights.any?
          sorted_highlights = active_highlights.sort_by { |r| r[:id] }
          dominant = sorted_highlights.last
          classes << "highlight-#{dominant[:color]}"
          ids = sorted_highlights.map { |r| r[:id] }.join(",")
          # data-note-count is the dominant highlight's note count.
          # Drives the Sprint 16.5 PR C color-toggle removal flow:
          # 0 → instant remove on click, ≥1 → confirm dialog with
          # the count-aware bilingual message. The reader controller
          # eager-loads :notes on highlights so .size is in-memory.
          out << %(<span class="#{classes.join(" ")}" data-highlight-ids="#{ids}" data-note-count="#{dominant[:note_count]}">#{fragment}</span>)
        else
          out << %(<span class="#{classes.join(" ")}">#{fragment}</span>)
        end
      end

      out.html_safe
    end

    private

    # Projects a highlight's OsisRef onto a specific verse and returns
    # { id:, color:, start:, end: } in that verse's body_text coordinate
    # space. Returns nil when the highlight doesn't intersect this verse.
    def verse_range_for(highlight, verse)
      ref = highlight.parsed_ref
      return nil unless ref.start_chapter == verse.chapter.number
      return nil unless (ref.start_verse..ref.end_verse).cover?(verse.number)

      text_len = verse.body_text.to_s.length
      start_off = verse.number == ref.start_verse ? (ref.start_offset || 0) : 0
      end_off   = verse.number == ref.end_verse   ? resolve_end_offset(ref.end_offset, text_len) : text_len

      return nil if start_off >= end_off

      { id: highlight.id, color: highlight.color, start: start_off, end: end_off, note_count: highlight.notes.size }
    end

    def resolve_end_offset(offset, text_len)
      case offset
      when nil, OsisRef::END_OFFSET then text_len
      else offset.to_i
      end
    end
  end
end
