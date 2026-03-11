require "rails_helper"

# End-to-end broadcast behavior: when the domain events happen, we
# emit Turbo Stream messages to the right group-chapter streams. Each
# test captures the broadcasts issued during a block and asserts their
# targets, operations, and counts.
RSpec.describe "Group bible broadcasts" do
  let(:owner)  { create(:user) }
  let(:member) { create(:user) }
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)    { create(:book, :john, translation: translation) }
  let!(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse)   do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   red_letter_ranges: [],
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let(:group) { create(:group, owner: owner) }

  before { create(:membership, user: member, group: group, role: :member) }

  def stream_name_for(group, translation_code = "KJV", book_osis = "John", chapter_number = 3)
    Turbo::StreamsChannel.send(:stream_name_from,
                               [ group, "bible", translation_code, book_osis, chapter_number ])
  end

  it "broadcasts verse replace + note append when a note is shared with the group" do
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: owner, body: "<p>The hinge.</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)

    expect {
      create(:note_share, note: note, shareable: group)
    }.to have_broadcasted_to(stream_name_for(group))
       .from_channel(Turbo::StreamsChannel)
       .at_least(:twice) # verse replace + note append
  end

  it "broadcasts verse replace + note remove when a share is destroyed" do
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: owner, body: "<p>Temporary</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)
    share = create(:note_share, note: note, shareable: group)

    expect {
      share.destroy!
    }.to have_broadcasted_to(stream_name_for(group))
       .from_channel(Turbo::StreamsChannel)
       .at_least(:twice)
  end

  it "does not broadcast when a share targets a user (direct share)" do
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: owner, body: "<p>Direct</p>", visibility: :shared_users)
    create(:highlight_note, highlight: highlight, note: note)

    expect {
      create(:note_share, note: note, shareable: member)
    }.not_to have_broadcasted_to(stream_name_for(group))
  end

  it "broadcasts to multiple groups when a note is shared with more than one" do
    other_group = create(:group, owner: owner)
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "rose")
    note = create(:note, user: owner, body: "<p>Multi</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)

    create(:note_share, note: note, shareable: group)

    expect {
      create(:note_share, note: note, shareable: other_group)
    }.to have_broadcasted_to(stream_name_for(other_group))
       .from_channel(Turbo::StreamsChannel)
       .at_least(:once)
  end

  it "broadcasts verse replace when a highlight's color changes and its note is group-shared" do
    highlight = create(:highlight, user: owner, translation: translation,
                                   osis_ref: "Bible.KJV.John.3.16", color: "gold")
    note = create(:note, user: owner, body: "<p>Change</p>", visibility: :shared_groups)
    create(:highlight_note, highlight: highlight, note: note)
    create(:note_share, note: note, shareable: group)

    expect {
      highlight.update!(color: "sage")
    }.to have_broadcasted_to(stream_name_for(group))
       .from_channel(Turbo::StreamsChannel)
       .at_least(:once)
  end
end
