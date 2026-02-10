require "rails_helper"

RSpec.describe Book, type: :model do
  describe "validations" do
    subject { build(:book) }

    it { is_expected.to validate_presence_of(:osis_code) }
    it { is_expected.to validate_presence_of(:name_en) }
    it { is_expected.to validate_presence_of(:name_es) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_presence_of(:testament) }

    it "requires osis_code uniqueness scoped to translation" do
      translation = create(:translation)
      create(:book, translation: translation, osis_code: "Gen", position: 1)
      dup = build(:book, translation: translation, osis_code: "Gen", position: 2)
      expect(dup).not_to be_valid
      expect(dup.errors[:osis_code]).to be_present
    end

    it "allows the same osis_code in a different translation" do
      t1 = create(:translation, code: "KJV")
      t2 = create(:translation, code: "RV1909")
      create(:book, translation: t1, osis_code: "Gen", position: 1)
      other = build(:book, translation: t2, osis_code: "Gen", position: 1)
      expect(other).to be_valid
    end

    it "requires position uniqueness scoped to translation" do
      translation = create(:translation)
      create(:book, translation: translation, osis_code: "Gen", position: 1)
      dup = build(:book, translation: translation, osis_code: "Exod", position: 1)
      expect(dup).not_to be_valid
      expect(dup.errors[:position]).to be_present
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:translation) }
  end

  describe "testament enum" do
    it "accepts :old and :new" do
      expect(build(:book, testament: :old)).to be_valid
      expect(build(:book, testament: :new)).to be_valid
    end
  end

  describe ".ordered" do
    it "returns books in canonical position order" do
      translation = create(:translation)
      revelation = create(:book, translation: translation, osis_code: "Rev", position: 66)
      genesis = create(:book, translation: translation, osis_code: "Gen", position: 1)
      expect(translation.books.ordered).to eq([ genesis, revelation ])
    end
  end
end
