require "rails_helper"

RSpec.describe Bible::RedLetterMirror do
  let!(:kjv)    { create(:translation, :kjv) }
  let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }

  let(:kjv_john)    { create(:book, :john, translation: kjv) }
  let(:rv_john) do
    create(:book, osis_code: "John", translation: rv1909,
                  name_en: "John", name_es: "Juan", position: 43, testament: :new)
  end
  let(:kjv_chapter) { create(:chapter, book: kjv_john, number: 3) }
  let(:rv_chapter)  { create(:chapter, book: rv_john,  number: 3) }

  def kjv_verse(number:, body:, ranges:)
    create(:verse, chapter: kjv_chapter, number: number,
                   body_text: body, body_html: body,
                   red_letter_ranges: ranges,
                   osis_ref: "Bible.KJV.John.3.#{number}")
  end

  def rv_verse(number:, body:)
    create(:verse, chapter: rv_chapter, number: number,
                   body_text: body, body_html: body,
                   red_letter_ranges: [],
                   osis_ref: "Bible.RV1909.John.3.#{number}")
  end

  describe ".call" do
    it "mirrors fully-red KJV verses onto matching RV1909 verses with target-length ranges" do
      en = "For God so loved the world, that he gave his only begotten Son."
      es = "Porque de tal manera amó Dios al mundo, que ha dado á su Hijo unigénito."
      kjv_verse(number: 16, body: en, ranges: [ [ 0, en.length ] ])
      rv_verse(number: 16,  body: es)

      result = described_class.call(target_translation_code: "RV1909")

      rv = Verse.find_by!(osis_ref: "Bible.RV1909.John.3.16")
      expect(rv.red_letter_ranges).to eq([ [ 0, es.length ] ])
      expect(result.updated).to eq(1)
      expect(result.fully_red_verses).to eq(1)
    end

    it "skips partial-red verses (leaves target empty)" do
      body = "And Jesus said unto them, I am the bread of life."
      kjv_verse(number: 35, body: body, ranges: [ [ 25, body.length ] ])
      rv_verse(number: 35, body: "Y Jesús les dijo: Yo soy el pan de vida.")

      described_class.call(target_translation_code: "RV1909")

      rv = Verse.find_by!(osis_ref: "Bible.RV1909.John.3.35")
      expect(rv.red_letter_ranges).to eq([])
    end

    it "counts a skipped partial verse in the result" do
      body = "And Jesus said, I am the way."
      kjv_verse(number: 6, body: body, ranges: [ [ 16, body.length ] ])
      rv_verse(number: 6, body: "Y Jesús le dijo: Yo soy el camino.")

      result = described_class.call(target_translation_code: "RV1909")
      expect(result.skipped_partial).to eq(1)
      expect(result.updated).to eq(0)
    end

    it "records a missing target when no RV1909 verse matches the KJV osis_ref" do
      body = "I am the resurrection and the life."
      kjv_verse(number: 25, body: body, ranges: [ [ 0, body.length ] ])
      # Note: RV John 3 has no verse 25.

      result = described_class.call(target_translation_code: "RV1909")
      expect(result.fully_red_verses).to eq(1)
      expect(result.updated).to eq(0)
      expect(result.skipped_missing).to eq(1)
    end

    it "ignores source verses with no red-letter ranges at all" do
      kjv_verse(number: 1, body: "There was a man sent from God.", ranges: [])
      rv_verse(number: 1, body: "Había un hombre enviado de Dios.")

      result = described_class.call(target_translation_code: "RV1909")
      expect(result.fully_red_verses).to eq(0)
    end

    it "does not touch red ranges on source (KJV) verses" do
      body = "I am the light of the world."
      kjv = kjv_verse(number: 12, body: body, ranges: [ [ 0, body.length ] ])
      rv_verse(number: 12, body: "Yo soy la luz del mundo.")

      described_class.call(target_translation_code: "RV1909")
      expect(kjv.reload.red_letter_ranges).to eq([ [ 0, body.length ] ])
    end

    it "is idempotent on re-run" do
      body = "Verily, verily, I say unto you."
      kjv_verse(number: 3, body: body, ranges: [ [ 0, body.length ] ])
      rv_verse(number: 3, body: "De cierto, de cierto os digo.")

      described_class.call(target_translation_code: "RV1909")
      described_class.call(target_translation_code: "RV1909")

      rv = Verse.find_by!(osis_ref: "Bible.RV1909.John.3.3")
      expect(rv.red_letter_ranges).to eq([ [ 0, "De cierto, de cierto os digo.".length ] ])
    end
  end
end
