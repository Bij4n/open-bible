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
  static targets = ["shareSection", "publicWarning", "postMenu", "postLabel"]
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
    if (event.target.name !== "note[visibility]") return
    this.syncVisibility()
    // Picking an option closes the Post-to menu — the summary label
    // (updated in syncVisibility) now carries the choice.
    if (this.hasPostMenuTarget) this.postMenuTarget.removeAttribute("open")
  }

  // Replaces window.confirm() with an inline warning panel. Showing
  // friction at the moment of choosing Public prevents accidental
  // publication; the inline design is less jarring on mobile than a
  // browser confirm dialog and keeps focus inside the panel.
  confirmPublic(event) {
    this.pendingPublicRadio = event.target
    if (this.hasPublicWarningTarget) {
      this.publicWarningTarget.hidden = false
    }
  }

  cancelPublic() {
    if (this.hasPublicWarningTarget) this.publicWarningTarget.hidden = true
    if (this.pendingPublicRadio) this.pendingPublicRadio.checked = false
    const privateRadio = this.element.querySelector('input[name="note[visibility]"][value="private_note"]')
    if (privateRadio) privateRadio.checked = true
    this.pendingPublicRadio = null
    this.syncVisibility()
  }

  acceptPublic() {
    if (this.hasPublicWarningTarget) this.publicWarningTarget.hidden = true
    this.pendingPublicRadio = null
    // Radio stays checked; syncVisibility was already called on change.
  }

  syncVisibility() {
    const checked = this.element.querySelector('input[name="note[visibility]"]:checked')
    const selected = checked?.value
    this.shareSectionTargets.forEach((section) => {
      const match = section.dataset.visibilityDependent
      section.hidden = !(selected === match)
    })
    // Keep the Post-to summary label in sync with the checked radio
    // (each radio carries its display label in data-label).
    if (this.hasPostLabelTarget && checked?.dataset?.label) {
      this.postLabelTarget.textContent = checked.dataset.label
    }
    // Dismiss the inline warning whenever the user switches away from public.
    if (selected !== "public_note" && this.hasPublicWarningTarget) {
      this.publicWarningTarget.hidden = true
    }
  }
}
