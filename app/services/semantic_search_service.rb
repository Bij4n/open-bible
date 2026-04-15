# Concept-search entry point: turns a free-text query into an
# embedding via the Python service, then scores it against every
# verse embedding in-process.
#
# Translation scope: `translations:` is "current" (default) or "all".
# "current" uses the passed translation_code (falling back to KJV);
# "all" spans every code we have embeddings for. The controller
# gets the scope from a radio and threads the current translation
# through from the reader or the user's default_translation.
#
# Return shape: { verses: [...], available: Boolean }. The controller
# uses `available` to decide whether to fall back to keyword results
# and show a "concept search is temporarily unavailable" banner.
class SemanticSearchService
  VERSE_LIMIT          = 20
  SIMILARITY_THRESHOLD = 0.3
  VALID_SCOPES         = %w[current all].freeze
  DEFAULT_TRANSLATION  = "KJV".freeze

  attr_reader :query, :user, :translations, :translation_code

  def initialize(query:, user: nil, translations: "current", translation_code: DEFAULT_TRANSLATION)
    @query            = query.to_s.strip
    @user             = user
    @translations     = VALID_SCOPES.include?(translations.to_s) ? translations.to_s : "current"
    @translation_code = translation_code.to_s.presence || DEFAULT_TRANSLATION
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
      threshold: SIMILARITY_THRESHOLD,
      translation_codes: codes_for_scope
    )

    { verses: verses, available: true }
  rescue EmbeddingService::EmbeddingError => e
    Rails.logger.warn "Semantic search failed: #{e.message}"
    empty_result(available: false)
  end

  private

  def codes_for_scope
    translations == "all" ? Translation.pluck(:code) : [ translation_code.upcase ]
  end

  def empty_result(available:)
    { verses: [], available: available }
  end
end
