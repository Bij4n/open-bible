require "rails_helper"

RSpec.describe "Legal pages", type: :system do
  describe "Terms of Use" do
    it "renders the terms page for a guest" do
      visit terms_path
      expect(page).to have_text("Terms of Use")
    end

    it "renders the terms page for a signed-in user" do
      sign_in create(:user)
      visit terms_path
      expect(page).to have_text("Terms of Use")
    end

    it "links back to the privacy page" do
      visit terms_path
      expect(page).to have_link("Privacy Policy", href: privacy_path)
    end
  end

  describe "Privacy Policy" do
    it "renders the privacy page for a guest" do
      visit privacy_path
      expect(page).to have_text("Privacy Policy")
    end

    it "renders the privacy page for a signed-in user" do
      sign_in create(:user)
      visit privacy_path
      expect(page).to have_text("Privacy Policy")
    end

    it "links back to the terms page" do
      visit privacy_path
      expect(page).to have_link("Terms of Use", href: terms_path)
    end
  end

  describe "Footer links" do
    it "shows Terms and Privacy links in the footer for guests" do
      visit root_path
      within("footer nav") do
        expect(page).to have_link("Terms of Use", href: terms_path)
        expect(page).to have_link("Privacy Policy", href: privacy_path)
      end
    end

    it "shows Terms and Privacy links in the footer for signed-in users" do
      sign_in create(:user)
      visit root_path
      within("footer nav") do
        expect(page).to have_link("Terms of Use", href: terms_path)
        expect(page).to have_link("Privacy Policy", href: privacy_path)
      end
    end
  end
end
