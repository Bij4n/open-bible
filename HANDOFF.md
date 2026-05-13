# HANDOFF.md

> Read this first when picking up the project in a fresh Claude session.
> Goal: orient in under 60 seconds, then go to the right doc for depth.

---

## Where things are right now

- **Production:** [bible-together.org](https://bible-together.org), live since 2026-04-21, on Render. `main` auto-deploys.
- **Repo:** Public on GitHub as of 2026-05-11 (MIT). `CONTRIBUTING.md` + `CODE_OF_CONDUCT.md` + `.github/pull_request_template.md` are in place for external contributors.
- **GitHub Discussions:** Live as of 2026-05-11. Categories: Announcements (admin-only), Q&A, Ideas, General. Welcome post pinned as discussion #92 in Announcements.
- **Branch:** `main` is clean. Two open PRs (#100, #101) are waiting on CI — see below.
- **Last cluster shipped (Sprint 25, 2026-05-12):** mobile highlighting / note-leaving / note-sharing flow.
  - **PR #97 (merged)** — Firefox/Xvfb workaround for local Nvidia SWGL deadlock; mobile CSS: comment-indent cap, Trix min-height.
  - **PR #98 (merged)** — Citation header in note panel ("John 3:16"); `touch-target-row` 44px labels on visibility radios + group checkboxes; `inputmode="email"` on share field; `osis_citation` helper.
  - **PR #99 (merged)** — Tap highlight to open toolbar without drag selection (`tapSpan` state, `onDocumentPointerup` handler, `showToolbarAtSpan`).
  - **PR #100 (OPEN — CI pending)** — Inline amber warning panel replaces `window.confirm()` for public note visibility. Branch: `inline-public-warning`. Watch CI and merge when green.
  - **PR #101 (OPEN — CI pending)** — Post-save Turbo Stream flash: `flash_container` div in layout, `respond_to_change` sends contextual notice + closes note panel. Branch: `post-save-flash`. Watch CI and merge when green.
- **Next session goal (owner-directed):** UI polish and design cleanup. See the queue below.

---

## What to read next, in order

1. **`CLAUDE.md`** — workflow rules (the 9 numbered rules, especially Rule 7 no-Chrome / Rule 8 no-Google-fonts / Rule 9 every-UI-commit-ships-its-spec), TDD discipline, commit style, confidence flagging.
2. **`PLAN.md` "Current sprint"** (top of file) — one-paragraph statement of where we are and what's queued. Keep this current as the project moves.
3. **`PLAN.md` decisions log** — the most recent ~5 entries are append-only context for *why* the current code is what it is. Grep here when something looks wrong before assuming it's wrong.
4. **`PROJECT_OVERVIEW.md`** — depth reference (stack, file tour, sprint history). Slower to read; only when you actually need it.

---

## Open questions / where the user needs to weigh in

These are the things sitting on the user's desk, not Claude's. Don't pick them blind.

- **Legal pages** — `/terms`, `/privacy`, `/acceptable-use`. Sprint 15 blocker, still open. More pressing now that the repo is public and the app is accepting donations. Needs jurisdiction decision + drafted copy from the owner before any code can be written.
- **Devise paranoid-mode stance** — currently `paranoid = false`; reset-password leaks account existence. More relevant now that the repo is public and visible. Flip to `paranoid = true` is a one-liner; owner decides whether the UX trade-off (typo'd email silently "succeeds") is acceptable.
- **Sprint 24 audit item 5** — language-switcher placement vs. theme-toggle pinning. The audit (saved at `~/.claude/plans/what-do-you-need-enumerated-ember.md`) flagged the account-sheet as overloaded; two options, owner needs to pick. Ask to see both options if unclear.
- **Contact form** — delivery channel undecided (Resend mailer pipe? Slack hook? Ticket queue?). Ready to build the moment the channel is decided.
- **Donation rotation UX redesign** — current behavior forces a rotation on every "Add address." Backlogged design call: `Add` creates inactive, separate `Activate` action promotes. Low urgency; current behaviour works.
- **Issue triage process** — now that the repo is public, how fast and by what criteria does the owner respond to incoming GitHub issues? No tooling needed; just a mental model to have.

---

## UI polish queue (owner-directed next session)

The owner wants to focus on polishing the UI and cleaning up the design. Below are the strongest candidates. Owner picks the direction; Claude executes.

**Highest-impact, clear scope:**
- **Fix the 5 pre-existing axe contrast failures** — `spec/system/accessibility_spec.rb` has been failing since before Sprint 25. The culprit is `#bcc3bb` foreground on `#7b7e7b` background (2.28:1 vs 4.5:1 AA requirement). Trace the exact callsites, darken the foreground or lighten the background to clear AA, re-run axe. Single-commit fix.
- **Sprint 24 audit item 9 — hero empty-state placeholder** — when no admin-featured public note exists, the homepage hero is single-column and reads as empty. Ship a fallback: famous public-domain verse card + "Be the first to share a note" CTA, or a static illustration treatment. Owner decides the approach.
- **Devise mailer HTML polish** — current invite / reset-password / confirmation mailers use bare `<p>` tags. The `GroupInvitationMailer` (PR #75) set the visual vocabulary (mint accent, Instrument Serif italic em); mechanical port of that pattern to the 4 Devise action mailers. Low risk, meaningful polish for email-driven acquisition.
- **Sprint 24 audit item 5 — language-switcher placement** — the account-sheet is overloaded (theme + locale + auth all in one dropdown). Two options exist; owner needs to pick. Audit detail at `~/.claude/plans/what-do-you-need-enumerated-ember.md`.

**Interaction polish:**
- **Sprint 24 audit item 10 — swipe-to-dismiss bottom sheet** — the mobile highlight toolbar (PR #50 bottom-sheet) and account menu have no swipe gesture. Substantive Stimulus + gesture work.
- **Sprint 16.5 PR E — pencil-bridge polish** — the transition between toolbar dismiss and note-panel reveal. No clear UX spec locked yet; owner needs to decide: slide animation? auto-focus scroll? back-arrow to reopen toolbar?
- **Note panel slide-in uses `transform` in CSS override but Tailwind v4 uses `translate` property** — current `body[data-note-panel-open="true"] #note-panel-container { transform: translateX(0) }` in `application.css` may not override `translate-x-full` correctly in all browsers. Verify production behavior, fix if there's a gap. (The test workaround uses `style.translate` directly; the production CSS rule should too.)

## Autonomous-doable queue (no owner input needed)

Pick from this list when the user says "what's next" without specifics. Listed roughly by impact / readiness, not by priority.

- **Sprint 24 audit item 9** — hero empty-state placeholder (see UI polish queue above).
- **Fix axe contrast failures** — 5 pre-existing failures in `spec/system/accessibility_spec.rb` (see UI polish queue above).
- **Sprint 24 audit item 10** — swipe-to-dismiss on the mobile bottom-sheet. Substantive Stimulus + gesture work.
- **Devise mailer HTML polish** — bare `<p>` tags. Mechanical port of the GroupInvitationMailer pattern.
- **Public author profiles** — `/authors/:slug` showing public notes by an author. Useful now that public notes exist and accumulate.
- **`/help` or FAQ** — usage guide. No clear demand yet but easy to add when needed.
- **Multilingual semantic search (4-step sequenced)** — see `PROJECT_OVERVIEW.md` §8 for the full plan. Currently Concept search is English-only and the homepage labels it as such; multilingual would let it cover RV1909 too.
- **Hide Concept search mode on RV1909 reader** until multilingual ships — currently the toggle exists but returns nothing useful for Spanish queries.
- **Old `MembershipsController#create`** is now orphaned (Sprint 23.4 swapped the UI to invitations). Delete in a small cleanup PR.
- **Admin controller inheritance consistency** — `bitcoin_addresses_controller` inherits `Admin::BaseController`; `notes` and `flags` don't. Standardize.

---

## Default operating mode

The user runs sessions in **auto mode** when they want continuous shipping. In auto mode:

- Pick from the autonomous-doable queue, ship one PR per logical change.
- Open the PR, watch CI via the `Monitor` tool, merge when all 5 required checks pass (`test`, `lint`, `scan_ruby`, `scan_js`, GitGuardian). The user has standing instructions to merge yourself when CI is green.
- After each merge, fast-forward local `main` (`git checkout main && git pull`). Note the active feature branch will be deleted by `--delete-branch` on merge.
- Update `PLAN.md` decisions log at the close of any cluster of 3+ related PRs. Don't update for a single PR.
- Don't bundle PRs. Each focused. If you're about to commit 200 lines across unrelated files, stop and split.
- No AI attribution anywhere — not in commits, PRs, code, docs, comments, anywhere. Ever.

When the user provides explicit direction (e.g. "fix the about page eyebrow"), do the targeted fix and stop.

---

## Stack reminders, already-decided

- **Ruby 3.4.9 / Rails 8.1.3 / PostgreSQL / Hotwire / Tailwind v4 / Devise / RSpec / Firefox + geckodriver (never Chrome).**
- **Self-hosted fonts only** in `public/fonts/`. No Google Fonts, no Tag Manager, no Analytics.
- **Email-only auth.** No SMS. No phone fields. Ever.
- **Bilingual (en + es) is a merge gate.** Both locales updated in the same PR.
- **CI required checks:** `test`, `lint`, `scan_ruby`, `scan_js`, GitGuardian. Branch protection enforces.
- **Theme system:** `data-theme="dark"` attribute on `<html>` set by `theme_controller.js` from server pin / localStorage / system; CSS uses `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))`.
- **OSIS refs** are canonical: `Bible.<TRANSLATION>.<Book>.<Chapter>.<Verse>[!offset]`. Don't reinvent — use `app/services/osis_ref.rb`.
- **Test count:** ~786 total (full suite as of 2026-05-12). Full non-JS suite runs in ~10s locally. 5 pre-existing axe contrast failures in `spec/system/accessibility_spec.rb` — present before Sprint 25, not introduced by this work.

---

## Local environment quirks (matters when running specs)

- **Xvfb workaround for Nvidia SWGL deadlock** — the dev box has an Nvidia GPU that makes headless Firefox crash via the SWGL software renderer. `spec/rails_helper.rb` starts a dedicated Xvfb server on `:99` and sets `DISPLAY=:99`; the geckodriver runs Firefox with a real framebuffer instead of headless. If JS specs start hanging (after a reboot or if Xvfb dies), the fix is to reboot or manually run `Xvfb :99 -screen 0 1280x1024x24 &`. CI uses browser-actions/setup-firefox + setup-geckodriver which don't have the GPU issue; headless works fine there.
- **Stale Firefox / geckodriver sessions** can still cause `Net::ReadTimeout` on `Selenium::WebDriver::Remote::Bridge#create_session` even with Xvfb. If a JS spec hangs, kill any orphaned geckodriver/firefox processes (`pkill -f geckodriver && pkill -f firefox`) and re-run. CI is the authoritative validator; don't chase local flakes.
- **Note panel + Turbo Frame testing pattern** — visiting `/notes/:id/edit` directly renders only the partial (no layout, no Stimulus). System specs that need JS features in the panel should visit a reader page and set the turbo-frame `src` via `execute_script`. Example in `spec/system/notes_spec.rb` "post-save flash" spec.
- **Tailwind v4 translate vs transform** — Tailwind v4 uses the CSS `translate` property (not `transform`) for `translate-x-*` utilities. When forcing elements on-screen in specs, you must set both `element.classList.remove('translate-x-full')` and `element.style.translate = '0 0'`; setting `element.style.transform` alone has no effect on the Tailwind-controlled position.
- **`bin/embedding`** boots a Python venv + uvicorn for semantic search; skip with `EMBEDDING_SERVICE_SKIP=1 bin/dev` if you don't need it.
