require "rails_helper"

RSpec.describe Follow, type: :model do
  let(:alice) { create(:user) }
  let(:bob)   { create(:user) }

  it "links a follower to a followed user" do
    follow = Follow.create!(follower: alice, followed: bob)
    expect(follow.follower).to eq(alice)
    expect(follow.followed).to eq(bob)
  end

  it "rejects duplicate follows of the same user" do
    Follow.create!(follower: alice, followed: bob)
    dup = Follow.new(follower: alice, followed: bob)
    expect(dup).not_to be_valid
  end

  it "rejects self-follows at the model layer" do
    follow = Follow.new(follower: alice, followed: alice)
    expect(follow).not_to be_valid
    expect(follow.errors[:followed]).to be_present
  end

  it "rejects self-follows at the database layer too" do
    follow = Follow.new(follower: alice, followed: alice)
    expect {
      follow.save(validate: false)
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  describe "User follow API" do
    it "follow!/unfollow!/following? round-trip" do
      expect(alice.following?(bob)).to be false

      alice.follow!(bob)
      expect(alice.following?(bob)).to be true
      expect(alice.following).to include(bob)
      expect(bob.followers).to include(alice)

      alice.unfollow!(bob)
      expect(alice.following?(bob)).to be false
    end

    it "follow! is idempotent" do
      alice.follow!(bob)
      expect { alice.follow!(bob) }.not_to change(Follow, :count)
    end

    it "friends are exactly the mutual follows" do
      carol = create(:user)
      alice.follow!(bob)        # one-way: not friends
      alice.follow!(carol)
      carol.follow!(alice)      # mutual: friends

      expect(alice.friends).to contain_exactly(carol)
      expect(alice.friends_with?(carol)).to be true
      expect(alice.friends_with?(bob)).to be false
      expect(carol.friends).to contain_exactly(alice)
      expect(bob.friends).to be_empty
    end

    it "destroying a user removes their follow rows in both directions" do
      alice.follow!(bob)
      bob.follow!(alice)
      expect { bob.destroy! }.to change(Follow, :count).by(-2)
    end
  end
end
