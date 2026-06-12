require "rails_helper"

RSpec.describe NotesHelper, type: :helper do
  describe "#visibility_glyph" do
    it "renders a glyph with an accessible label for every visibility" do
      Note::VISIBILITIES.keys.each do |v|
        note = build(:note, visibility: v)
        html = helper.visibility_glyph(note)
        expect(html).to include("<svg"), "no svg for #{v}"
        expect(html).to include(I18n.t("notes.visibility.#{v}")), "no label for #{v}"
        expect(html).to include("sr-only")
      end
    end

    it "titles the glyph so sighted users get the tooltip too" do
      note = build(:note, visibility: :friends_note)
      expect(helper.visibility_glyph(note)).to include(%(title="#{I18n.t("notes.visibility.friends_note")}"))
    end
  end
end
