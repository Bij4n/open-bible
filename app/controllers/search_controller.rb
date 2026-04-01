class SearchController < ApplicationController
  def index
    @query   = params[:q].to_s
    @scope   = params[:scope].to_s.presence || "all"
    @results = SearchService.new(query: @query, user: current_user, scope: @scope).call
  end
end
