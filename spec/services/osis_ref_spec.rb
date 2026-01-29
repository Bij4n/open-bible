require "rails_helper"

RSpec.describe OsisRef do
  describe ".parse" do
    context "valid grammar forms" do
      it "parses a single verse" do
        ref = described_class.parse("Bible.KJV.John.3.16")
        expect(ref.translation_code).to eq("KJV")
        expect(ref.start_book).to eq("John")
        expect(ref.start_chapter).to eq(3)
        expect(ref.start_verse).to eq(16)
        expect(ref.start_offset).to be_nil
        expect(ref.end_book).to eq("John")
        expect(ref.end_chapter).to eq(3)
        expect(ref.end_verse).to eq(16)
        expect(ref.end_offset).to be_nil
      end

      it "parses a multi-verse span within a chapter" do
        ref = described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.3.18")
        expect(ref.start_verse).to eq(16)
        expect(ref.end_verse).to eq(18)
        expect(ref).to be_cross_verse
      end

      it "parses a character range within a single verse" do
        ref = described_class.parse("Bible.KJV.John.3.16!12-Bible.KJV.John.3.16!45")
        expect(ref.start_offset).to eq(12)
        expect(ref.end_offset).to eq(45)
        expect(ref).not_to be_cross_verse
      end

      it "parses a character range across verses" do
        ref = described_class.parse("Bible.KJV.John.3.16!12-Bible.KJV.John.3.17!45")
        expect(ref.start_verse).to eq(16)
        expect(ref.end_verse).to eq(17)
        expect(ref.start_offset).to eq(12)
        expect(ref.end_offset).to eq(45)
      end

      it "treats !end as an end-of-verse sentinel" do
        ref = described_class.parse("Bible.KJV.John.3.16!12-Bible.KJV.John.3.16!end")
        expect(ref.start_offset).to eq(12)
        expect(ref.end_offset).to eq(:end)
      end

      it "accepts offset 0" do
        ref = described_class.parse("Bible.KJV.John.3.16!0-Bible.KJV.John.3.16!5")
        expect(ref.start_offset).to eq(0)
        expect(ref.end_offset).to eq(5)
      end

      it "handles multi-character book osis codes" do
        ref = described_class.parse("Bible.KJV.1Kgs.1.1")
        expect(ref.start_book).to eq("1Kgs")
      end

      it "handles large verse numbers (Psalm 119)" do
        ref = described_class.parse("Bible.KJV.Ps.119.176")
        expect(ref.start_chapter).to eq(119)
        expect(ref.start_verse).to eq(176)
      end

      it "trims surrounding whitespace" do
        ref = described_class.parse("  Bible.KJV.John.3.16  ")
        expect(ref.to_s).to eq("Bible.KJV.John.3.16")
      end
    end

    context "malformed input" do
      it "raises on empty string" do
        expect { described_class.parse("") }.to raise_error(OsisRef::ParseError)
      end

      it "raises on missing Bible. prefix" do
        expect { described_class.parse("KJV.John.3.16") }.to raise_error(OsisRef::ParseError)
      end

      it "raises on wrong separators" do
        expect { described_class.parse("BibleKJV.John.3.16") }.to raise_error(OsisRef::ParseError)
      end

      it "raises on negative offset" do
        expect { described_class.parse("Bible.KJV.John.3.16!-5") }.to raise_error(OsisRef::ParseError)
      end

      it "raises on non-integer offset" do
        expect { described_class.parse("Bible.KJV.John.3.16!abc") }.to raise_error(OsisRef::ParseError)
      end

      it "raises on non-integer verse" do
        expect { described_class.parse("Bible.KJV.John.x.16") }.to raise_error(OsisRef::ParseError)
      end

      it "raises when endpoint translations mismatch" do
        expect { described_class.parse("Bible.KJV.John.3.16-Bible.RV.John.3.18") }
          .to raise_error(OsisRef::ParseError, /translation/i)
      end

      it "raises on backwards verses" do
        expect { described_class.parse("Bible.KJV.John.3.18-Bible.KJV.John.3.16") }
          .to raise_error(OsisRef::ParseError, /backwards/i)
      end

      it "raises on backwards offsets within the same verse" do
        expect { described_class.parse("Bible.KJV.John.3.16!20-Bible.KJV.John.3.16!10") }
          .to raise_error(OsisRef::ParseError, /backwards/i)
      end
    end
  end

  describe "predicates" do
    it "#single_verse? is true for a bare verse ref" do
      expect(described_class.parse("Bible.KJV.John.3.16")).to be_single_verse
    end

    it "#single_verse? is false for a multi-verse span" do
      expect(described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.3.17")).not_to be_single_verse
    end

    it "#cross_verse? is true only when start and end verses differ" do
      expect(described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.3.17")).to be_cross_verse
      expect(described_class.parse("Bible.KJV.John.3.16!1-Bible.KJV.John.3.16!5")).not_to be_cross_verse
    end

    it "#same_chapter? is true within one chapter" do
      expect(described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.3.17")).to be_same_chapter
    end

    it "#same_chapter? is false across chapters" do
      expect(described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.4.1")).not_to be_same_chapter
    end
  end

  describe "#verse_osis_refs" do
    it "returns a single ref for a bare verse" do
      refs = described_class.parse("Bible.KJV.John.3.16").verse_osis_refs
      expect(refs).to eq([ "Bible.KJV.John.3.16" ])
    end

    it "enumerates every verse in a same-chapter span" do
      refs = described_class.parse("Bible.KJV.John.3.14-Bible.KJV.John.3.17").verse_osis_refs
      expect(refs).to eq([
        "Bible.KJV.John.3.14",
        "Bible.KJV.John.3.15",
        "Bible.KJV.John.3.16",
        "Bible.KJV.John.3.17"
      ])
    end

    it "raises when the ref crosses chapters (can't enumerate without DB)" do
      ref = described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.4.1")
      expect { ref.verse_osis_refs }.to raise_error(OsisRef::MultiChapterNotSupported)
    end
  end

  describe "#to_s" do
    it "round-trips every normalized form" do
      [
        "Bible.KJV.John.3.16",
        "Bible.KJV.John.3.16-Bible.KJV.John.3.17",
        "Bible.KJV.John.3.16!12-Bible.KJV.John.3.16!45",
        "Bible.KJV.John.3.16!12-Bible.KJV.John.3.17!45",
        "Bible.KJV.John.3.16!12-Bible.KJV.John.3.16!end",
        "Bible.KJV.1Kgs.1.1",
        "Bible.KJV.Ps.119.176"
      ].each do |str|
        expect(described_class.parse(str).to_s).to eq(str), "expected #{str.inspect} to round-trip"
      end
    end
  end

  describe "strict mode" do
    it "raises ScopeError when strict: :same_chapter and ref crosses chapters" do
      expect {
        described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.4.1", strict: :same_chapter)
      }.to raise_error(OsisRef::ScopeError)
    end

    it "accepts same-chapter refs under strict :same_chapter" do
      expect {
        described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.3.17", strict: :same_chapter)
      }.not_to raise_error
    end

    it "ScopeError is a subclass of ParseError for rescue purposes" do
      expect(OsisRef::ScopeError.ancestors).to include(OsisRef::ParseError)
    end

    it "permissive parse (default) allows cross-chapter refs" do
      ref = described_class.parse("Bible.KJV.John.3.16-Bible.KJV.John.4.1")
      expect(ref).not_to be_same_chapter
    end
  end

  describe ".build" do
    it "returns an equivalent OsisRef from the keyword form" do
      ref = described_class.build(
        translation_code: "KJV",
        start: { book: "John", chapter: 3, verse: 16, offset: 12 },
        end: { book: "John", chapter: 3, verse: 17, offset: 45 }
      )
      expect(ref.to_s).to eq("Bible.KJV.John.3.16!12-Bible.KJV.John.3.17!45")
    end

    it "defaults to single-verse ref when end is omitted" do
      ref = described_class.build(
        translation_code: "KJV",
        start: { book: "John", chapter: 3, verse: 16 }
      )
      expect(ref.to_s).to eq("Bible.KJV.John.3.16")
      expect(ref).to be_single_verse
    end
  end

  describe "equality" do
    it "treats two refs with the same string as equal" do
      a = described_class.parse("Bible.KJV.John.3.16")
      b = described_class.parse("Bible.KJV.John.3.16")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "treats refs with different strings as distinct" do
      a = described_class.parse("Bible.KJV.John.3.16")
      b = described_class.parse("Bible.KJV.John.3.17")
      expect(a).not_to eq(b)
    end
  end
end
