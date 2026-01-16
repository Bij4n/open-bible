import { Controller } from "@hotwired/stimulus"

// Toggles data-theme between "light" and "dark" on <html>, persisting the
// user's choice to localStorage. On first visit we honour prefers-color-scheme.
// TODO (Sprint 2): bind persisted preference to the current_user so it follows
// them across browsers.
export default class extends Controller {
  static targets = ["label"]
  static values = {
    storageKey: { type: String, default: "open-bible:theme" }
  }

  connect() {
    const stored = localStorage.getItem(this.storageKeyValue)
    const initial = stored || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    this.apply(initial)
  }

  toggle() {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    this.apply(next)
    localStorage.setItem(this.storageKeyValue, next)
  }

  apply(theme) {
    document.documentElement.dataset.theme = theme
    if (this.hasLabelTarget) {
      const key = theme === "dark" ? "labelLight" : "labelDark"
      const text = this.labelTarget.dataset[key]
      if (text) this.labelTarget.textContent = text
    }
  }
}
