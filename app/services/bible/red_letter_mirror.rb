module Bible
  # Copies "Jesus is speaking" red-letter information from a source
  # translation to a target translation that didn't ship with it
  # tagged. The gratis-bible sources we use for RV1909 don't encode
  # <q who="Jesus"> spans, so we need a post-import pass that maps
  # KJV's red-letter verses onto their RV1909 equivalents.
  #
  # Caveat: character offsets can't cross translations — "For God so
  # loved..." (108 chars) doesn't align with "Porque de tal manera
  # amó..." (150 chars). So we only transfer *fully red* verses,
  # i.e. where the source's ranges are a single [0, verse_length]
  # span indicating the whole verse is Jesus speaking. Partial red
  # verses (Jesus's words embedded mid-verse) are left empty in the
  # target — we'd be guessing where Spanish clauses split.
  #
  # This covers the practical cases: long Jesus discourses like
  # John 14-17 and the Sermon on the Mount are fully-red in KJV and
  # round-trip cleanly. Partial-red boundary verses lose their red
  # styling in RV1909; that's the price of the honest transfer.
  class RedLetterMirror
    DEFAULT_SOURCE = "KJV".freeze

    Result = Struct.new(:fully_red_verses, :updated, :skipped_missing, :skipped_partial,
                        keyword_init: true) do
      def to_s
        "mirrored #{updated}/#{fully_red_verses} fully-red verses " \
        "(skipped #{skipped_partial} partial, #{skipped_missing} missing)"
      end
    end

    def self.call(target_translation_code:, source_translation_code: DEFAULT_SOURCE)
      new(source: source_translation_code, target: target_translation_code).call
    end

    def initialize(source:, target:)
      @source = Translation.find_by!(code: source.to_s.upcase)
      @target = Translation.find_by!(code: target.to_s.upcase)
    end

    def call
      fully_red   = 0
      updated     = 0
      missing     = 0
      partial     = 0

      source_verses.find_each do |src|
        if fully_red?(src)
          fully_red += 1
          dst = find_target(src)
          if dst.nil?
            missing += 1
          else
            dst.update_columns(red_letter_ranges: [ [ 0, dst.body_text.length ] ])
            updated += 1
          end
        elsif src.red_letter_ranges.any?
          partial += 1
        end
      end

      Result.new(fully_red_verses: fully_red, updated: updated,
                 skipped_missing: missing, skipped_partial: partial)
    end

    private

    # Verses from the source translation with at least one red-letter
    # range. jsonb '!=' comparison against the empty-array default
    # leverages the column NOT NULL default and is index-friendly.
    def source_verses
      Verse.joins(chapter: :book)
           .where(books: { translation_id: @source.id })
           .where("red_letter_ranges::text <> '[]'")
    end

    def fully_red?(src)
      ranges = src.red_letter_ranges
      ranges.size == 1 && ranges.first == [ 0, src.body_text.length ]
    end

    # Strip the source's translation prefix from the osis_ref and
    # reattach the target's prefix. Bible.KJV.John.3.16 -> Bible.RV1909.John.3.16.
    def find_target(src)
      dotted = src.osis_ref.sub(/\ABible\.#{Regexp.escape(@source.code)}\./, "Bible.#{@target.code}.")
      Verse.find_by(osis_ref: dotted)
    end
  end
end
