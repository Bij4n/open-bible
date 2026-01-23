require "rails_helper"

RSpec.describe "Theme toggle", type: :system, js: true do
  it "flips data-theme on click and persists the choice across reloads" do
    visit "/"

    # Deterministic starting point — prefers-color-scheme varies between
    # headless Chrome versions, and we want to assert the toggle itself.
    page.execute_script(
      "localStorage.setItem('open-bible:theme', 'light');" \
      "document.documentElement.dataset.theme = 'light';"
    )
    expect(page).to have_css(%(html[data-theme="light"]))

    find("button[data-action='theme#toggle']").click

    expect(page).to have_css(%(html[data-theme="dark"]))
    stored = page.evaluate_script("localStorage.getItem('open-bible:theme')")
    expect(stored).to eq("dark")

    visit "/"
    expect(page).to have_css(%(html[data-theme="dark"]))
  end
end
