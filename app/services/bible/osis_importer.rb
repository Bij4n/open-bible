require "nokogiri"
require "erb"

module Bible
  # Parses an OSIS XML file into Translation / Book / Chapter / Verse rows
  # using a Nokogiri SAX parser (DOM would blow up the heap on a 10 MB Bible).
  #
  # Supports both OSIS 2.1.1 dialects that show up in public-domain sources:
  #
  #   Milestone-style (seven1m/open-bibles Haiola flavor — KJV):
  #     <chapter sID="..."/>
  #       <verse sID="..."/>text<verse eID="..."/>
  #       <q who="Jesus" sID="..."/>red words<q eID="..."/>
  #     <chapter eID="..."/>
  #
  #   Container-style (gratis-bible ZefToOsis flavor — RV1909):
  #     <chapter osisID="Gen.1">
  #       <verse osisID="Gen.1.1">text</verse>
  #     </chapter>
  #
  # Red-letter tagging via <q who="Jesus"> is only honored in milestone
  # form; the container-style sources we support don't tag Jesus's words,
  # so RV1909 red letters come from Bible::RedLetterMirror instead.
  #
  # The importer is idempotent: re-running against the same source updates
  # existing rows keyed by osis_ref (Bible.<TRANS>.Book.Chapter.Verse).
  class OsisImporter
    BATCH_SIZE = 500

    def initialize(path:, translation_code:)
      @path = path
      @translation_code = translation_code
    end

    def call
      handler = Handler.new(translation_code: @translation_code)
      parser = Nokogiri::XML::SAX::Parser.new(handler)
      parser.parse_file(@path.to_s)
      handler.finalize
      handler.stats
    end

    class Handler < Nokogiri::XML::SAX::Document
      attr_reader :stats

      def initialize(translation_code:)
        @translation_code = translation_code
        @translation = Translation.find_by!(code: translation_code)
        @canonical_codes = Bible::CanonicalBooks.osis_codes.to_set

        @div_stack = []
        @current_book = nil
        @current_book_is_canonical = false
        @current_chapter = nil
        @current_verse = nil
        @in_note = false
        @jesus_open_sid = nil
        @jesus_open_offset = nil

        @verse_batch = []
        @chapter_verse_counts = Hash.new(0)
        @seen_books = Set.new
        @seen_chapters = Set.new
        @stats = { books: 0, chapters: 0, verses: 0, red_letter_ranges: 0 }
      end

      def start_element(name, attrs)
        a = attrs.to_h
        case name
        when "div"
          if a["type"] == "book"
            handle_book_start(a)
            @div_stack.push(:book)
          else
            @div_stack.push(:other)
          end
        when "chapter"
          if a["sID"]
            handle_chapter_start_milestone(a)
          elsif a["osisID"]
            handle_chapter_start_container(a)
          end
        when "verse"
          if a["sID"]
            handle_verse_start(a)
          elsif a["eID"]
            handle_verse_end(a)
          elsif a["osisID"]
            handle_verse_start_container(a)
          end
        when "q"
          if a["sID"] && a["who"] == "Jesus"
            handle_jesus_start(a)
          elsif a["eID"] && @jesus_open_sid == a["eID"]
            handle_jesus_end
          end
        when "note"
          @in_note = true
        end
      end

      def end_element(name)
        case name
        when "note"
          @in_note = false
        when "verse"
          # Only container-style verses close on end_element. Milestone
          # verses close on the separate <verse eID=.../> marker.
          handle_verse_end_container if @current_verse && @current_verse[:style] == :container
        when "chapter"
          # Container <chapter> close. Milestone chapters close on <chapter eID=.../>,
          # which arrives as a start_element (self-closing), not end_element.
          @current_chapter = nil if @current_chapter && @current_chapter_style == :container
        when "div"
          closing = @div_stack.pop
          if closing == :book
            @current_book = nil
            @current_book_is_canonical = false
            @current_chapter = nil
            @current_chapter_style = nil
          end
        end
      end

      def characters(text)
        return if @in_note
        return unless @current_book_is_canonical
        return unless @current_verse

        @current_verse[:buffer] << text
      end

      def finalize
        flush_batch
        persist_chapter_counts
      end

      private

      def handle_book_start(attrs)
        code = attrs["osisID"]
        if @canonical_codes.include?(code)
          meta = Bible::CanonicalBooks.find(code)
          @current_book = Book.find_or_create_by!(translation: @translation, osis_code: code) do |b|
            b.name_en   = meta[:name_en]
            b.name_es   = meta[:name_es]
            b.position  = meta[:position]
            b.testament = meta[:testament]
          end
          @current_book_is_canonical = true
          @stats[:books] += 1 if @seen_books.add?(code)
        else
          @current_book = nil
          @current_book_is_canonical = false
          Rails.logger.info("[OsisImporter] skipping non-canonical book #{code}")
        end
      end

      def handle_chapter_start_milestone(attrs)
        return unless @current_book_is_canonical

        number = attrs["n"].to_i
        @current_chapter = Chapter.find_or_create_by!(book: @current_book, number: number)
        @current_chapter_style = :milestone
        key = [ @current_book.id, number ]
        @stats[:chapters] += 1 if @seen_chapters.add?(key)
        @chapter_verse_counts[@current_chapter.id] = 0
      end

      def handle_chapter_start_container(attrs)
        return unless @current_book_is_canonical

        # Container <chapter osisID="Gen.1"> has no `n` attr; derive the
        # chapter number from the last dotted segment.
        number = attrs["osisID"].to_s.split(".").last.to_i
        @current_chapter = Chapter.find_or_create_by!(book: @current_book, number: number)
        @current_chapter_style = :container
        key = [ @current_book.id, number ]
        @stats[:chapters] += 1 if @seen_chapters.add?(key)
        @chapter_verse_counts[@current_chapter.id] = 0
      end

      def handle_verse_start(attrs)
        return unless @current_book_is_canonical

        @current_verse = {
          osis_id: attrs["osisID"],
          sID:     attrs["sID"],
          style:   :milestone,
          buffer:  String.new,
          raw_ranges: []
        }
        # Carry-over: if a Jesus span stayed open across the previous verse
        # boundary, start this verse already inside it.
        @jesus_open_offset = 0 if @jesus_open_sid
      end

      def handle_verse_start_container(attrs)
        return unless @current_book_is_canonical
        return unless @current_chapter

        @current_verse = {
          osis_id: attrs["osisID"],
          sID:     nil,
          style:   :container,
          buffer:  String.new,
          raw_ranges: []
        }
      end

      def handle_verse_end(attrs)
        return unless @current_verse
        return unless @current_verse[:sID] == attrs["eID"]

        if @jesus_open_sid
          push_raw_range(@jesus_open_offset, @current_verse[:buffer].length)
          # Keep @jesus_open_sid set; it closes in a later verse.
        end

        persist_verse(@current_verse)
        @current_verse = nil
        @jesus_open_offset = nil
      end

      def handle_verse_end_container
        persist_verse(@current_verse)
        @current_verse = nil
      end

      def handle_jesus_start(attrs)
        return unless @current_verse

        @jesus_open_sid = attrs["sID"]
        @jesus_open_offset = @current_verse[:buffer].length
      end

      def handle_jesus_end
        if @current_verse && @jesus_open_offset
          push_raw_range(@jesus_open_offset, @current_verse[:buffer].length)
        end
        @jesus_open_sid = nil
        @jesus_open_offset = nil
      end

      def push_raw_range(start_off, end_off)
        return if start_off >= end_off

        @current_verse[:raw_ranges] << [ start_off, end_off ]
      end

      def persist_verse(verse)
        _book_code, _chap, verse_num = verse[:osis_id].split(".")
        body_text, ranges = normalize_whitespace(verse[:buffer], verse[:raw_ranges])
        body_html = render_body_html(body_text, ranges)
        osis_ref  = canonical_osis_ref(verse[:osis_id])

        now = Time.current
        @verse_batch << {
          chapter_id:       @current_chapter.id,
          number:           verse_num.to_i,
          body_text:        body_text,
          body_html:        body_html,
          red_letter_ranges: ranges,
          osis_ref:         osis_ref,
          created_at:       now,
          updated_at:       now
        }
        @stats[:verses] += 1
        @stats[:red_letter_ranges] += ranges.size
        @chapter_verse_counts[@current_chapter.id] += 1

        flush_batch if @verse_batch.size >= BATCH_SIZE
      end

      def flush_batch
        return if @verse_batch.empty?

        Verse.upsert_all(@verse_batch, unique_by: :osis_ref)
        @verse_batch.clear
      end

      def persist_chapter_counts
        @chapter_verse_counts.each do |chapter_id, count|
          Chapter.where(id: chapter_id).update_all(verse_count: count)
        end
      end

      # Normalize source whitespace (collapse internal runs, strip leading +
      # trailing) and remap the raw char-offset ranges onto the normalized
      # buffer. The remap is the subtle part; see the spec for the contract.
      def normalize_whitespace(raw, raw_ranges)
        normalized = String.new
        # offset_map[i] == length of `normalized` after consuming raw[0..i-1].
        # Length is raw.length + 1 so we can remap end-positions past the last char.
        offset_map = [ 0 ]
        prev_space = true # drops leading whitespace

        raw.each_char do |c|
          if c.match?(/\s/)
            unless prev_space
              normalized << " "
              prev_space = true
            end
          else
            normalized << c
            prev_space = false
          end
          offset_map << normalized.length
        end

        normalized.rstrip!
        max = normalized.length
        offset_map.map! { |m| m > max ? max : m }

        new_ranges = raw_ranges.map { |s, e| [ offset_map[s], offset_map[e] ] }
                               .reject { |s, e| s >= e }
        [ normalized, new_ranges ]
      end

      def render_body_html(text, ranges)
        html = +""
        cursor = 0
        ranges.sort_by(&:first).each do |s, e|
          html << ERB::Util.html_escape(text[cursor...s]) if s > cursor
          html << %(<span class="jesus-words">)
          html << ERB::Util.html_escape(text[s...e])
          html << %(</span>)
          cursor = e
        end
        html << ERB::Util.html_escape(text[cursor..]) if cursor < text.length
        html
      end

      def canonical_osis_ref(source_osis_id)
        # Source uses bare form "John.3.16"; we store "Bible.KJV.John.3.16"
        # so Sprint 3's highlight anchors have a stable, fully-qualified ref.
        "Bible.#{@translation_code.upcase}.#{source_osis_id}"
      end
    end
  end
end
