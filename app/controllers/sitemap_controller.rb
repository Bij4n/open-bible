class SitemapController < ApplicationController
  # Public XML sitemap for SEO crawlers. Lists static marketing routes
  # plus every public bible chapter URL. Bible content is public-domain
  # KJV + RV1909, never changes once imported, so the sitemap is highly
  # cache-friendly. Cached with a 1-day TTL via fragment caching in
  # the view; the eager-loaded Translation→Book→Chapter graph stays
  # warm in Solid Cache between requests.
  def show
    @translations = Translation.includes(books: :chapters).order(:code)
    respond_to do |format|
      format.xml { render :show, layout: false }
    end
  end
end
