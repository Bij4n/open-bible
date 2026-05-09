# HANDOFF.md

> Read this first when picking up the project in a fresh Claude session.
> Goal: orient in under 60 seconds, then go to the right doc for depth.

---

## Where things are right now

- **Production:** [bible-together.org](https://bible-together.org), live since 2026-04-21, on Render. `main` auto-deploys.
- **Branch:** `main` is clean and matches origin. No active sprint in flight.
- **Last cluster shipped (Sprint 24, PRs #80–90):** copy-pass + page descriptions + dark/light-and-mobile audit. Headline fix was the surface-400/600 token definitions in `@theme` — ~100 muted-text callsites had been tree-shaking, making dark-mode "muted" labels render at full near-white. Theme toggle is now tri-state (Light / Dark / System) and System mode tracks OS-level `prefers-color-scheme` live.

---

## What to read next, in order

1. **`CLAUDE.md`** — workflow rules (the 9 numbered rules, especially Rule 7 no-Chrome / Rule 8 no-Google-fonts / Rule 9 every-UI-commit-ships-its-spec), TDD discipline, commit style, confidence flagging.
2. **`PLAN.md` "Current sprint"** (top of file) — one-paragraph statement of where we are and what's queued. Keep this current as the project moves.
3. **`PLAN.md` decisions log** — the most recent ~5 entries are append-only context for *why* the current code is what it is. Grep here when something looks wrong before assuming it's wrong.
4. **`PROJECT_OVERVIEW.md`** — depth reference (stack, file tour, sprint history). Slower to read; only when you actually need it.

---

## Open questions / where the user needs to weigh in

These are the things sitting on the user's desk, not Claude's. Don't pick them blind.

- **Sprint 24 audit item 5** — language-switcher placement vs. theme-toggle pinning. The audit (saved at `~/.claude/plans/what-do-you-need-enumerated-ember.md`) flagged the account-sheet as overloaded; two options, owner needs to pick.
- **Legal pages** — `/terms`, `/privacy`, `/acceptable-use`. Sprint 15 blocker, still open. Needs jurisdiction + drafted copy.
- **Contact form** — delivery channel undecided (Resend mailer pipe? Slack hook? Ticket queue?).
- **Donation rotation UX redesign** — current behavior forces a rotation on every "Add address." Backlogged design call: `Add` creates inactive, separate `Activate` action promotes.
- **Devise paranoid-mode stance** — currently `paranoid = false`; reset-password leaks account existence. Decide before the donation page attracts adversarial traffic.

---

## Autonomous-doable queue (no owner input needed)

Pick from this list when the user says "what's next" without specifics. Listed roughly by impact / readiness, not by priority.

- **Sprint 24 audit item 7** — notes-panel anchor header. Format the highlight's OSIS ref to a human "John 3:16" via a new helper (parse with `OsisRef`, look up book by `osis_code` for `name_en` / `name_es`); render a small "anchored to <ref>" line at the top of the slide-in panel. Bigger lift if you also wire a tap-target that closes the panel + scrolls to the verse — that's a Stimulus action on `note_panel_controller`.
- **Sprint 24 audit item 9** — hero empty-state placeholder. Right now when no admin-featured public note exists, the homepage hero stays single-column and reads as empty. Either ship a placeholder (famous public-domain verse + "Be the first to share a note" CTA) or treat the empty state as a finished design — owner's call.
- **Sprint 24 audit item 10** — swipe-to-dismiss on the mobile bottom-sheet (account menu + highlight toolbar). Substantive Stimulus + gesture work.
- **Devise mailer HTML polish** — bare `<p>` tags currently. Email-styling vocabulary now exists from the static error pages + group invitation mailer (PR #75). Mechanical port.
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
- **Test count:** ~711 non-JS examples + ~60 JS-tagged. Full non-JS suite runs in ~10s locally.

---

## Local environment quirks (matters when running specs)

- **Stale Firefox / geckodriver sessions on the dev box** can cause JS-tagged system specs to time out with `Net::ReadTimeout` on `Selenium::WebDriver::Remote::Bridge#create_session` — the spec itself is fine; the local browser is wedged. CI is the authoritative validator for JS-tagged specs. If `theme_toggle_spec` or any other JS spec hangs locally, push and let CI confirm rather than chasing the local flake.
- **`bin/embedding`** boots a Python venv + uvicorn for semantic search; skip with `EMBEDDING_SERVICE_SKIP=1 bin/dev` if you don't need it.
