require "rails_helper"

# Groups discover page — publicly accessible directory of open groups.
# Open groups appear; private and invite-only do not. Signed-in users
# can join directly. Guests see the page but are sent to sign-in on join.
# rack_test driver — no JS needed, all server-side.
RSpec.describe "Groups discover", type: :system do
  let!(:open_group)        { create(:group, :open_group,    name: "Genesis Study") }
  let!(:invite_only_group) { create(:group,                 name: "Invite Only Group") }
  let!(:private_group)     { create(:group, :private_group, name: "Private Group") }

  describe "guest access" do
    it "renders the discover page without authentication" do
      visit discover_groups_path
      expect(page).to have_content(I18n.t("groups.discover_title"))
    end

    it "shows open groups" do
      visit discover_groups_path
      expect(page).to have_content("Genesis Study")
    end

    it "does not show invite-only groups" do
      visit discover_groups_path
      expect(page).not_to have_content("Invite Only Group")
    end

    it "does not show private groups" do
      visit discover_groups_path
      expect(page).not_to have_content("Private Group")
    end

    it "shows the join button linking to sign-in for guests" do
      visit discover_groups_path
      expect(page).to have_link(I18n.t("groups.join_open"), href: new_user_session_path)
    end
  end

  describe "signed-in user" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "shows the join button for groups the user hasn't joined" do
      visit discover_groups_path
      expect(page).to have_button(I18n.t("groups.join_open"))
    end

    it "joins an open group and redirects to the group page" do
      visit discover_groups_path
      click_button I18n.t("groups.join_open")

      expect(page).to have_current_path(group_path(open_group))
      expect(page).to have_content(I18n.t("groups.joined"))
      expect(open_group.reload.member?(user)).to be true
    end

    it "shows a 'Read Bible' link instead of join for groups the user is already in" do
      open_group.memberships.create!(user: user, role: :member)
      visit discover_groups_path
      expect(page).to have_link(I18n.t("groups.bible"))
      expect(page).not_to have_button(I18n.t("groups.join_open"))
    end
  end

  describe "empty state" do
    before { open_group.destroy }

    it "shows the empty state message when no open groups exist" do
      visit discover_groups_path
      expect(page).to have_content(I18n.t("groups.discover_empty"))
    end
  end
end
