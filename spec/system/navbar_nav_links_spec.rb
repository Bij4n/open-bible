require "rails_helper"

# Top-level nav links for signed-in users — Notes and Groups appear in
# the nav rail when authenticated; absent for guests.
# rack_test driver — these are plain HTML links, no JS required.
# The links use `hidden sm:inline-block` for responsive display, but
# rack_test doesn't apply CSS so we assert DOM presence regardless of
# viewport width.
RSpec.describe "Navbar signed-in links", type: :system do
  context "when signed out" do
    it "does not show the Notes link" do
      visit "/"
      within("header nav") do
        expect(page).not_to have_link(I18n.t("layout.my_notes_link"), href: notes_path)
      end
    end

    it "does not show the Groups link" do
      visit "/"
      within("header nav") do
        expect(page).not_to have_link(I18n.t("layout.my_groups_link"), href: groups_path)
      end
    end

    it "shows the How it Works link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.how_it_works_link"), href: how_it_works_path)
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

    it "shows the Notes link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.my_notes_link"), href: notes_path)
      end
    end

    it "shows the Groups link" do
      visit "/"
      within("header nav") do
        expect(page).to have_link(I18n.t("layout.my_groups_link"), href: groups_path)
      end
    end

    it "marks the Notes link active when on /notes" do
      visit notes_path
      within("header nav") do
        link = find_link(I18n.t("layout.my_notes_link"))
        expect(link[:class]).to include("decoration-accent-700/40")
      end
    end

    it "marks the Groups link active when on /groups" do
      visit groups_path
      within("header nav") do
        link = find_link(I18n.t("layout.my_groups_link"))
        expect(link[:class]).to include("decoration-accent-700/40")
      end
    end

    it "does not mark the Notes link active on /" do
      visit "/"
      within("header nav") do
        link = find_link(I18n.t("layout.my_notes_link"))
        expect(link[:class]).not_to include("decoration-accent-700/40")
      end
    end
  end
end
