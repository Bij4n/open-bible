import { Controller } from "@hotwired/stimulus"

// Custom listbox-style picker used by the reader's chapter and
// translation selectors. Replaces native <select> because several
// browsers (notably Chromium-based on Linux, including Brave) don't
// apply CSS reliably to option elements — dropdown content became
// illegible in dark mode. This gives us full visual control and
// consistent keyboard semantics.
//
// Usage: render shared/_nav_select with options: [[label, url], ...]
// and selected_url. Clicking an option Turbo.visits the URL.
export default class extends Controller {
  static targets = ["trigger", "menu"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    this.handleKey = this.handleKey.bind(this)
  }

  disconnect() {
    this.removeGlobalListeners()
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    const selected = this.menuTarget.querySelector('[aria-selected="true"]')
      || this.menuTarget.querySelector('[role="option"]')
    selected?.focus()
    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("keydown", this.handleKey)
  }

  close() {
    this.menuTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.removeGlobalListeners()
  }

  removeGlobalListeners() {
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("keydown", this.handleKey)
  }

  select(event) {
    const url = event.currentTarget.dataset.url
    if (url) Turbo.visit(url)
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  handleKey(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      this.triggerTarget.focus()
      return
    }

    const options = [...this.menuTarget.querySelectorAll('[role="option"]')]
    if (options.length === 0) return
    const currentIndex = options.indexOf(document.activeElement)

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        options[Math.min(currentIndex + 1, options.length - 1)]?.focus()
        break
      case "ArrowUp":
        event.preventDefault()
        options[Math.max(currentIndex - 1, 0)]?.focus()
        break
      case "Home":
        event.preventDefault()
        options[0]?.focus()
        break
      case "End":
        event.preventDefault()
        options[options.length - 1]?.focus()
        break
    }
  }
}
