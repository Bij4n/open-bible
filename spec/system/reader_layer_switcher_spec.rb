require "rails_helper"

# Design-v3 reader layers: the reader shows one lens at a time — your
# own markup, one of your studies' shared layers, or the community
# layer. The switcher is a nav_select that navigates between the three
# existing reader surfaces, preserving translation/book/chapter.
# rack_test — options render as buttons with data-url inside the
# (hidden) listbox; the nav_select JS only handles open/visit.
RSpec.describe "Reader layer switcher", type: :system do
  let(:user) { create(:user) }
  let(:translation) { create(:translation, :kjv) }
  let(:book) { create(:book, :john, translation: translation) }
  let(:chapter) { create(:chapter, book: book, number: 3) }
  let!(:verse) do
    create(:verse, chapter: chapter, number: 16,
                   body_text: "For God so loved the world",
                   body_html: "For God so loved the world",
                   osis_ref: "Bible.KJV.John.3.16")
  end
  let!(:group) { create(:group, name: "Wednesday Study", owner: user) }

  def option_selector(url)
    "button[data-action='nav-select#select'][data-url='#{url}']"
  end

  context "signed in, on the personal reader" do
    before { sign_in user }

    it "offers Mine, each study, and Community for the same chapter" do
      visit "/bible/kjv/john/3"

      expect(page).to have_css(option_selector("/bible/kjv/john/3"), text: I18n.t("bible.reader.layer_mine"), visible: :all)
      expect(page).to have_css(option_selector("/groups/#{group.id}/bible/kjv/john/3"), text: "Wednesday Study", visible: :all)
      expect(page).to have_css(option_selector("/public/bible/kjv/john/3"), text: I18n.t("bible.reader.layer_community"), visible: :all)
    end

    it "marks the group layer selected on the group bible view" do
      visit "/groups/#{group.id}/bible/kjv/john/3"

      expect(page).to have_css("#{option_selector("/groups/#{group.id}/bible/kjv/john/3")}[aria-selected='true']", visible: :all)
    end

    it "marks Community selected on the public bible view" do
      visit "/public/bible/kjv/john/3"

      expect(page).to have_css("#{option_selector("/public/bible/kjv/john/3")}[aria-selected='true']", visible: :all)
    end
  end

  it "renders no layer switcher for signed-out visitors" do
    visit "/public/bible/kjv/john/3"

    expect(page).not_to have_css(option_selector("/bible/kjv/john/3"), visible: :all)
  end
end
