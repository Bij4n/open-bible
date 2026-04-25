require "rails_helper"

RSpec.describe "Settings preferences", type: :system, js: true do
  let(:user) { create(:user, email: "reader@open-bible.test", ui_locale: "en", theme: "system") }

  before { sign_in user }

  it "persists a signed-in user's theme choice across reloads without flash" do
    visit "/settings"
    choose "Dark"

    # Wait for the frame to swap in the saved-indicator before asserting
    # DB state — otherwise we race the Turbo fetch.
    expect(page).to have_content(/preferences saved/i)
    expect(user.reload.theme).to eq("dark")

    # On a fresh page load, the server should render with data-theme=dark
    # immediately (first-paint, before JS runs).
    visit "/"
    expect(page).to have_css(%(html[data-theme="dark"]))
  end

  it "persists a signed-in user's language choice across reloads" do
    visit "/settings"
    choose "Español"

    expect(page).to have_content(/preferences saved|preferencias guardadas/i)
    expect(user.reload.ui_locale).to eq("es")

    visit "/"
    expect(page).to have_content(/donde los versículos encuentran voz/i)
    expect(page).to have_css("html[lang='es']")
  end

  it "persists signed-out language switching via session" do
    sign_out user
    visit "/"
    expect(page).to have_content(/where verses meet voices/i)

    # Language pills moved into the Account-menu dropdown in the
    # Sprint 12 navbar rewrite; they still render as <a> for signed-out
    # users so click_on still works, but the menu has to be open first.
    open_account_menu
    click_on "Español"
    expect(page).to have_content(/donde los versículos encuentran voz/i)

    # Navigate elsewhere without carrying a locale param — session should
    # still apply.
    visit "/users/sign_in"
    expect(page).to have_css("html[lang='es']")
  end
end
