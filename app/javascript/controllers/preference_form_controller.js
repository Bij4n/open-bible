import { Controller } from "@hotwired/stimulus"

// Auto-submits the enclosing form when a radio/select changes so the
// user doesn't need to click a Save button. Turbo Frame on the form
// scopes the response to just that section.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
