import { Controller } from "@hotwired/stimulus"

// Three-way theme resolution on connect:
//   1. If the server already set data-theme (signed-in user with a saved
//      preference), respect it.
//   2. Else if localStorage has a value, use it.
//   3. Else follow prefers-color-scheme.
//
// On toggle: flip the theme, persist to localStorage, and if the user is
// signed in, POST the new value to /settings so it survives across
// devices. The server-side update is best-effort — UI responds to the
// local change immediately.
export default class extends Controller {
  static targets = ["label"]
  static values = {
    storageKey: { type: String, default: "open-bible:theme" }
  }

  connect() {
    const existing = document.documentElement.dataset.theme
    if (existing === "light" || existing === "dark") {
      this.apply(existing, { persistLocal: false, persistServer: false })
      return
    }
    const stored = localStorage.getItem(this.storageKeyValue)
    const initial = stored || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    this.apply(initial, { persistLocal: false, persistServer: false })
  }

  toggle() {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    this.apply(next, { persistLocal: true, persistServer: true })
  }

  apply(theme, { persistLocal, persistServer }) {
    document.documentElement.dataset.theme = theme
    if (this.hasLabelTarget) {
      const key = theme === "dark" ? "labelLight" : "labelDark"
      const text = this.labelTarget.dataset[key]
      if (text) this.labelTarget.textContent = text
    }
    if (persistLocal) localStorage.setItem(this.storageKeyValue, theme)
    if (persistServer) this.persistRemote(theme)
  }

  persistRemote(theme) {
    const csrf = document.querySelector('meta[name="csrf-token"]')
    if (!csrf) return // not signed in / no layout csrf meta

    // Only fires when the user is signed in; settings_path requires auth
    // and 302s to sign-in otherwise, which we silently ignore here.
    fetch("/settings", {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrf.content
      },
      body: JSON.stringify({ user: { theme } })
    }).catch(() => {
      // Network errors here aren't user-actionable; local state already
      // reflects the preference.
    })
  }
}
