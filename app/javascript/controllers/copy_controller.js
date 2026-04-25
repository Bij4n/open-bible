import { Controller } from "@hotwired/stimulus"

// Copies a fixed string (the address) to the clipboard. Briefly swaps
// the button label to the "copied" indicator so the click feels
// acknowledged without a toast.
export default class extends Controller {
  static targets = ["source", "label"]
  static values = {
    copied: String,
    revertMs: { type: Number, default: 1500 }
  }

  async copy() {
    const text = this.hasSourceTarget ? this.sourceTarget.textContent.trim() : ""
    if (!text) return

    try {
      await navigator.clipboard.writeText(text)
    } catch (_e) {
      const range = document.createRange()
      range.selectNodeContents(this.sourceTarget)
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
      document.execCommand("copy")
      sel.removeAllRanges()
    }

    if (!this.hasLabelTarget) return
    const original = this.labelTarget.textContent
    this.labelTarget.textContent = this.copiedValue || "Copied"
    clearTimeout(this._revertTimer)
    this._revertTimer = setTimeout(() => {
      this.labelTarget.textContent = original
    }, this.revertMsValue)
  }
}
