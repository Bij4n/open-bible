require "rails_helper"

RSpec.describe "Sitemap", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }

  it "renders /sitemap.xml as XML with the static + bible chapter URLs" do
    get "/sitemap.xml"
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/xml")
    expect(response.body).to start_with("<?xml")
    expect(response.body).to include("<urlset")
    expect(response.body).to include(root_url)
    expect(response.body).to include(about_url)
    expect(response.body).to include(donate_url)
    expect(response.body).to include(search_url)
    expect(response.body).to include(public_bible_chapter_url(translation: "kjv", book: "john", chapter: 3))
  end

  it "is reachable without authentication" do
    get "/sitemap.xml"
    expect(response).to have_http_status(:ok)
  end
end
