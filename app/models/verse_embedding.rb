class VerseEmbedding < ApplicationRecord
  belongs_to :verse

  validates :embedding_data, presence: true
  validates :model_version, presence: true
  validates :verse_id, uniqueness: true

  scope :by_model, ->(version) { where(model_version: version) }

  def embedding
    @embedding ||= JSON.parse(embedding_data)
  end

  def embedding=(vector)
    self.embedding_data = vector.to_json
    @embedding = nil
  end

  def similarity_to(query_vector)
    vec = embedding
    dot = 0.0
    mag_a = 0.0
    mag_b = 0.0
    i = 0
    len = vec.length
    while i < len
      a = vec[i]
      b = query_vector[i]
      dot   += a * b
      mag_a += a * a
      mag_b += b * b
      i += 1
    end
    return 0.0 if mag_a.zero? || mag_b.zero?
    dot / (Math.sqrt(mag_a) * Math.sqrt(mag_b))
  end

  # Loads embeddings for the given translation codes and scores each
  # against the query vector. Acceptable at 31k rows per translation
  # (sub-3s on warm cache); if it gets slow the next step is either a
  # boot-time memo on a class variable or a move to pgvector with an
  # HNSW index.
  def self.search_by_similarity(query_embedding, limit: 20, threshold: 0.3, translation_codes: [ "KJV" ])
    codes = Array(translation_codes).map(&:to_s).map(&:upcase)
    includes(verse: { chapter: { book: :translation } })
      .where(verses: { chapters: { books: { translations: { code: codes } } } })
      .filter_map { |ve|
        score = ve.similarity_to(query_embedding)
        next if score < threshold
        verse = ve.verse
        verse.define_singleton_method(:similarity_score) { score }
        verse
      }
      .sort_by { |v| -v.similarity_score }
      .first(limit)
  end
end
