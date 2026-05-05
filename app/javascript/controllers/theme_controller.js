import { Controller } from "@hotwired/stimulus"

// Tri-state theme cycle: light → dark → system → light. The "system"
// mode follows prefers-color-scheme and reacts to OS-level changes
// while it's selected. Storage holds the *mode* (which can be
// "system"), while the rendered data-theme attribute holds the
// *resolved* palette ("light" or "dark") so CSS doesn't have to know
// about a third option.
//
// On connect:
//   1. If the server already set data-theme (signed-in user with a
//      saved preference of light/dark), use that as the mode.
//   2. Else if localStorage has a value, use it.
//   3. Else fall back to "system".
//
// On toggle: advance to the next mode, persist locally, and POST to
// /settings if signed in. Server-side update is best-effort.
const MODES = ["light", "dark", "system"]

export default class extends Controller {
  static targets = ["label"]
  static values = {
    storageKey: { type: String, default: "open-bible:theme" }
  }

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemListener = this._onSystemChange.bind(this)
    this.media.addEventListener("change", this.systemListener)

    const existing = document.documentElement.dataset.theme
    let mode
    if (existing === "light" || existing === "dark") {
      mode = existing
    } else {
      const stored = localStorage.getItem(this.storageKeyValue)
      mode = MODES.includes(stored) ? stored : "system"
    }
    this.applyMode(mode, { persistLocal: false, persistServer: false })
  }

  disconnect() {
    if (this.media) this.media.removeEventListener("change", this.systemListener)
  }

  toggle() {
    const idx = MODES.indexOf(this.mode)
    const next = MODES[(idx === -1 ? 0 : idx + 1) % MODES.length]
    this.applyMode(next, { persistLocal: true, persistServer: true })
  }

  applyMode(mode, { persistLocal, persistServer }) {
    this.mode = mode
    const resolved = mode === "system" ? (this.media.matches ? "dark" : "light") : mode
    document.documentElement.dataset.theme = resolved

    if (this.hasLabelTarget) {
      const dataKey = mode === "dark" ? "labelDark" : mode === "light" ? "labelLight" : "labelSystem"
      const text = this.labelTarget.dataset[dataKey]
      if (text) this.labelTarget.textContent = text
    }

    if (persistLocal) localStorage.setItem(this.storageKeyValue, mode)
    if (persistServer) this.persistRemote(mode)
  }

  _onSystemChange() {
    if (this.mode === "system") {
      this.applyMode("system", { persistLocal: false, persistServer: false })
    }
  }

  persistRemote(theme) {
    const csrf = document.querySelector('meta[name="csrf-token"]')
    if (!csrf) return // not signed in / no layout csrf meta

    fetch("/settings", {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrf.content
      },
      body: JSON.stringify({ user: { theme } })
    }).catch(() => {})
  }
}
