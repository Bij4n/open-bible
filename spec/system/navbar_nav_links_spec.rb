require "rails_helper"

# Top-level nav IA (design v3): Read · Studies · Community · Search.
# Read and Community are public; Studies appears when signed in, How it
# works when signed out. "My notes" moves out of the rail into the
# account menu.
# rack_test driver — these are plain HTML links, no JS required.
# Rail links are direct children of the header nav element; account-menu
# entries live deeper inside [role="menu"], which is how the assertions
# distinguish the two (rack_test doesn't apply CSS visibility).
RSpec.describe "Navbar nav links", type: :system do
  context "when signed out" do
    it "shows the Read link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.read_link"), href: bible_entry_path)
      end
    end

    it "shows the Community link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.community_link"), href: "/public/bible")
      end
    end

    it "shows the How it Works link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.how_it_works_link"), href: how_it_works_path)
      end
    end

    it "does not show the Studies link" do
      visit "/"
      within("header nav") do
        expect(page).not_to have_link(I18n.t("layout.studies_link"), href: groups_path)
      end
    end
  end

  context "when signed in" do
    before { sign_in create(:user) }

    it "does not show the How it Works link in the header nav" do
      visit "/"
      within("header nav") do
        expect(page).not_to have_link(I18n.t("layout.how_it_works_link"), href: how_it_works_path)
      end
    end

    it "shows the Read link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.read_link"), href: bible_entry_path)
      end
    end

    it "shows the Studies link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.studies_link"), href: groups_path)
      end
    end

    it "shows the Community link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.community_link"), href: "/public/bible")
      end
    end

    it "keeps My notes out of the nav rail" do
      visit "/"
      expect(page).not_to have_css("header nav > a[href='#{notes_path}']")
    end

    it "puts My notes in the account menu" do
      visit "/"
      # The menu carries the `hidden` attribute until its Stimulus
      # controller opens it; rack_test never runs that JS, so look
      # through the hidden container.
      within("[role='menu']", visible: :all) do
        expect(page).to have_link(I18n.t("layout.my_notes_link"), href: notes_path, visible: :all)
      end
    end

    it "marks the Studies link active when on /groups" do
      visit groups_path
      within("header nav") do
        link = find_link(I18n.t("layout.studies_link"))
        expect(link[:class]).to include("decoration-accent-700/40")
      end
    end

    it "does not mark the Studies link active on /" do
      visit "/"
      within("header nav") do
        link = find_link(I18n.t("layout.studies_link"))
        expect(link[:class]).not_to include("decoration-accent-700/40")
      end
    end

    it "does not mark the Read link active on /" do
      visit "/"
      within("header nav") do
        link = find_link(I18n.t("layout.read_link"))
        expect(link[:class]).not_to include("decoration-accent-700/40")
      end
    end
  end
end
