require "rails_helper"

# Render the homepage in each locale and assert no translation
# fell through to the missing-translation marker. Walking the
# response body for "translation missing" is more robust than
# enumerating keys by hand — the view itself is the source of
# truth for which strings need to be in both locales, and any
# key the view references that isn't in the locale file produces
# the marker we grep for.
RSpec.describe "Home i18n coverage", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :genesis, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 1) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 1,
                   body_text: "In the beginning",
                   body_html: "In the beginning",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.Gen.1.1")
  end

  %i[en es].each do |locale|
    it "renders the homepage in #{locale} without missing translations" do
      get "/", params: { locale: locale }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("translation missing")
      expect(response.body).not_to include("translation_missing")
    end
  end

  # The hero h1 ships `welcome_html` with <em> markup around the two
  # words rendered as Instrument Serif italic mint accents. The
  # rendered body contains the literal markup, so the assertion
  # matches the full HTML form rather than the visible-text form.
  it "renders the localized H1 in English" do
    get "/", params: { locale: :en }
    expect(response.body).to include("Where <em>verses</em> meet <em>voices</em>.")
  end

  it "renders the localized H1 in Spanish" do
    get "/", params: { locale: :es }
    expect(response.body).to include("Donde los <em>versículos</em> encuentran <em>voz</em>.")
  end
end
