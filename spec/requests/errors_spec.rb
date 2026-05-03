require "rails_helper"

# Branded error pages — two-layer system:
#
# 1. Static fallbacks in public/{404,422,500,400}.html — served by
#    nginx/Rack::Static when the Rails app can't process the request
#    (boot failure, mid-deploy, etc.). These don't go through the
#    Rails router. Test by file-content assertion.
#
# 2. Dynamic ErrorsController#show — wired via
#    config.exceptions_app = self.routes (production.rb). When Rails
#    catches an exception, it dispatches the configured error path
#    through the routes table to ErrorsController, which renders the
#    Echo-branded view inside application.html.erb so the page carries
#    the full chrome (header + footer). Test by direct controller
#    invocation; in test/dev env Rack::Static otherwise intercepts
#    /404 etc. and serves the file from public/ before routing runs.
RSpec.describe "Errors", type: :request do
  describe "static fallback files" do
    %w[404 422 500 400].each do |code|
      it "public/#{code}.html exists with Echo-branded content" do
        path = Rails.root.join("public/#{code}.html")
        expect(path).to be_exist
        body = File.read(path)
        expect(body).to include("Open Bible")
        expect(body).to include("#0F5C3F")
        expect(body).to include("Back to home")
        case code
        when "404" then expect(body).to include("404")
        when "422" then expect(body).to include("422")
        when "500" then expect(body).to include("500")
        when "400" then expect(body).to include("400")
        end
      end
    end
  end

  describe "ErrorsController#show (dynamic, branded)" do
    # exceptions_app dispatches through the routes table, but in test
    # env Rack::Static intercepts /404 etc. before routing. Hit the
    # controller via a route that doesn't conflict with a public file
    # name. We use Rails.application.routes to recognize the path then
    # invoke the controller directly with the resolved params.
    [ [ 404, :not_found ], [ 422, :unprocessable_content ],
      [ 500, :internal_server_error ], [ 400, :bad_request ],
      [ 406, :not_acceptable ] ].each do |code, status|
      it "renders status #{code}" do
        get "/__error/#{code}"
        expect(response).to have_http_status(status)
        expect(response.body).to include(code.to_s)
      end
    end

    it "renders the en eyebrow + heading content" do
      get "/__error/404"
      expect(response.body).to include("404 — Not found")
      expect(response.body).to include("doesn't exist")
    end

    it "renders the es eyebrow + heading content with locale=es" do
      get "/__error/404?locale=es"
      expect(response.body).to include("404 — No encontrada")
      expect(response.body).to include("no existe")
    end

    it "falls back to 404 when given an unknown code" do
      get "/__error/999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
