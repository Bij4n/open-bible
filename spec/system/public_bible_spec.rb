require "rails_helper"

RSpec.describe "Public bible + moderation", type: :system, js: true do
  let(:admin)  { create(:user, admin: true) }
  let(:reader) { create(:user) }
  let(:author) { create(:user, display_name: "Apollos") }
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)    { create(:book, :john, translation: translation) }
  let!(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end

  def public_note!(user: author, body: "Community thought", featured: false)
    highlight = create(:highlight, user: user, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: user, body: "<p>#{body}</p>",
                         visibility: :public_note, featured: featured,
                         featured_at: (featured ? Time.current : nil))
    create(:highlight_note, highlight: highlight, note: note)
    note
  end

  it "upvotes a note and the count updates without a reload" do
    public_note!(body: "Original thought")
    sign_in reader
    visit "/public/bible/kjv/john/3"

    expect(page).to have_content("0")
    find("button[data-upvote-target='button']").click
    expect(page).to have_selector("[data-upvote-target='count']", text: "1")

    # Reload and verify persistence
    visit "/public/bible/kjv/john/3"
    expect(page).to have_selector("[data-upvote-target='count']", text: "1")
  end

  it "admin features a note and the Featured badge appears on public bible" do
    note = public_note!(body: "Admin-worthy")
    sign_in admin

    visit "/admin/notes"
    click_button("Feature")

    visit "/public/bible/kjv/john/3"
    expect(page).to have_content(/featured/i)
    _ = note
  end

  it "admin hides a note and it disappears from anonymous public bible" do
    public_note!(body: "This will be hidden")
    sign_in admin
    visit "/admin/notes"
    # Hide button opens a turbo_confirm dialog; accept it via driver.
    page.accept_confirm do
      click_button("Hide")
    end

    # Verify admin still sees it (opacity-60 treatment)
    visit "/public/bible/kjv/john/3"
    expect(page).to have_content("This will be hidden")

    # Sign out; anonymous visitor should NOT see it.
    click_button "Sign out"
    # Wait for the signout redirect to settle before revisiting.
    expect(page).to have_link(text: /sign in/i)
    visit "/public/bible/kjv/john/3"
    expect(page).not_to have_content("This will be hidden")
  end

  it "flags a note and records the flag" do
    note = public_note!(body: "Spammy")
    sign_in reader
    visit "/public/bible/kjv/john/3"

    page.accept_prompt(with: "marketing content") do
      find("button[data-action='flag#prompt']").click
    end

    # Success alert fires; dismiss it.
    page.accept_alert

    expect(Flag.where(flaggable: note, user: reader)).to exist
  end
end
