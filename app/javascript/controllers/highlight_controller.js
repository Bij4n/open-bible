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

  // Legacy stored colors (pre-design-v3) render-map onto the current
  // four-color palette; the same aliasing applies when matching an
  // existing highlight's color to a toolbar swatch, so e.g. a "gold"
  // highlight marks the yellow swatch active and toggles off through
  // it. Mirrors Highlight::COLORS docs in app/models/highlight.rb.
  static LEGACY_COLOR_ALIASES = { gold: "yellow", sage: "green", sky: "blue", lavender: "blue" }

  canonicalColor(color) {
    if (!color) return color
    return this.constructor.LEGACY_COLOR_ALIASES[color] || color
  }

  connect() {
    this.onSelectionChange = this.onSelectionChange.bind(this)
    this.onDocumentPointerdown = this.onDocumentPointerdown.bind(this)
    this.onDocumentPointerup = this.onDocumentPointerup.bind(this)
    this.onDocumentKeydown = this.onDocumentKeydown.bind(this)
    document.addEventListener("selectionchange", this.onSelectionChange)
    // pointerdown fires for both mouse and touch, so toolbar dismiss
    // works on mobile without separate touchstart handling.
    document.addEventListener("pointerdown", this.onDocumentPointerdown)
    // pointerup detects taps on existing highlight spans so the toolbar
    // opens without requiring a text selection drag.
    document.addEventListener("pointerup", this.onDocumentPointerup)
    // Readwise-style keyboard verbs: j/k verse focus, h highlight,
    // n note (design v3).
    document.addEventListener("keydown", this.onDocumentKeydown)
    if (this.debugValue) this.mountInspector()
  }

  disconnect() {
    document.removeEventListener("selectionchange", this.onSelectionChange)
    document.removeEventListener("pointerdown", this.onDocumentPointerdown)
    document.removeEventListener("pointerup", this.onDocumentPointerup)
    document.removeEventListener("keydown", this.onDocumentKeydown)
    if (this.inspector) this.inspector.remove()
  }

  // Keyboard verbs. Bare keys only — anything typed into a form
  // control, Trix, or with a modifier held passes through untouched.
  onDocumentKeydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return
    const t = event.target
    if (t instanceof Element &&
        (t.closest("input, textarea, select, trix-editor, [contenteditable='true']") ||
         t.isContentEditable)) return

    switch (event.key) {
      case "j": this.moveKbdFocus(1);  event.preventDefault(); break
      case "k": this.moveKbdFocus(-1); event.preventDefault(); break
      case "h":
      case "H": this.kbdHighlight(); break
      case "n":
      case "N": this.kbdNote(); break
      case "Escape": this.clearKbdFocus(); break
    }
  }

  kbdVerses() {
    return this.hasChapterTarget ? Array.from(this.chapterTarget.querySelectorAll(".verse")) : []
  }

  moveKbdFocus(delta) {
    const verses = this.kbdVerses()
    if (verses.length === 0) return
    const current = verses.indexOf(this.kbdFocusEl)
    const next = current === -1
      ? (delta > 0 ? 0 : verses.length - 1)
      : Math.min(verses.length - 1, Math.max(0, current + delta))
    this.setKbdFocus(verses[next])
  }

  setKbdFocus(verseEl) {
    if (this.kbdFocusEl) this.kbdFocusEl.classList.remove("verse-kbd-focus")
    this.kbdFocusEl = verseEl
    if (verseEl) {
      verseEl.classList.add("verse-kbd-focus")
      verseEl.scrollIntoView({ block: "center" })
    }
  }

  clearKbdFocus() {
    this.setKbdFocus(null)
  }

  // h: select the focused verse and run the one-click default-color
  // path. syncSelection is invoked synchronously so currentRef is set
  // before the toolbar's default button is clicked — waiting for the
  // async selectionchange event would race.
  kbdHighlight() {
    if (!this.kbdFocusEl) return
    this.selectVerseContents(this.kbdFocusEl)
    this.syncSelection()
    this.toolbarTarget?.querySelector?.("[data-highlight-default]")?.click()
  }

  // n: select the focused verse and open the note flow (which creates
  // the backing default-color highlight when none exists).
  kbdNote() {
    if (!this.kbdFocusEl) return
    this.selectVerseContents(this.kbdFocusEl)
    this.syncSelection()
    this.note()
  }

  onDocumentPointerdown(event) {
    if (!this.hasToolbarTarget || this.toolbarTarget.hidden) return
    if (this.toolbarTarget.contains(event.target)) return
    if (this.hasChapterTarget && this.chapterTarget.contains(event.target)) return
    this.hideToolbar()
    window.getSelection()?.removeAllRanges()
  }

  // Detects a tap (pointerup with no active text selection) inside the
  // chapter. A tap on an existing highlight span shows the toolbar at
  // that span (any viewport; stores tapSpan so note() and
  // removeViaToggle() work without a selection). On narrow viewports a
  // tap anywhere else in a verse selects the verse's full text — the
  // design-v3 mobile primitive (YouVersion-style verse-tap), since
  // precise long-press drag selection is fiddly on touch. The
  // programmatic selection flows through the normal selectionchange →
  // syncSelection pipeline, so the toolbar, OsisRef math, and
  // highlight/note actions all behave exactly as a manual selection.
  onDocumentPointerup(event) {
    if (!this.hasChapterTarget || !this.chapterTarget.contains(event.target)) return
    const sel = window.getSelection()
    if (sel && !sel.isCollapsed) return  // drag-select; let syncSelection handle it
    const span = event.target.closest("[data-highlight-ids]")
    if (span) {
      this.tapSpan = span
      this.showToolbarAtSpan(span)
      return
    }

    // Verse-tap is gated to the bottom-sheet breakpoint (<640px) so a
    // desktop click inside the text stays a plain caret placement.
    if (window.innerWidth >= 640) return
    const verseEl = event.target.closest(".verse")
    if (verseEl) this.selectVerseContents(verseEl)
  }

  // Selects a verse's full body text, skipping [data-ignore-selection]
  // subtrees (verse-number sup, cross-translation badge) by anchoring
  // on the first and last accepted text nodes — element-boundary
  // endpoints would not survive computeOffset.
  selectVerseContents(verseEl) {
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

    let first = null
    let last = null
    let n
    while ((n = walker.nextNode())) {
      if (!first) first = n
      last = n
    }
    if (!first) return

    const range = document.createRange()
    range.setStart(first, 0)
    range.setEnd(last, last.textContent.length)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)
  }

  showToolbarAtSpan(span) {
    if (!this.hasToolbarTarget) return
    const rect = span.getBoundingClientRect()
    const tb = this.toolbarTarget
    tb.hidden = false
    tb.style.top  = `${window.scrollY + rect.top - tb.offsetHeight - 8}px`
    tb.style.left = `${window.scrollX + rect.left}px`

    const verseEl = span.closest(".verse")
    if (verseEl?.dataset?.verseId) tb.dataset.anchorVerseId = verseEl.dataset.verseId

    const color = this.canonicalColor(
      Array.from(span.classList).find((c) => c.startsWith("highlight-"))?.replace("highlight-", "")
    )
    tb.querySelectorAll("button[data-color]:not([data-highlight-default])").forEach((btn) => {
      btn.setAttribute("aria-pressed", btn.dataset.color === color ? "true" : "false")
    })
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
      // If the toolbar was opened by tapping a highlight span, keep it
      // visible — a collapsed selection after a tap is expected.
      if (!this.tapSpan) this.hideToolbar()
      return
    }
    // User started a new text selection; clear the tap state.
    this.tapSpan = null
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
    // Anchor signal — which verse the toolbar is currently positioned
    // against. Used by system specs as a deterministic wait target
    // (have_css "[...][data-anchor-verse-id='X']") instead of polling
    // pixel-level position math under Selenium's async timing. Also
    // useful in dev-tools for debugging selection lifecycle.
    const startEl = range.startContainer.nodeType === Node.TEXT_NODE
      ? range.startContainer.parentElement
      : range.startContainer
    const verseEl = startEl?.closest?.(".verse")
    if (verseEl?.dataset?.verseId) {
      tb.dataset.anchorVerseId = verseEl.dataset.verseId
    }
    this.markActiveSwatch(range)
  }

  hideToolbar() {
    this.tapSpan = null
    if (this.hasToolbarTarget) {
      this.toolbarTarget.hidden = true
      delete this.toolbarTarget.dataset.anchorVerseId
      this.clearActiveSwatch()
    }
  }

  // Sprint 16.6 — range-intersection active-state detection.
  // Replaces the PR A anchor-based contract because production
  // friction showed the anchor-based contract was wrong for the
  // dominant use case (overshoot-by-one-character when retargeting
  // an existing highlight). New rule: any [data-highlight-ids] span
  // the selection range INTERSECTS participates; dominant is
  // Math.max across all touched ids — consistent with the renderer's
  // highest-id-wins precedence and with removeViaToggle's existing
  // destroy target. No new precedence rule introduced.
  //
  // Perf: scope the walk to the selection's verses, not the whole
  // chapter. Single-verse and adjacent-two-verse selections (the
  // common case) avoid walking the entire chapter on every
  // selectionchange. Three-or-more-verse selections fall back to
  // chapter-wide walk to catch highlights in the middle verses
  // (degenerate, rare). Adjacency check uses nextElementSibling
  // because verses render as direct children of chapterTarget
  // separated by whitespace text nodes.
  //
  // Shared by markActiveSwatch (PR A) and removeViaToggle (PR C).
  dominantHighlightUnderSelection(range) {
    if (!this.hasChapterTarget) return null

    const startVerse = this.closestVerseEl(range.startContainer)
    const endVerse = this.closestVerseEl(range.endContainer)
    if (!startVerse) return null

    let scope
    if (!endVerse || startVerse === endVerse) {
      scope = [startVerse]
    } else if (startVerse.nextElementSibling === endVerse) {
      scope = [startVerse, endVerse]
    } else {
      scope = [this.chapterTarget]
    }

    const touchedSpans = scope.flatMap((root) =>
      Array.from(root.querySelectorAll("[data-highlight-ids]"))
    ).filter((span) => range.intersectsNode(span))

    if (touchedSpans.length === 0) return null

    const allIds = new Set()
    touchedSpans.forEach((span) => {
      const ids = (span.dataset.highlightIds || "").split(",").filter(Boolean).map(Number)
      ids.forEach((id) => allIds.add(id))
    })
    if (allIds.size === 0) return null

    const dominantId = Math.max(...allIds)

    // Find the touched span where dominantId is the LOCAL max — that
    // fragment carries dominant's color in its visible class. By
    // construction such a span should exist (dominant is in some
    // span's id list, and per renderer's highest-id-wins, the span
    // where local max == dominantId carries dominant's color).
    // Defensive null on miss in case of DOM mutation race or
    // unforeseen edge — markActiveSwatch / removeViaToggle handle
    // null via existing fall-through.
    const dominantSpan = touchedSpans.find((span) => {
      const localIds = (span.dataset.highlightIds || "").split(",").filter(Boolean).map(Number)
      return Math.max(...localIds) === dominantId
    })
    if (!dominantSpan) {
      console.warn("[highlight] no touched span carries dominantId as local max", { dominantId, touchedSpans })
      return null
    }

    const color = Array.from(dominantSpan.classList).find((c) => c.startsWith("highlight-"))?.replace("highlight-", "")
    const noteCount = parseInt(dominantSpan.dataset.noteCount || "0", 10)

    return {
      span: dominantSpan,
      color,
      ids: Array.from(allIds),
      dominantId,
      noteCount,
    }
  }

  markActiveSwatch(range) {
    if (!this.hasToolbarTarget) return
    const dominant = this.dominantHighlightUnderSelection(range)
    const activeColor = this.canonicalColor(dominant?.color ?? null)
    this.toolbarTarget.querySelectorAll("button[data-color]:not([data-highlight-default])").forEach((btn) => {
      btn.setAttribute("aria-pressed", btn.dataset.color === activeColor ? "true" : "false")
    })
  }

  clearActiveSwatch() {
    if (!this.hasToolbarTarget) return
    this.toolbarTarget.querySelectorAll("button[data-color]:not([data-highlight-default])").forEach((btn) => {
      btn.setAttribute("aria-pressed", "false")
    })
  }

  // The × button. Hides the toolbar and collapses the selection. The
  // collapse is necessary — without it, the still-active range would
  // re-fire selectionchange after the toolbar hides and re-show the
  // toolbar instantly. Removing the highlight is intentionally NOT
  // this button's responsibility (Sprint 16.5 PR C lands removal on
  // the color swatch as a toggle).
  dismiss(event) {
    this.hideToolbar()
    window.getSelection()?.removeAllRanges()
  }

  async apply(event) {
    const swatch = event.currentTarget
    const color = swatch.dataset.color
    if (!color) return

    // Toggle-remove fires when the clicked swatch is the active one,
    // or when the labeled Highlight button (which never carries
    // pressed state) targets the color that's already active.
    const activeSwatch = this.hasToolbarTarget &&
      this.toolbarTarget.querySelector("button[data-color][aria-pressed='true']")
    if (swatch.getAttribute("aria-pressed") === "true" ||
        (activeSwatch && activeSwatch.dataset.color === color)) {
      return this.removeViaToggle()
    }

    if (!this.currentRef) return

    const snapshot = this.snapshotSelection()
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
    if (!response.ok) return

    await this.applyTurboStream(response)
    requestAnimationFrame(() => this.restoreSelectionOrFallback(snapshot, color))
  }

  // Color-toggle removal path. Confirms with the user when the
  // highlight has notes attached (Q1 Option A: auto-destroy with
  // confirmation gate); skips the dialog when noteCount is 0. The
  // pluralized confirm templates are rendered server-side as data
  // attributes on the toolbar; we substitute %{count} client-side.
  async removeViaToggle() {
    let dominant

    if (this.tapSpan) {
      const span = this.tapSpan
      const ids = (span.dataset.highlightIds || "").split(",").filter(Boolean).map(Number)
      if (ids.length === 0) return
      const color = Array.from(span.classList).find((c) => c.startsWith("highlight-"))?.replace("highlight-", "")
      const noteCount = parseInt(span.dataset.noteCount || "0", 10)
      dominant = { span, color, ids, dominantId: Math.max(...ids), noteCount }
    } else {
      const sel = window.getSelection()
      if (!sel || sel.rangeCount === 0) return
      const range = sel.getRangeAt(0)
      dominant = this.dominantHighlightUnderSelection(range)
      if (!dominant) return
    }

    if (dominant.noteCount > 0) {
      const tmpl = dominant.noteCount === 1
        ? this.toolbarTarget.dataset.confirmRemoveSingular
        : this.toolbarTarget.dataset.confirmRemovePlural
      const message = (tmpl || "").replace("%{count}", String(dominant.noteCount))
      if (!window.confirm(message)) return
    }

    const snapshot = this.snapshotSelection()
    const csrfMeta = document.querySelector('meta[name="csrf-token"]')
    const csrf = csrfMeta ? csrfMeta.content : ""
    const response = await fetch(`/highlights/${dominant.dominantId}`, {
      method: "DELETE",
      credentials: "same-origin",
      headers: { "X-CSRF-Token": csrf, "Accept": "text/vnd.turbo-stream.html" },
    })
    if (!response.ok) return

    await this.applyTurboStream(response)
    requestAnimationFrame(() => this.restoreSelectionOrFallback(snapshot, null))
  }

  // Snapshot the current selection as { startVerseId, startOffset,
  // endVerseId, endOffset, text } so we can restore it after the
  // turbo_stream replace mutates the verse DOM. Cross-verse
  // selections track both endpoints' verse ids and walk both verses
  // on restoration. Returns null if no selection or selection isn't
  // anchored inside a .verse element.
  snapshotSelection() {
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) return null
    const range = sel.getRangeAt(0)

    const startVerseEl = this.closestVerseEl(range.startContainer)
    const endVerseEl = this.closestVerseEl(range.endContainer)
    if (!startVerseEl || !endVerseEl) return null

    return {
      startVerseId: startVerseEl.dataset.verseId,
      startOffset: this.computeOffset(startVerseEl, range.startContainer, range.startOffset),
      endVerseId: endVerseEl.dataset.verseId,
      endOffset: this.computeOffset(endVerseEl, range.endContainer, range.endOffset),
      text: range.toString(),
    }
  }

  closestVerseEl(node) {
    return node.nodeType === Node.TEXT_NODE
      ? node.parentElement?.closest(".verse")
      : node.closest?.(".verse")
  }

  // Sprint 16.5 PR D — Strategy 2 with strategy-3 fallback. Restore
  // the snapshotted selection across the post-stream DOM; if the
  // restored range's text doesn't match the snapshot, fall back to
  // strategy 3 (toolbar repositions on the new highlighted-span's
  // bounding rect) and console.warn for visibility. Worst-case UX
  // is bounded — toolbar lands on a real DOM element instead of
  // stale coordinates.
  restoreSelectionOrFallback(snapshot, applyColor) {
    if (!snapshot) return

    try {
      const range = this.rangeFromSnapshot(snapshot)
      if (!range) throw new Error("could not rebuild range from snapshot")
      if (range.toString() !== snapshot.text) {
        throw new Error(`text mismatch: expected ${JSON.stringify(snapshot.text)}, got ${JSON.stringify(range.toString())}`)
      }
      const sel = window.getSelection()
      sel.removeAllRanges()
      sel.addRange(range)
      // Explicit reposition + active-state update. Don't depend on
      // selectionchange firing deterministically across the post-
      // stream DOM mutation — the timing is browser-dependent and
      // CI flaked when relying on the natural flow. Direct call to
      // showToolbarAt is synchronous; markActiveSwatch runs inside
      // it. currentRef updated so subsequent applies have the right
      // OsisRef.
      this.currentRef = this.rangeToOsisRef(range)
      this.showToolbarAt(range)
    } catch (err) {
      console.warn("[highlight] selection restoration failed; falling back to bounding-rect repositioning:", err.message)
      this.repositionToolbarFallback(applyColor)
    }
  }

  rangeFromSnapshot(snapshot) {
    const startVerse = document.querySelector(`[data-verse-id="${snapshot.startVerseId}"]`)
    const endVerse = document.querySelector(`[data-verse-id="${snapshot.endVerseId}"]`)
    if (!startVerse || !endVerse) return null
    const start = this.findOffsetPosition(startVerse, snapshot.startOffset)
    const end = this.findOffsetPosition(endVerse, snapshot.endOffset)
    if (!start || !end) return null
    const range = document.createRange()
    range.setStart(start.node, start.offset)
    range.setEnd(end.node, end.offset)
    return range
  }

  findOffsetPosition(verseEl, targetOffset) {
    const walker = document.createTreeWalker(verseEl, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        let p = n.parentElement
        while (p && p !== verseEl) {
          if (p.dataset?.ignoreSelection !== undefined) return NodeFilter.FILTER_REJECT
          p = p.parentElement
        }
        return NodeFilter.FILTER_ACCEPT
      },
    })
    // Strict `>` (not `>=`) so an exact-boundary offset prefers the
    // START of the NEXT text node over the END of the current one.
    // Concrete reason: when a highlight is applied, the verse splits
    // into [pre-highlight, highlight-text, post-highlight] text nodes.
    // For an offset coinciding with the highlight's START, `>=` picked
    // the END of the pre-highlight node — which lives OUTSIDE the
    // highlight span — and PR A's anchor-based active-state detection
    // (correctly per its contract) walks closest("[data-highlight-ids]")
    // from startContainer's parent and returns null when the parent
    // is the verse, not the highlight span. With strict `>`, the
    // boundary lands at offset 0 of the highlight's own text node
    // (parent IS the highlight span), and anchor detection works.
    // boundaryFallback handles the end-of-verse case where targetOffset
    // equals the total verse length — return the last text node's end
    // since there's no next text node.
    let cumulative = 0
    let boundaryFallback = null
    let cur
    while ((cur = walker.nextNode())) {
      const len = cur.textContent.length
      if (cumulative + len > targetOffset) {
        return { node: cur, offset: targetOffset - cumulative }
      }
      if (cumulative + len === targetOffset) {
        boundaryFallback = { node: cur, offset: len }
      }
      cumulative += len
    }
    return boundaryFallback
  }

  // Strategy 3 fallback. For apply: anchor toolbar at the just-applied
  // color's first matching span. For remove: leave toolbar at last
  // position, clear active state. Either way, the toolbar lands on a
  // real DOM element and stays open per hybrid C.
  repositionToolbarFallback(applyColor) {
    if (!this.hasToolbarTarget) return
    if (applyColor) {
      const target = this.chapterTarget?.querySelector(`.highlight-${applyColor}[data-highlight-ids]`)
      if (target) {
        const rect = target.getBoundingClientRect()
        const tb = this.toolbarTarget
        tb.style.top = `${window.scrollY + rect.top - tb.offsetHeight - 8}px`
        tb.style.left = `${window.scrollX + rect.left}px`
      }
      this.toolbarTarget.querySelectorAll("button[data-color]").forEach((btn) => {
        btn.setAttribute("aria-pressed", btn.dataset.color === applyColor ? "true" : "false")
      })
    } else {
      this.clearActiveSwatch()
    }
  }

  async applyTurboStream(response) {
    const html = await response.text()
    if (!html.trim()) return
    if (window.Turbo?.renderStreamMessage) {
      window.Turbo.renderStreamMessage(html)
    } else {
      const tmp = document.createElement("template")
      tmp.innerHTML = html.trim()
      document.body.appendChild(tmp.content)
    }
  }

  async note(event) {
    // If toolbar was shown by tapping an existing highlight span, open
    // the note panel for that highlight directly (no selection needed).
    if (this.tapSpan) {
      const ids = (this.tapSpan.dataset.highlightIds || "").split(",").filter(Boolean).map(Number)
      if (ids.length > 0) {
        this.hideToolbar()
        this.loadNotePanelFor(ids)
        return
      }
    }

    // If the user has a selection, first create a default-color
    // highlight, then open the note panel for that new highlight.
    // If no selection (they clicked an existing highlight first), fall
    // through and the note panel loads for the existing highlight ids.
    const existingIds = this.highlightIdsUnderCursor()

    if (existingIds.length > 0) {
      this.hideToolbar()
      this.loadNotePanelFor(existingIds)
      return
    }

    if (!this.currentRef) return

    this.hideToolbar()
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
      body: JSON.stringify({ highlight: { osis_ref: this.currentRef, color: "yellow" } })
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
