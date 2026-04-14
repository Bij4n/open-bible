require "rails_helper"
require "rake"
require "fileutils"

RSpec.describe "bible:import rake task for RV1909" do
  let(:fixture_path) { Rails.root.join("spec/fixtures/osis/rv1909_mini.xml") }
  let(:target_path)  { Rails.root.join("tmp/bible_sources/rv1909_mini.xml") }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("bible:import")
  end

  before do
    Rake::Task["bible:import"].reenable
    FileUtils.mkdir_p(target_path.dirname)
    FileUtils.cp(fixture_path, target_path)
    Bible::CanonicalBooks.reset!
  end

  after do
    FileUtils.rm_f(target_path)
  end

  it "creates the RV1909 translation with Spanish language" do
    Rake::Task["bible:import"].invoke("rv1909_mini")

    translation = Translation.find_by!(code: "RV1909_MINI")
    expect(translation.name).to eq("RV1909 Mini (test fixture)")
    expect(translation.language).to eq("es")
    expect(translation.public_domain).to be true
  end

  it "imports canonical books with Spanish names from config/books.yml" do
    Rake::Task["bible:import"].invoke("rv1909_mini")

    translation = Translation.find_by!(code: "RV1909_MINI")
    books = translation.books.order(:position)
    expect(books.pluck(:osis_code)).to eq(%w[Gen John])
    expect(books.find_by(osis_code: "Gen").name_es).to eq("Génesis")
    expect(books.find_by(osis_code: "John").name_es).to eq("Juan")
  end

  it "filters out apocryphal books just like the KJV path" do
    Rake::Task["bible:import"].invoke("rv1909_mini")

    translation = Translation.find_by!(code: "RV1909_MINI")
    expect(translation.books.pluck(:osis_code)).not_to include("Tob")
  end

  it "normalizes osis_ref to Bible.RV1909_MINI.Book.Chapter.Verse" do
    Rake::Task["bible:import"].invoke("rv1909_mini")
    expect(Verse.find_by(osis_ref: "Bible.RV1909_MINI.John.3.16")).to be_present
  end

  it "round-trips Spanish UTF-8 characters through the importer" do
    Rake::Task["bible:import"].invoke("rv1909_mini")

    gen_1_1 = Verse.find_by!(osis_ref: "Bible.RV1909_MINI.Gen.1.1")
    expect(gen_1_1.body_text).to eq("EN el principio crió Dios los cielos y la tierra.")
    expect(gen_1_1.body_text).to include("crió")   # archaic RV1909 verb form
    expect(gen_1_1.body_text.encoding).to eq(Encoding::UTF_8)

    john_3_16 = Verse.find_by!(osis_ref: "Bible.RV1909_MINI.John.3.16")
    expect(john_3_16.body_text).to eq(
      "Porque de tal manera amó Dios al mundo, que ha dado á su Hijo " \
      "unigénito, para que todo aquel que en él cree, no se pierda, mas " \
      "tenga vida eterna."
    )
    expect(john_3_16.body_text).to include("á su Hijo unigénito")
  end

  it "records empty red_letter_ranges (source has no <q who='Jesus'>)" do
    Rake::Task["bible:import"].invoke("rv1909_mini")
    expect(Verse.where(osis_ref: "Bible.RV1909_MINI.John.3.16").pick(:red_letter_ranges)).to eq([])
  end

  it "caches verse_count per chapter" do
    Rake::Task["bible:import"].invoke("rv1909_mini")
    john3 = Book.joins(:translation)
                .where(translations: { code: "RV1909_MINI" }, osis_code: "John")
                .first
                .chapters.find_by!(number: 3)
    expect(john3.verse_count).to eq(4)
  end

  it "mirrors red-letter ranges from KJV when KJV is already imported" do
    # Seed a fully-red KJV John 3:16 so the import hook can mirror it.
    kjv = create(:translation, :kjv)
    kjv_john = create(:book, :john, translation: kjv)
    kjv_chapter = create(:chapter, book: kjv_john, number: 3)
    en_body = "For God so loved the world."
    create(:verse, chapter: kjv_chapter, number: 16,
                   body_text: en_body, body_html: en_body,
                   red_letter_ranges: [ [ 0, en_body.length ] ],
                   osis_ref: "Bible.KJV.John.3.16")

    Rake::Task["bible:import"].invoke("rv1909_mini")

    es_verse = Verse.find_by!(osis_ref: "Bible.RV1909_MINI.John.3.16")
    expect(es_verse.red_letter_ranges).to eq([ [ 0, es_verse.body_text.length ] ])
  end

  it "is idempotent on re-run" do
    Rake::Task["bible:import"].invoke("rv1909_mini")
    expect(Verse.where("osis_ref LIKE 'Bible.RV1909_MINI.%'").count).to eq(9)

    Rake::Task["bible:import"].reenable
    Rake::Task["bible:import"].invoke("rv1909_mini")

    expect(Translation.where(code: "RV1909_MINI").count).to eq(1)
    expect(Verse.where("osis_ref LIKE 'Bible.RV1909_MINI.%'").count).to eq(9)
  end
end
