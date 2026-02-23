require "rails_helper"

RSpec.describe Bible::OsisImporter, "container-style OSIS" do
  let(:fixture_path) { Rails.root.join("spec/fixtures/osis/container_mini.xml") }

  subject(:importer) { described_class.new(path: fixture_path, translation_code: "KJV") }

  before do
    create(:translation, :kjv)
  end

  it "returns import stats" do
    stats = importer.call
    expect(stats).to include(books: 1, chapters: 2, verses: 6, red_letter_ranges: 0)
  end

  it "filters non-canonical books identically to milestone-style" do
    importer.call
    expect(Book.where(osis_code: "Tob")).to be_empty
    expect(Book.where(osis_code: "John")).to exist
  end

  it "captures inline verse text from <verse osisID>...</verse>" do
    importer.call
    verse = Verse.find_by!(osis_ref: "Bible.KJV.John.3.16")
    expect(verse.body_text).to eq("For God so loved the world — container style.")
  end

  it "associates verses with the right chapter via container <chapter>" do
    importer.call
    john3 = Book.find_by!(osis_code: "John").chapters.find_by!(number: 3)
    john4 = Book.find_by!(osis_code: "John").chapters.find_by!(number: 4)
    expect(john3.verses.pluck(:number).sort).to eq([ 14, 15, 16, 17 ])
    expect(john4.verses.pluck(:number).sort).to eq([ 1, 2 ])
  end

  it "records no red-letter ranges when the source has no <q who='Jesus'>" do
    importer.call
    expect(Verse.find_by!(osis_ref: "Bible.KJV.John.3.16").red_letter_ranges).to eq([])
  end

  it "caches verse_count on chapter rows" do
    importer.call
    john3 = Book.find_by!(osis_code: "John").chapters.find_by!(number: 3)
    john4 = Book.find_by!(osis_code: "John").chapters.find_by!(number: 4)
    expect(john3.verse_count).to eq(4)
    expect(john4.verse_count).to eq(2)
  end

  it "is idempotent on re-run" do
    importer.call
    expect { described_class.new(path: fixture_path, translation_code: "KJV").call }
      .not_to change(Verse, :count)
  end
end
