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
end
