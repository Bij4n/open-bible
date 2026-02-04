import { Controller } from "@hotwired/stimulus"

// Converts a DOM Selection inside the chapter container into an OsisRef
// and posts new highlights to /highlights. The server re-renders the
// chapter with highlight overlays on the next navigation, so after a
// successful mutation we Turbo.visit the same URL to pick up the
// updated HTML.
//
// A developer inspector (bottom-right corner) is mounted when the
// Rails environment is development or the page was loaded with
// `?debug=1`; it shows the computed OsisRef live as the selection
// changes — invaluable for debugging offset math. The inspector only
// echoes data that's already on the page (verse ids, osis refs,
// character offsets), so it doesn't expose anything sensitive.
export default class extends Controller {
  static targets = ["chapter", "toolbar"]
  static values = {
    translationCode: String,
    book: String,
    chapter: Number,
    debug: { type: Boolean, default: false }
  }

  connect() {
    this.onSelectionChange = this.onSelectionChange.bind(this)
    document.addEventListener("selectionchange", this.onSelectionChange)
    if (this.debugValue) this.mountInspector()
  }

  disconnect() {
    document.removeEventListener("selectionchange", this.onSelectionChange)
    if (this.inspector) this.inspector.remove()
  }

  onSelectionChange() {
    if (this.rafId) cancelAnimationFrame(this.rafId)
    this.rafId = requestAnimationFrame(() => this.syncSelection())
  }

  syncSelection() {
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0 || sel.isCollapsed) {
      this.currentRef = null
      this.updateInspector(null, null)
      this.hideToolbar()
      return
    }
    const range = sel.getRangeAt(0)
    if (!this.hasChapterTarget || !this.chapterTarget.contains(range.commonAncestorContainer)) {
      this.currentRef = null
      this.updateInspector(null, null)
      this.hideToolbar()
      return
    }
    const ref = this.rangeToOsisRef(range)
    this.currentRef = ref
    this.updateInspector(ref, range)
    if (!ref) { this.hideToolbar(); return }
    this.showToolbarAt(range)
  }

  rangeToOsisRef(range) {
    const start = this.resolveEndpoint(range.startContainer, range.startOffset)
    const end   = this.resolveEndpoint(range.endContainer,   range.endOffset)
    if (!start || !end) return null
    // Sprint 3 scope: same chapter only.
    if (start.book !== end.book || start.chapter !== end.chapter) return null

    const left  = `Bible.${this.translationCodeValue}.${start.book}.${start.chapter}.${start.verse}!${start.offset}`
    const right = `Bible.${this.translationCodeValue}.${end.book}.${end.chapter}.${end.verse}!${end.offset}`
    return left === right ? left : `${left}-${right}`
  }

  resolveEndpoint(node, offsetInNode) {
    const verseEl = node.nodeType === Node.ELEMENT_NODE
      ? (node.classList?.contains("verse") ? node : node.closest(".verse"))
      : node.parentElement?.closest(".verse")
    if (!verseEl) return null

    const osisRef = verseEl.dataset.osisRef
    if (!osisRef) return null
    const parts = osisRef.split(".")
    // parts: ["Bible", <TRANS>, <Book>, <Chapter>, <Verse>]
    const book    = parts[2]
    const chapter = parseInt(parts[3], 10)
    const verse   = parseInt(parts[4], 10)

    const offset = this.computeOffset(verseEl, node, offsetInNode)
    if (offset === null) return null

    return { book, chapter, verse, osisRef, offset, verseId: verseEl.dataset.verseId }
  }

  computeOffset(verseEl, node, offsetInNode) {
    // Walk all text nodes inside the verse, skipping subtrees marked
    // [data-ignore-selection] (the verse-number <sup>). Sum lengths up
    // to the endpoint, then add offsetInNode for text-node endpoints.
    const walker = document.createTreeWalker(verseEl, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        let p = n.parentElement
        while (p && p !== verseEl) {
          if (p.dataset?.ignoreSelection !== undefined) return NodeFilter.FILTER_REJECT
          p = p.parentElement
        }
        return NodeFilter.FILTER_ACCEPT
      }
    })

    if (node.nodeType === Node.TEXT_NODE) {
      // Reject if the endpoint is inside an ignored subtree.
      let p = node.parentElement
      while (p && p !== verseEl) {
        if (p.dataset?.ignoreSelection !== undefined) return null
        p = p.parentElement
      }

      let offset = 0
      let cur
      while ((cur = walker.nextNode())) {
        if (cur === node) return offset + offsetInNode
        offset += cur.textContent.length
      }
      return null
    }

    // Element-node endpoint: offsetInNode is the child index at which
    // the selection boundary sits. Sum textContent length of the first
    // `offsetInNode` accepted children.
    let offset = 0
    const children = Array.from(node.childNodes)
    const limit = Math.min(offsetInNode, children.length)
    for (let i = 0; i < limit; i++) {
      const child = children[i]
      if (child.nodeType === Node.ELEMENT_NODE && child.dataset?.ignoreSelection !== undefined) continue
      offset += child.textContent?.length ?? 0
    }
    return offset
  }

  showToolbarAt(range) {
    if (!this.hasToolbarTarget) return
    const rect = range.getBoundingClientRect()
    const tb = this.toolbarTarget
    tb.hidden = false
    tb.style.top  = `${window.scrollY + rect.top - tb.offsetHeight - 8}px`
    tb.style.left = `${window.scrollX + rect.left}px`
  }

  hideToolbar() {
    if (this.hasToolbarTarget) this.toolbarTarget.hidden = true
  }

  async apply(event) {
    const color = event.currentTarget.dataset.color
    if (!color || !this.currentRef) return
    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrf = csrfMeta ? csrfMeta.content : ""

    const response = await fetch("/highlights", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrf,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ highlight: { osis_ref: this.currentRef, color } })
    })

    if (response.ok) {
      window.Turbo?.visit(window.location.href, { action: "replace" }) || window.location.reload()
    }
  }

  async note(event) {
    // If the user has a selection, first create a gold highlight
    // (default color), then open the note panel for that new highlight.
    // If no selection (they clicked an existing highlight first), fall
    // through and the note panel loads for the existing highlight ids.
    const existingIds = this.highlightIdsUnderCursor()

    if (existingIds.length > 0) {
      this.loadNotePanelFor(existingIds)
      return
    }

    if (!this.currentRef) return

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrf = csrfMeta ? csrfMeta.content : ""
    const response = await fetch("/highlights", {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrf,
        "Accept": "application/json"
      },
      body: JSON.stringify({ highlight: { osis_ref: this.currentRef, color: "gold" } })
    })
    if (!response.ok) return
    const body = await response.json()
    this.loadNotePanelFor([ body.id ])
  }

  loadNotePanelFor(highlightIds) {
    const params = new URLSearchParams()
    highlightIds.forEach((id) => params.append("highlight_ids[]", id))
    const url = `/notes/new?${params.toString()}`

    const frame = document.getElementById("note_panel")
    if (!frame) return
    frame.src = url
    document.body.dataset.notePanelOpen = "true"
  }

  highlightIdsUnderCursor() {
    const sel = window.getSelection()
    const anchor = sel?.anchorNode?.parentElement?.closest("[data-highlight-ids]")
    if (!anchor) return []
    return (anchor.dataset.highlightIds || "").split(",").filter(Boolean).map(Number)
  }

  async remove(event) {
    // Look up the highlight id on a span under the current selection,
    // if any; otherwise silently bail.
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) return
    const anchor = sel.anchorNode?.parentElement?.closest("[data-highlight-ids]")
    if (!anchor) return
    const ids = (anchor.dataset.highlightIds || "").split(",").filter(Boolean)
    if (ids.length === 0) return

    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrf = csrfMeta ? csrfMeta.content : ""

    // Delete the most recent (highest id) under the cursor — matches the
    // color precedence in the renderer.
    const target = ids.map((n) => parseInt(n, 10)).sort((a, b) => b - a)[0]
    await fetch(`/highlights/${target}`, {
      method: "DELETE",
      credentials: "same-origin",
      headers: { "X-CSRF-Token": csrf, "Accept": "text/vnd.turbo-stream.html" }
    })
    window.Turbo?.visit(window.location.href, { action: "replace" }) || window.location.reload()
  }

  mountInspector() {
    this.inspector = document.createElement("div")
    this.inspector.id = "highlight-inspector"
    this.inspector.style.cssText =
      "position:fixed;bottom:12px;right:12px;max-width:360px;padding:10px 12px;border-radius:6px;" +
      "background:#2a1f14;color:#e8d5a8;font-family:ui-monospace,monospace;font-size:11px;line-height:1.4;" +
      "z-index:9999;box-shadow:0 6px 20px rgba(0,0,0,0.35);"
    this.inspector.innerHTML = "<strong>Selection inspector</strong><br><em>(no selection)</em>"
    document.body.appendChild(this.inspector)
  }

  updateInspector(ref, range) {
    if (!this.inspector) return
    if (!ref) {
      this.inspector.innerHTML = "<strong>Selection inspector</strong><br><em>(no valid selection)</em>"
      return
    }
    const startNode = range.startContainer.nodeName
    const endNode   = range.endContainer.nodeName
    this.inspector.innerHTML =
      "<strong>Selection inspector</strong><br>" +
      `ref: <code>${escapeHtml(ref)}</code><br>` +
      `start: ${startNode} @ ${range.startOffset}<br>` +
      `end: ${endNode} @ ${range.endOffset}`
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]))
}
