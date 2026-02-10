module Bible
  # Loads the canonical 66-book reference from config/books.yml. This is the
  # whitelist the OSIS importer consults: any book not listed here is skipped,
  # which is how we drop the Apocrypha from KJV OSIS sources.
  module CanonicalBooks
    CONFIG_PATH = Rails.root.join("config", "books.yml")

    class << self
      def all
        @all ||= YAML.safe_load_file(CONFIG_PATH).map(&:symbolize_keys)
      end

      def find(osis_code)
        all.detect { |b| b[:osis_code] == osis_code }
      end

      def osis_codes
        @osis_codes ||= all.map { |b| b[:osis_code] }
      end

      def reset!
        @all = nil
        @osis_codes = nil
      end
    end
  end
end
