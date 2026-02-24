import { Controller } from "@hotwired/stimulus"

// Swaps the current reader URL to the selected translation, keeping the
// book and chapter the same. The <option> value is the fully-computed
// bible_chapter_path server-side; the controller just visits it.
export default class extends Controller {
  navigate(event) {
    const url = event.target.value
    if (url) Turbo.visit(url)
  }
}
