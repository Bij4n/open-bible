class SearchController < ApplicationController
  MODES = %w[keyword semantic].freeze

  def index
    @query        = params[:q].to_s
    @scope        = params[:scope].to_s.presence || "all"
    @mode         = MODES.include?(params[:mode]) ? params[:mode] : "keyword"
    @translations = SearchService::VALID_TRANSLATIONS.include?(params[:translations]) ? params[:translations] : "current"
    @translation_code = params[:translation_code].to_s.presence || default_translation_code

    @semantic_available = !rv1909_only?
    @mode = "keyword" if @mode == "semantic" && !@semantic_available

    @results = @mode == "semantic" ? semantic_results : keyword_results
  end

  private

  def keyword_results
    SearchService.new(
      query: @query,
      user: current_user,
      scope: @scope,
      translations: @translations,
      translation_code: @translation_code
    ).call
  end

  def semantic_results
    semantic = SemanticSearchService.new(
      query: @query,
      user: current_user,
      translations: @translations,
      translation_code: @translation_code
    ).call
    return keyword_results.merge(semantic_fallback: true) unless semantic[:available]

    {
      verses: @scope.in?(%w[all verses]) ? semantic[:verses] : [],
      notes: [],
      semantic: true,
      notes_scope_requested: @scope == "notes"
    }
  end

  def default_translation_code
    user_signed_in? && current_user.default_translation&.code || "KJV"
  end

  def rv1909_only?
    @translations == "current" && @translation_code.upcase == "RV1909"
  end
end
