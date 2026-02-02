require "rails_helper"

RSpec.describe Note, ".visible_to" do
  let(:alice) { create(:user) }
  let(:bob)   { create(:user) }
  let(:carol) { create(:user) }

  let!(:alice_private) { create(:note, user: alice, visibility: :private_note) }
  let!(:bob_private)   { create(:note, user: bob,   visibility: :private_note) }
  let!(:public_one)    { create(:note, user: bob,   visibility: :public_note) }

  it "returns the user's own notes" do
    expect(Note.visible_to(alice)).to include(alice_private)
  end

  it "excludes other users' private notes" do
    expect(Note.visible_to(alice)).not_to include(bob_private)
  end

  it "includes notes shared directly with the user" do
    bob_to_alice = create(:note, user: bob, visibility: :shared_users)
    create(:note_share, note: bob_to_alice, shareable: alice)
    expect(Note.visible_to(alice)).to include(bob_to_alice)
  end

  it "includes notes shared with a group the user belongs to" do
    group = create(:group, owner: bob)
    create(:membership, user: alice, group: group, role: :member)
    bob_to_group = create(:note, user: bob, visibility: :shared_groups)
    create(:note_share, note: bob_to_group, shareable: group)
    expect(Note.visible_to(alice)).to include(bob_to_group)
  end

  it "excludes notes shared with groups the user doesn't belong to" do
    other_group = create(:group, owner: carol)
    bob_to_other = create(:note, user: bob, visibility: :shared_groups)
    create(:note_share, note: bob_to_other, shareable: other_group)
    expect(Note.visible_to(alice)).not_to include(bob_to_other)
  end

  it "includes public notes" do
    expect(Note.visible_to(alice)).to include(public_one)
  end

  it "returns nothing for nil (anonymous)" do
    expect(Note.visible_to(nil)).to be_empty
  end

  it "dedupes when a note is shared via multiple paths" do
    group = create(:group, owner: bob)
    create(:membership, user: alice, group: group, role: :member)
    double_shared = create(:note, user: bob, visibility: :shared_users)
    create(:note_share, note: double_shared, shareable: alice)
    create(:note_share, note: double_shared, shareable: group)

    results = Note.visible_to(alice).where(id: double_shared.id)
    expect(results.count).to eq(1)
  end
end
