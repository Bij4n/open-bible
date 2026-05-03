require "rails_helper"

# Site-wide SEO + social-sharing meta tags emitted by application.html.erb.
# Per-page <title> and meta description fall through to app-level
# defaults via content_for; OG + Twitter tags mirror the same values.
RSpec.describe "Layout meta tags", type: :request do
  describe "GET /" do
    before { get "/" }

    it "emits a <meta name=\"description\">" do
      expect(response.body).to match(%r{<meta name="description" content="[^"]+">})
    end

    it "emits Open Graph tags (og:title, og:description, og:type, og:url, og:image)" do
      expect(response.body).to include('property="og:title"')
      expect(response.body).to include('property="og:description"')
      expect(response.body).to include('property="og:type" content="website"')
      expect(response.body).to include('property="og:url"')
      expect(response.body).to include('property="og:image"')
      expect(response.body).to include('property="og:site_name"')
      expect(response.body).to include("/icon.png")
    end

    it "emits Twitter card tags" do
      expect(response.body).to include('name="twitter:card" content="summary"')
      expect(response.body).to include('name="twitter:title"')
      expect(response.body).to include('name="twitter:description"')
      expect(response.body).to include('name="twitter:image"')
    end

    it "emits a canonical link without query params" do
      get "/?utm_source=twitter"
      expect(response.body).to match(%r{<link rel="canonical" href="[^"?]+">})
      expect(response.body).not_to match(%r{<link rel="canonical" href="[^"]*\?})
    end

    it "switches og:locale based on I18n.locale" do
      get "/?locale=es"
      expect(response.body).to include('property="og:locale" content="es_ES"')
      get "/?locale=en"
      expect(response.body).to include('property="og:locale" content="en_US"')
    end
  end

  describe "page-level title interpolation" do
    it "appends ' · Open Bible' when a controller sets content_for :title" do
      get "/about"
      expect(response.body).to match(%r{<title>[^<]+ · Open Bible</title>})
    end

    it "uses just the app name when no content_for :title is set" do
      # Homepage doesn't yield :title; falls through to app.name
      get "/"
      expect(response.body).to match(%r{<title>Open Bible</title>})
    end
  end
end
