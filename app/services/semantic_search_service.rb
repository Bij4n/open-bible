# Concept-search entry point: turns a free-text query into an
# embedding via the Python service, then scores it against every KJV
# verse embedding in-process.
#
# Return shape: { verses: [...], available: Boolean }. The controller
# uses `available` to decide whether to fall back to keyword results
# and show a "concept search is temporarily unavailable" banner.
class SemanticSearchService
  VERSE_LIMIT          = 20
  SIMILARITY_THRESHOLD = 0.3

  attr_reader :query, :user

  def initialize(query:, user: nil)
    @query = query.to_s.strip
    @user  = user
  end

  def call
    return empty_result(available: false) if query.blank?
    return empty_result(available: false) unless EmbeddingService.healthy?
    return empty_result(available: true)  if VerseEmbedding.count.zero?

    payload = EmbeddingService.embed_texts([ query ])
    query_vector = payload["embeddings"].first
    return empty_result(available: false) if query_vector.blank?

    verses = VerseEmbedding.search_by_similarity(
      query_vector,
      limit: VERSE_LIMIT,
      threshold: SIMILARITY_THRESHOLD
    )

    { verses: verses, available: true }
  rescue EmbeddingService::EmbeddingError => e
    Rails.logger.warn "Semantic search failed: #{e.message}"
    empty_result(available: false)
  end

  private

  def empty_result(available:)
    { verses: [], available: available }
  end
end
