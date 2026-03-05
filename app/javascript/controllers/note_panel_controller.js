import { Controller } from "@hotwired/stimulus"

// Slide-in note editor panel. Lives inside a <turbo-frame id="note_panel">
// in the layout; when the server renders the form into the frame we
// flip the `open` dataset flag and let CSS do the slide. Keyboard UX:
// Escape closes, Cmd/Ctrl+Enter submits.
//
// The shareSection targets have a `data-visibility-dependent` value
// naming the radio they belong to; we hide the non-matching sections
// so only the currently chosen visibility's fields are visible.
export default class extends Controller {
  static targets = ["shareSection"]
  static values = { open: Boolean }

  connect() {
    this.syncVisibility()
    this.element.addEventListener("change", this.onVisibilityChange.bind(this))
    document.body.dataset.notePanelOpen = "true"
    this.element.scrollIntoView({ block: "nearest" })

    // Trix sometimes mounts empty when the frame content replaces mid-
    // animation; a single rAF before auto-focus handles it reliably.
    requestAnimationFrame(() => {
      const trix = this.element.querySelector("trix-editor")
      trix?.focus?.()
    })
  }

  disconnect() {
    delete document.body.dataset.notePanelOpen
  }

  close() {
    document.body.dataset.notePanelOpen = "false"
    const frame = document.getElementById("note_panel")
    if (frame) frame.innerHTML = ""
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }
    const cmdOrCtrl = event.metaKey || event.ctrlKey
    if (cmdOrCtrl && event.key === "Enter") {
      event.preventDefault()
      this.element.querySelector("form")?.requestSubmit()
    }
  }

  onVisibilityChange(event) {
    if (event.target.name === "note[visibility]") this.syncVisibility()
  }

  syncVisibility() {
    const selected = this.element.querySelector('input[name="note[visibility]"]:checked')?.value
    this.shareSectionTargets.forEach((section) => {
      const match = section.dataset.visibilityDependent
      section.hidden = !(selected === match)
    })
  }
}
