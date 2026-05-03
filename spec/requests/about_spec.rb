require "rails_helper"

RSpec.describe "About page", type: :request do
  it "renders the About content at /about" do
    get "/about"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("home.about.heading"))
    expect(response.body).to include(I18n.t("home.about.para_1"))
    expect(response.body).to include(I18n.t("home.about.para_2"))
  end

  it "renders the Spanish content with locale=es" do
    get "/about?locale=es"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("home.about.heading", locale: :es))
    expect(response.body).to include(I18n.t("home.about.para_1", locale: :es))
  end

  it "is reachable without authentication" do
    get "/about"
    expect(response).to have_http_status(:ok)
  end
end
