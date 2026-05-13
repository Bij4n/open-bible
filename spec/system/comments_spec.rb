require "rails_helper"

RSpec.describe "Comments", type: :system, js: true do
  let(:owner)  { create(:user, display_name: "Alice") }
  let(:member) { create(:user) }
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
  let(:group) { create(:group, owner: owner) }
  let(:note) do
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: owner, body: "<p>Seed thought.</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)
    create(:note_share, note: note, shareable: group)
    note
  end

  before { create(:membership, user: member, group: group, role: :member) }

  it "adds a comment to a group-shared note and shows it in the thread" do
    sign_in member
    note # trigger creation

    visit "/groups/#{group.id}/bible/kjv/john/3"
    expect(page).to have_content("Seed thought")

    fill_in "comment[body]", with: "Well said.", match: :first
    # Submit the top-level (not reply) form — it's the first one rendered.
    within "##{ActionView::RecordIdentifier.dom_id(note)}" do
      first("form").find("input[type=submit]").click
    end

    expect(page).to have_content("Well said.")
    expect(Comment.where(note: note, user: member, body: "Well said.")).to exist
  end

  it "indents replies under their parent with depth-based margin" do
    sign_in owner
    top = create(:comment, note: note, user: owner, body: "Original")
    reply = create(:comment, note: note, user: member, parent: top, body: "Response")

    visit "/groups/#{group.id}/bible/kjv/john/3"

    reply_el = find("##{ActionView::RecordIdentifier.dom_id(reply)}", visible: :all)
    style = reply_el[:style]
    expect(style).to include("margin-left: 20px")
  end

  it "shows the reply form when Reply is clicked", js: true do
    sign_in owner
    create(:comment, note: note, user: owner, body: "Seed comment")

    # Visit the note page directly — much lighter than the full group
    # Bible chapter (no verse rendering or highlight computation).
    visit note_path(note)
    expect(page).to have_content("Seed comment")

    # Reply form starts hidden.
    expect(page).to have_css("[data-comment-target='replyForm']", visible: false)

    find("[data-action='comment#toggleReply']").click

    # After toggle the form is visible and the textarea is focused.
    expect(page).to have_css("[data-comment-target='replyForm']", visible: true)
    expect(page.evaluate_script("document.activeElement.tagName")).to eq("TEXTAREA")
  end

  it "hides edit/delete for other users' comments" do
    create(:comment, note: note, user: owner, body: "Owner says so")
    sign_in member
    visit "/groups/#{group.id}/bible/kjv/john/3"
    expect(page).to have_content("Owner says so")
    expect(page).not_to have_selector("input[value='Delete']")
  end
end
