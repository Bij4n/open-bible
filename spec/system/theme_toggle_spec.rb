require "rails_helper"

RSpec.describe "Theme toggle", type: :system, js: true do
  it "flips data-theme on click and persists the choice across reloads" do
    visit "/"

    # Deterministic starting point — prefers-color-scheme varies between
    # headless browser versions, and we want to assert the toggle itself.
    page.execute_script(
      "localStorage.setItem('open-bible:theme', 'light');" \
      "document.documentElement.dataset.theme = 'light';"
    )
    expect(page).to have_css(%(html[data-theme="light"]))

    # Theme toggle moved into the Account-menu dropdown in the Sprint
    # 12 navbar rewrite; open the menu before clicking it.
    open_account_menu
    find("button[data-action='theme#toggle']").click

    expect(page).to have_css(%(html[data-theme="dark"]))
    stored = page.evaluate_script("localStorage.getItem('open-bible:theme')")
    expect(stored).to eq("dark")

    visit "/"
    expect(page).to have_css(%(html[data-theme="dark"]))
  end

  it "cycles light → dark → system → light on successive clicks" do
    visit "/"
    page.execute_script(
      "localStorage.setItem('open-bible:theme', 'light');" \
      "document.documentElement.dataset.theme = 'light';"
    )

    open_account_menu
    button = find("button[data-action='theme#toggle']")

    button.click
    expect(page.evaluate_script("localStorage.getItem('open-bible:theme')")).to eq("dark")

    button.click
    expect(page.evaluate_script("localStorage.getItem('open-bible:theme')")).to eq("system")

    button.click
    expect(page.evaluate_script("localStorage.getItem('open-bible:theme')")).to eq("light")
    expect(page).to have_css(%(html[data-theme="light"]))
  end
end
