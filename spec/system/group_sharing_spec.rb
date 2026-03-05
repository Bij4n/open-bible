require "rails_helper"

RSpec.describe "Group note sharing", type: :system, js: true do
  let(:alice) { create(:user, email: "alice@open-bible.test", display_name: "Alice") }
  let(:bob)   { create(:user, email: "bob@open-bible.test") }
  let!(:translation) { create(:translation, :kjv) }
  let!(:book) { create(:book, :john, translation: translation) }
  let!(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let(:group) { create(:group, owner: alice, name: "Morning Study") }

  before { create(:membership, user: bob, group: group, role: :member) }

  it "shows a note shared with the group to every member" do
    highlight = create(:highlight, user: alice, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: alice, body: "<p>The hinge of the gospel.</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)
    create(:note_share, note: note, shareable: group)

    sign_in bob
    visit "/groups/#{group.id}/bible/kjv/john/3"

    expect(page).to have_content("For God so loved the world")
    expect(page).to have_content("The hinge of the gospel")
    expect(page).to have_content(/by Alice/i)
  end

  it "does not leak the note to a non-member" do
    non_member = create(:user)
    highlight = create(:highlight, user: alice, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: alice, body: "<p>Private to group</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)
    create(:note_share, note: note, shareable: group)

    sign_in non_member
    visit "/groups/#{group.id}/bible/kjv/john/3"
    # Selenium can't read HTTP status directly; just verify the note
    # never paints and the chapter body isn't rendered for non-members.
    expect(page).not_to have_content("Private to group")
    expect(page).not_to have_content("For God so loved the world")
  end
end
