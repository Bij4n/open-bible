require "rails_helper"

RSpec.describe Note, ".search_body" do
  let(:author) { create(:user) }

  let!(:hinge_note) do
    create(:note, user: author, visibility: :public_note,
                  body: "<p>The <strong>hinge</strong> of the gospel is love.</p>")
  end
  let!(:faith_note) do
    create(:note, user: author, visibility: :public_note,
                  body: "<p>Faith is the substance of things hoped for.</p>")
  end

  it "finds notes whose rich-text body contains the search term" do
    results = Note.search_body("hinge")
    expect(results).to include(hinge_note)
    expect(results).not_to include(faith_note)
  end

  it "is case-insensitive" do
    expect(Note.search_body("HINGE")).to include(hinge_note)
  end

  it "supports prefix matches" do
    # "gosp" should match "gospel"
    expect(Note.search_body("gosp")).to include(hinge_note)
  end

  it "returns empty for no-match queries" do
    expect(Note.search_body("zzzzz")).to be_empty
  end

  it "searches across visibility states (scoping is the caller's concern)" do
    private_match = create(:note, user: author, visibility: :private_note,
                                  body: "<p>A private hinge thought.</p>")
    expect(Note.search_body("hinge")).to include(private_match)
  end
end
