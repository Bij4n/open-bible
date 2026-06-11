import { Controller } from "@hotwired/stimulus"

// Reader display preferences (design v3). Currently one: continuous
// prose vs one-verse-per-block "study mode". Client-side preference,
// persisted in localStorage so it follows the visitor across chapters
// and sessions without a server round-trip.
const VERSE_VIEW_KEY = "open-bible:verse-view"

export default class extends Controller {
  static targets = ["body", "verseToggle"]

  connect() {
    this.applyStored()
  }

  // Re-apply after Turbo restores/replaces the chapter body.
  bodyTargetConnected() {
    this.applyStored()
  }

  toggleVerseBlocks() {
    const blocks = !this.isBlocks()
    localStorage.setItem(VERSE_VIEW_KEY, blocks ? "blocks" : "flow")
    this.applyStored()
  }

  isBlocks() {
    return localStorage.getItem(VERSE_VIEW_KEY) === "blocks"
  }

  applyStored() {
    const blocks = this.isBlocks()
    if (this.hasBodyTarget) this.bodyTarget.classList.toggle("verse-blocks", blocks)
    if (this.hasVerseToggleTarget) this.verseToggleTarget.setAttribute("aria-pressed", blocks ? "true" : "false")
  }
}
