require "rails_helper"

RSpec.describe Bible::OsisImporter do
  let(:fixture_path) { Rails.root.join("spec/fixtures/osis/kjv_mini.xml") }

  subject(:importer) { described_class.new(path: fixture_path, translation_code: "KJV") }

  before do
    # Ensure translation exists so the importer can attach books to it.
    create(:translation, :kjv)
  end

  describe "#call" do
    it "returns the import statistics" do
      stats = importer.call
      expect(stats).to include(
        books: 2,
        chapters: 3,
        verses: 14,
        red_letter_ranges: 5
      )
    end

    it "creates only canonical books (filters apocrypha)" do
      importer.call
      codes = Translation.find_by(code: "KJV").books.pluck(:osis_code).sort
      expect(codes).to eq(%w[1Kgs John])
      expect(Book.where(osis_code: "Tob")).to be_empty
    end

    it "attaches chapters and verses under the right books" do
      importer.call
      john = Book.find_by!(osis_code: "John")
      kgs  = Book.find_by!(osis_code: "1Kgs")
      expect(john.chapters.pluck(:number).sort).to eq([ 3, 4 ])
      expect(kgs.chapters.pluck(:number)).to eq([ 1 ])
      expect(john.chapters.find_by!(number: 3).verses.count).to eq(4)
      expect(john.chapters.find_by!(number: 4).verses.count).to eq(5)
      expect(kgs.chapters.find_by!(number: 1).verses.count).to eq(5)
    end

    it "caches verse_count on chapter rows" do
      importer.call
      john3 = Book.find_by!(osis_code: "John").chapters.find_by!(number: 3)
      expect(john3.verse_count).to eq(4)
    end

    it "normalizes osis_ref to Bible.KJV.Book.Chapter.Verse" do
      importer.call
      john_316 = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
      expect(john_316.body_text).to start_with("For God so loved the world")
    end

    context "John 3:16 (fully red)" do
      let(:verse) { importer.call; Verse.find_by!(osis_ref: "Bible.KJV.John.3.16") }

      it "stores the full plain text verse body" do
        expect(verse.body_text).to eq(
          "For God so loved the world, that he gave his only begotten Son, " \
          "that whosoever believeth in him should not perish, but have everlasting life."
        )
      end

      it "marks the entire verse as a red-letter range" do
        expect(verse.red_letter_ranges).to eq([ [ 0, verse.body_text.length ] ])
      end

      it "wraps the red range in body_html with the jesus-words span" do
        expect(verse.body_html).to start_with(%(<span class="jesus-words">For God))
        expect(verse.body_html).to end_with(%(life.</span>))
      end
    end

    context "John 3:14 (partly red, has footnote)" do
      let(:verse) { importer.call; Verse.find_by!(osis_ref: "Bible.KJV.John.3.14") }

      it "strips footnote content from body_text" do
        expect(verse.body_text).not_to include("Num 21:9")
      end

      it "keeps the partial red-letter range around 'even so must...be lifted up'" do
        span = "even so must the Son of man be lifted up"
        start = verse.body_text.index(span)
        expect(verse.red_letter_ranges).to eq([ [ start, start + span.length ] ])
      end

      it "escapes non-red content and wraps red content in the span in body_html" do
        expect(verse.body_html).to include(%(<span class="jesus-words">even so must the Son of man be lifted up</span>))
        expect(verse.body_html).to include("As Moses lifted up")
      end
    end

    context "John 3:17 (no red letters)" do
      it "has an empty red_letter_ranges array" do
        importer.call
        verse = Verse.find_by!(osis_ref: "Bible.KJV.John.3.17")
        expect(verse.red_letter_ranges).to eq([])
        expect(verse.body_html).not_to include("jesus-words")
      end
    end

    context "John 4:1-4:2 (cross-verse Jesus span)" do
      before { importer.call }

      it "closes the open range at the end of verse 1" do
        verse = Verse.find_by!(osis_ref: "Bible.KJV.John.4.1")
        start = verse.body_text.index("red words span one")
        expect(verse.red_letter_ranges).to eq([ [ start, verse.body_text.length ] ])
      end

      it "opens verse 2 already inside the carried-over Jesus span" do
        verse = Verse.find_by!(osis_ref: "Bible.KJV.John.4.2")
        expect(verse.red_letter_ranges).to eq([ [ 0, "red words span two".length ] ])
        expect(verse.body_text).to start_with("red words span two")
      end
    end

    context "1Kgs 1:1 (divineName passthrough)" do
      it "includes the inner text of divineName in body_text" do
        importer.call
        verse = Verse.find_by!(osis_ref: "Bible.KJV.1Kgs.1.1")
        expect(verse.body_text).to include("LORD")
      end
    end

    context "1Kgs 1:2 (whitespace-heavy)" do
      it "collapses runs of whitespace and strips leading/trailing space" do
        importer.call
        verse = Verse.find_by!(osis_ref: "Bible.KJV.1Kgs.1.2")
        expect(verse.body_text).to eq(
          "Wherefore his servants said unto him, Let there be sought a young virgin."
        )
      end
    end

    describe "idempotency" do
      it "re-running the importer yields the same row counts" do
        first = importer.call
        Bible::CanonicalBooks.reset!
        second = described_class.new(path: fixture_path, translation_code: "KJV").call

        expect(second).to eq(first)
        expect(Translation.find_by(code: "KJV").books.count).to eq(2)
        expect(Verse.count).to eq(14)
      end
    end
  end
end
