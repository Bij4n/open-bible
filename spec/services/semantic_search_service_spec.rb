require "rails_helper"

RSpec.describe SemanticSearchService do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }

  def verse_with_embedding(number:, vector:)
    verse = create(:verse, chapter: chapter, number: number,
                           body_text: "sample #{number}",
                           body_html: "sample #{number}",
                           osis_ref: "Bible.KJV.John.3.#{number}")
    create(:verse_embedding, verse: verse, embedding: vector)
    verse
  end

  describe "#call" do
    it "returns an empty, unavailable result on a blank query" do
      result = described_class.new(query: "  ").call
      expect(result).to eq(verses: [], available: false)
    end

    it "returns an empty, unavailable result when the service is down" do
      allow(EmbeddingService).to receive(:healthy?).and_return(false)
      result = described_class.new(query: "love").call
      expect(result).to eq(verses: [], available: false)
    end

    it "returns an empty, available result when no embeddings exist yet" do
      allow(EmbeddingService).to receive(:healthy?).and_return(true)
      result = described_class.new(query: "love").call
      expect(result).to eq(verses: [], available: true)
    end

    it "returns verses ordered by cosine similarity on success" do
      near = verse_with_embedding(number: 1, vector: [ 1.0, 0.0 ] + Array.new(382, 0.0))
      # cos([0.8, 0.6], [1, 0]) == 0.8 — above the 0.3 threshold, below near's 1.0
      far  = verse_with_embedding(number: 2, vector: [ 0.8, 0.6 ] + Array.new(382, 0.0))

      query_vector = [ 1.0, 0.0 ] + Array.new(382, 0.0)
      allow(EmbeddingService).to receive_messages(
        healthy?: true,
        embed_texts: { "embeddings" => [ query_vector ], "model_version" => "all-MiniLM-L6-v2" }
      )

      result = described_class.new(query: "love").call
      expect(result[:available]).to be true
      expect(result[:verses]).to eq([ near, far ])
      expect(result[:verses].first.similarity_score).to be_within(0.0001).of(1.0)
    end

    it "treats an EmbeddingError as a service outage" do
      verse_with_embedding(number: 1, vector: [ 1.0 ] + Array.new(383, 0.0))
      allow(EmbeddingService).to receive(:healthy?).and_return(true)
      allow(EmbeddingService).to receive(:embed_texts).and_raise(EmbeddingService::EmbeddingError, "boom")

      result = described_class.new(query: "love").call
      expect(result).to eq(verses: [], available: false)
    end

    it "returns empty + unavailable when the service response has no vectors" do
      verse_with_embedding(number: 1, vector: [ 1.0 ] + Array.new(383, 0.0))
      allow(EmbeddingService).to receive_messages(
        healthy?: true,
        embed_texts: { "embeddings" => [], "model_version" => "all-MiniLM-L6-v2" }
      )

      result = described_class.new(query: "love").call
      expect(result).to eq(verses: [], available: false)
    end
  end

  describe "translations scope" do
    let!(:rv1909) { create(:translation, code: "RV1909", name: "Reina-Valera 1909", language: "es") }
    let!(:rv_john) { create(:book, osis_code: "John", translation: rv1909, name_en: "John", name_es: "Juan", position: 43, testament: :new) }
    let!(:rv_chapter) { create(:chapter, book: rv_john, number: 3) }

    def rv_verse_with_embedding(number:, vector:)
      verse = create(:verse, chapter: rv_chapter, number: number,
                             body_text: "es sample #{number}",
                             body_html: "es sample #{number}",
                             osis_ref: "Bible.RV1909.John.3.#{number}")
      create(:verse_embedding, verse: verse, embedding: vector)
      verse
    end

    let(:query_vector) { [ 1.0, 0.0 ] + Array.new(382, 0.0) }

    before do
      allow(EmbeddingService).to receive_messages(
        healthy?: true,
        embed_texts: { "embeddings" => [ query_vector ], "model_version" => "all-MiniLM-L6-v2" }
      )
    end

    it "defaults to current translation (KJV) when translations is unset" do
      kjv = verse_with_embedding(number: 16, vector: query_vector)
      rv  = rv_verse_with_embedding(number: 16, vector: query_vector)

      result = described_class.new(query: "divine love").call
      expect(result[:verses]).to include(kjv)
      expect(result[:verses]).not_to include(rv)
    end

    it "scopes to the passed translation_code when translations: 'current'" do
      kjv = verse_with_embedding(number: 16, vector: query_vector)
      rv  = rv_verse_with_embedding(number: 16, vector: query_vector)

      result = described_class.new(query: "divine love",
                                   translations: "current",
                                   translation_code: "RV1909").call
      expect(result[:verses]).to include(rv)
      expect(result[:verses]).not_to include(kjv)
    end

    it "spans every translation when translations: 'all'" do
      kjv = verse_with_embedding(number: 16, vector: query_vector)
      rv  = rv_verse_with_embedding(number: 16, vector: query_vector)

      result = described_class.new(query: "divine love", translations: "all").call
      expect(result[:verses]).to include(kjv, rv)
    end

    it "ignores unknown translations values and treats them as 'current'" do
      kjv = verse_with_embedding(number: 16, vector: query_vector)
      rv_verse_with_embedding(number: 16, vector: query_vector)

      result = described_class.new(query: "divine love",
                                   translations: "cross-sprite",
                                   translation_code: "KJV").call
      expect(result[:verses]).to contain_exactly(kjv)
    end
  end
end
