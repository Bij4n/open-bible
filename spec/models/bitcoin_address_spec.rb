require "rails_helper"

RSpec.describe BitcoinAddress, type: :model do
  describe "validations" do
    it "requires an address" do
      expect(BitcoinAddress.new(address: nil)).not_to be_valid
    end

    it "rejects addresses shorter than 20 chars" do
      short = BitcoinAddress.new(address: "bc1qtooShort")
      expect(short).not_to be_valid
      expect(short.errors[:address]).to be_present
    end

    it "accepts addresses within the length window" do
      ok = BitcoinAddress.new(address: "bc1qexampletestaddressforvalidation12345678")
      expect(ok).to be_valid
    end

    it "rejects addresses longer than 128 chars" do
      too_long = BitcoinAddress.new(address: "a" * 129)
      expect(too_long).not_to be_valid
    end

    it "caps notes at 1000 chars" do
      a = BitcoinAddress.new(address: "bc1qexampletestaddressforspecs00000001", notes: "x" * 1001)
      expect(a).not_to be_valid
    end
  end

  describe ".current" do
    it "returns the row marked active" do
      create(:bitcoin_address, :archived)
      active = create(:bitcoin_address, :active)

      expect(BitcoinAddress.current).to eq(active)
    end

    it "returns nil when no row is active" do
      create(:bitcoin_address, :archived)
      expect(BitcoinAddress.current).to be_nil
    end
  end

  describe ".rotate_to!" do
    it "creates the new row as active and archives the previous active" do
      previous = create(:bitcoin_address, :active)

      new_address = BitcoinAddress.rotate_to!(address: "bc1qbrandnewaddressfortesting12345", notes: "ledger live / acct 4")

      expect(new_address).to be_persisted
      expect(new_address.active).to be true
      expect(new_address.notes).to eq("ledger live / acct 4")

      expect(previous.reload.active).to be false
      expect(previous.archived_at).to be_present
    end

    it "creates the row as active when no previous row exists" do
      expect(BitcoinAddress.count).to eq(0)

      new_address = BitcoinAddress.rotate_to!(address: "bc1qfirstaddressrotation0000000001")

      expect(new_address.active).to be true
      expect(BitcoinAddress.current).to eq(new_address)
    end

    it "rolls back the archive when the new row's validation fails" do
      previous = create(:bitcoin_address, :active)

      expect {
        BitcoinAddress.rotate_to!(address: "tooShort")
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(previous.reload.active).to be(true), "previous should still be active after rollback"
      expect(previous.archived_at).to be_nil
    end
  end

  describe "DB-level partial unique index on active = true" do
    it "rejects a second active row inserted directly" do
      create(:bitcoin_address, :active)

      expect {
        # Bypass the rotate_to! flow to hit the index directly.
        BitcoinAddress.new(address: "bc1qsecondactivewouldcollide00000", active: true).save!(validate: true)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
