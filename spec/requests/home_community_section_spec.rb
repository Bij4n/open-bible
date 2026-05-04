require "rails_helper"

# Sprint 22.3 — homepage community section. Renders up to 3 most-recent
# public notes between hero and Features. Skips the featured hero note
# (no double-show). Doesn't render at all when there are zero
# eligible public notes (graceful empty state).
RSpec.describe "Homepage community section", type: :request do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end

  def create_public_note(author_name:, body:, color: "gold")
    user = create(:user, display_name: author_name)
    note = create(:note, user: user, body: "<p>#{body}</p>", visibility: :public_note)
    hl = create(:highlight, user: user, translation: translation,
                            osis_ref: "Bible.KJV.John.3.16!4-Bible.KJV.John.3.16!7",
                            color: color)
    create(:highlight_note, highlight: hl, note: note)
    note
  end

  it "does not render the section when no public notes exist" do
    get "/"
    expect(response.body).not_to include(I18n.t("home.community.heading_html").gsub(/<\/?em>/, ""))
    expect(response.body).not_to include('id="community"')
  end

  it "renders 1 card when 1 public note exists" do
    create_public_note(author_name: "Apollos", body: "The hinge of the gospel.")
    get "/"
    expect(response.body).to include('id="community"')
    expect(response.body).to include("Apollos")
    expect(response.body).to include("hinge of the gospel")
  end

  it "renders 3 cards when 3+ public notes exist" do
    %w[Apollos Priscilla Lydia Phoebe].each_with_index do |name, i|
      create_public_note(author_name: name, body: "Note from #{name}.")
    end
    get "/"
    expect(response.body).to include('id="community"')
    expect(response.body).to include("Phoebe")    # newest
    expect(response.body).to include("Lydia")     # 2nd newest
    expect(response.body).to include("Priscilla") # 3rd newest
    expect(response.body).not_to include("Apollos") # 4th — over the 3-card limit
  end

  it "skips the featured hero note (no double-show)" do
    apollos_note = create_public_note(author_name: "Apollos", body: "Hero featured note.")
    apollos_note.update!(featured: true, featured_at: Time.current)
    create_public_note(author_name: "Priscilla", body: "Community note.")

    get "/"
    # Apollos shows in hero (only once). Priscilla shows in community.
    expect(response.body.scan("Apollos").length).to eq(1)
    expect(response.body).to include("Priscilla")
  end

  it "filters hidden public notes" do
    note = create_public_note(author_name: "Apollos", body: "Will be hidden.")
    note.update!(hidden_at: Time.current)
    get "/"
    expect(response.body).not_to include("Apollos")
    expect(response.body).not_to include('id="community"')
  end

  it "uses the prototype heading + intro copy" do
    create_public_note(author_name: "Apollos", body: "trigger render")
    get "/"
    expect(response.body).to include("Read what struck")
    expect(response.body).to include("someone else")
    expect(response.body).to include(I18n.t("home.community.intro"))
  end

  it "renders the Spanish heading + intro with locale=es" do
    create_public_note(author_name: "Apollos", body: "trigger render")
    get "/?locale=es"
    expect(response.body).to include("Lee lo que tocó")
    expect(response.body).to include("otro")
    expect(response.body).to include(I18n.t("home.community.intro", locale: :es))
  end
end
