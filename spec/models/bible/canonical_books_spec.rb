require "rails_helper"

RSpec.describe Bible::CanonicalBooks do
  before { described_class.reset! }

  describe ".all" do
    it "returns 66 canonical books" do
      expect(described_class.all.size).to eq(66)
    end

    it "preserves canonical order" do
      expect(described_class.all.first[:osis_code]).to eq("Gen")
      expect(described_class.all.last[:osis_code]).to eq("Rev")
    end

    it "assigns positions 1 through 66 with no gaps" do
      positions = described_class.all.map { |b| b[:position] }
      expect(positions).to eq((1..66).to_a)
    end

    it "splits 39 old + 27 new" do
      testaments = described_class.all.group_by { |b| b[:testament] }.transform_values(&:size)
      expect(testaments).to eq("old" => 39, "new" => 27)
    end

    it "excludes the apocrypha" do
      apocryphal = %w[Tob Jdt EsthGr Wis Sir Bar EpJer PrAzar Sus Bel 1Macc 2Macc 1Esd PrMan 2Esd]
      described_class.osis_codes.each do |code|
        expect(apocryphal).not_to include(code), "#{code} is apocryphal and should not be in the canon list"
      end
    end

    it "requires all books to carry English and Spanish names" do
      described_class.all.each do |book|
        expect(book[:name_en]).to be_present, "missing name_en for #{book[:osis_code]}"
        expect(book[:name_es]).to be_present, "missing name_es for #{book[:osis_code]}"
      end
    end
  end

  describe ".find" do
    it "returns the book for a known osis_code" do
      john = described_class.find("John")
      expect(john).to include(osis_code: "John", name_en: "John", name_es: "Juan", position: 43, testament: "new")
    end

    it "returns nil for an apocryphal code" do
      expect(described_class.find("Tob")).to be_nil
    end
  end

  describe ".osis_codes" do
    it "returns all 66 codes in canonical order" do
      codes = described_class.osis_codes
      expect(codes.first).to eq("Gen")
      expect(codes.last).to eq("Rev")
      expect(codes.size).to eq(66)
    end
  end
end
