import { Controller } from "@hotwired/stimulus"

// Inline reply-form toggle. Each comment has its own replyForm target
// so multiple forms can be open without stepping on each other — the
// form-action posting via turbo submits carries the comment's
// parent_id hidden field.
export default class extends Controller {
  static targets = ["replyForm"]

  toggleReply() {
    if (!this.hasReplyFormTarget) return
    this.replyFormTarget.classList.toggle("hidden")
    if (!this.replyFormTarget.classList.contains("hidden")) {
      const textarea = this.replyFormTarget.querySelector("textarea")
      textarea?.scrollIntoView({ behavior: "smooth", block: "nearest" })
      textarea?.focus()
    }
  }
}
