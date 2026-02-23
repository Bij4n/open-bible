require "digest"
require "fileutils"
require "open-uri"
require "uri"
require "yaml"

# Downloads OSIS sources listed in config/bible_sources.yml, verifies their
# SHA256, unzips if needed, and runs Bible::OsisImporter. Downloads land
# under tmp/bible_sources (gitignored); re-runs reuse the cached file.
namespace :bible do
  desc "Import a Bible translation from OSIS XML. Usage: bin/rails 'bible:import[kjv]'"
  task :import, [ :code ] => :environment do |_, args|
    code = args[:code] || ENV["CODE"]
    abort "Usage: bin/rails 'bible:import[kjv]'" if code.blank?

    entry = BibleImportTask.load_entry(code)
    abort "Unknown translation code #{code.inspect} (not in config/bible_sources.yml)" unless entry

    xml_path = BibleImportTask.fetch_source(entry)
    translation = BibleImportTask.ensure_translation(code, entry)

    puts "Importing #{translation.code} from #{xml_path}..."
    started = Time.current
    stats = Bible::OsisImporter.new(path: xml_path, translation_code: translation.code).call
    duration = Time.current - started

    puts "Imported #{stats[:books]} books, #{stats[:chapters]} chapters, " \
         "#{stats[:verses]} verses, #{stats[:red_letter_ranges]} red-letter ranges " \
         "in #{duration.round(1)}s"

    # Sources that don't encode <q who="Jesus"> (container-style OSIS
    # from gratis-bible, including RV1909) arrive with zero red-letter
    # ranges. Mirror from KJV when available; skipped for KJV itself
    # and anything that already has red coverage.
    if stats[:red_letter_ranges].zero? && translation.code != "KJV" && Translation.exists?(code: "KJV")
      result = Bible::RedLetterMirror.call(target_translation_code: translation.code)
      puts "Red-letter mirror: #{result}"
    end
  end

  namespace :import do
    desc "Import the King James Version"
    task kjv: :environment do
      Rake::Task["bible:import"].invoke("kjv")
    end
  end
end

# Helpers extracted to a module for testability and to keep the task body
# focused on orchestration.
module BibleImportTask
  DOWNLOAD_DIR = Rails.root.join("tmp/bible_sources")

  class << self
    # Production lookups only see config/bible_sources.yml. Tests also see
    # spec/fixtures/bible_sources.yml so test-only entries never leak into
    # dev/prod config.
    def config_paths
      paths = [ Rails.root.join("config/bible_sources.yml") ]
      paths << Rails.root.join("spec/fixtures/bible_sources.yml") if Rails.env.test?
      paths
    end

    def load_entry(code)
      key = code.to_s.downcase
      config_paths.each do |path|
        next unless path.exist?

        sources = YAML.safe_load_file(path) || {}
        entry = sources[key]
        return entry if entry
      end
      nil
    end

    def fetch_source(entry)
      FileUtils.mkdir_p(DOWNLOAD_DIR)
      source = entry.fetch("source")
      filename = source.fetch("filename")
      download_path = DOWNLOAD_DIR.join(filename)

      download(source.fetch("url"), download_path) unless download_path.exist?
      verify_sha256!(download_path, source.fetch("sha256"))

      source["archive"] ? unzip_and_find_xml(download_path) : download_path
    end

    def ensure_translation(code, entry)
      Translation.find_or_create_by!(code: code.upcase) do |t|
        t.name          = entry.fetch("name")
        t.language      = entry.fetch("language")
        t.public_domain = entry.fetch("public_domain", false)
        t.license_notes = entry.fetch("license_notes", "")
      end
    end

    private

    def download(url, path)
      uri = URI.parse(url)
      abort "Refusing to download non-HTTPS URL #{url.inspect}" unless uri.scheme == "https"
      puts "Downloading #{url} -> #{path}"
      uri.open do |remote|
        File.open(path, "wb") { |f| IO.copy_stream(remote, f) }
      end
    end

    def verify_sha256!(path, expected)
      actual = Digest::SHA256.file(path).hexdigest
      return if actual == expected

      abort "SHA256 mismatch for #{path.basename}:\n  expected #{expected}\n  got      #{actual}"
    end

    def unzip_and_find_xml(zip_path)
      require "zip"
      extract_dir = DOWNLOAD_DIR.join(zip_path.basename(".zip").to_s)
      FileUtils.mkdir_p(extract_dir)
      Zip::File.open(zip_path) do |archive|
        archive.each do |entry|
          target = extract_dir.join(entry.name)
          FileUtils.mkdir_p(target.dirname)
          entry.extract(target) { true } unless target.exist?
        end
      end
      Dir[extract_dir.join("**/*.xml")].first || abort("No .xml found inside #{zip_path}")
    end
  end
end
