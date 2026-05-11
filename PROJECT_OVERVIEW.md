# PROJECT_OVERVIEW.md

> Hand this to a fresh Claude conversation as a primer. Reference material — not a README.

---

## 1. What Open Bible is

**Open Bible** (live at **https://bible-together.org**) is a bilingual web Bible — KJV (English) and Reina-Valera 1909 (Spanish), both public-domain — that lets readers highlight scripture at the character level, attach rich-text notes, and share those notes privately, with specific users, with groups, or publicly.

That's the affordance. The **product** is something else: it's scripture-as-conversation. The animating belief is that scripture is meant to be read with someone — that the comma where a verse turned for you matters more when somebody else can hear it. Testimony culture meets digital reading. Fellowship is the product; highlighting and notes are the surface. Long-term, this is shaped to become a real social network around scripture: usernames, profiles, follow relationships, a feed of what's striking other readers. We're not there yet, and the homepage copy now reflects that — *Where verses meet voices.* / *Donde los versículos encuentran voz.*

- **Repository:** `Bij4n/open-bible` — open-source on GitHub (MIT). `CONTRIBUTING.md` documents the contributor rules; `CODE_OF_CONDUCT.md` sets community expectations.
- **Production:** https://bible-together.org (live since 2026-04-21)
- **Hosting:** Render (blueprint at repo root in `render.yaml`)
- **Audience:** anyone reading scripture and wanting to mark it up, talk about it, and eventually find others reading the same thing — bilingual EN/ES from day one, no SMS, no phone fields, ever
- **Why it exists:** existing Bible apps treat reading as solo and notes as private filing cabinets. Open Bible treats notes as testimony and reading as something done in fellowship.

---

## 2. Tech stack

| Layer | Choice |
|---|---|
| Language | Ruby `3.4.9` (asdf-managed; `.ruby-version` pinned) |
| Framework | Rails `~> 8.1.3` |
| Database | PostgreSQL — single DB shared by primary + Solid Cache/Queue/Cable (multi-DB collapsed at deploy) |
| Frontend | Hotwire (Turbo + Stimulus), import maps, **Tailwind CSS v4** via `tailwindcss-rails` |
| Asset pipeline | Propshaft |
| Fonts | **Inter** (UI/body sans) + **Instrument Serif** (verse + italic accents) + **JetBrains Mono** (refs/labels) — self-hosted `.woff2` in `public/fonts/` (Rule 8). Source Serif 4 retained one transitional sprint while call sites migrate. |
| Rich text | Action Text (Trix), used for note bodies and comments |
| Real-time | Action Cable + Turbo Streams (group Bibles only) |
| Background jobs | Solid Queue (DB-backed) |
| Cache | Solid Cache (DB-backed) |
| Auth | Devise 5 — email/password only, no OAuth, no SMS, no `:confirmable`/`:lockable`/`:trackable`/`:omniauthable` |
| Keyword search | `pg_search` (ts_headline highlighting) |
| Semantic search | Sentence embeddings (`all-MiniLM-L6-v2`, 384-dim) stored as JSON text + in-Ruby cosine — pgvector deferred. **English-only** today; surfaced as "Semantic search (English)" on the homepage. |
| Embedding service | Separate **Python pserv** at `services/embedding-service/` (FastAPI/uvicorn, sentence-transformers, torch). Rails calls it over HTTP via `EmbeddingService` client. In dev, `bin/embedding` boots `.venv` + uvicorn; on Render it's a private service (`type: pserv`). |
| Email | **Resend** SMTP. Sender domain `send.bible-together.org` is **separately verified** as a subdomain so DNS records (SPF/DKIM/DMARC) live on the subdomain, not the apex. `raise_delivery_errors: true` is set deliberately — loud failure beats silent black holes (proved its worth during the 5-PR SMTP cascade). |
| QR codes | `rqrcode` (Ruby, MIT, inline SVG — no external API) |
| Migrations | `strong_migrations` |
| Testing | RSpec, FactoryBot, Capybara, Selenium-WebDriver, **geckodriver + Firefox** (never Chrome — Rule 7), `axe-core-rspec`, WebMock |
| Linting | `rubocop-rails-omakase`, `erb_lint` |
| Security | Brakeman, `bundler-audit`, GitGuardian (CI required check) |

**Hosting topology — Render, three services:**

1. `open-bible-web` — Rails (Starter, ~$7/mo)
2. `open-bible-embedding` — Python pserv for embeddings (Standard, ~$25/mo — torch+sentence-transformers OOM on Starter)
3. `open-bible-db` — Postgres (Basic-256mb, ~$7/mo)

Total ~$39/mo. `RAILS_MASTER_KEY` is set in Render env (sync: false in blueprint). Pushes to `main` auto-deploy.

**Custom domain:** Namecheap → `bible-together.org` (apex + www). The send subdomain `send.bible-together.org` is configured separately in Resend so outbound mail is scoped — apex DNS stays clean, and a domain reset wouldn't take down email.

---

## 3. File and directory tour

### Controllers — `app/controllers/`

- `application_controller.rb` — sets locale, exposes helper methods `resolved_theme` and `donate_link_visible?` (memoized `BitcoinAddress.exists?(active: true)` so multiple footer renders share one query). `ensure_admin` returns `head :not_found` (not 403) so admin routes don't advertise their existence.
- `home_controller.rb` — renders `/` from `app/views/home/show.html.erb`.
- `donations_controller.rb` — `GET /donate`, `POST /donate/confirm` (with sr-only honeypot field), `GET /donate/thank-you`. 404s when no active address.
- `admin/bitcoin_addresses_controller.rb` — admin-gated; index + create + rotate.
- `admin/{notes,flags}_controller.rb` — moderation queues from Sprint 7. Mixed inheritance: `bitcoin_addresses_controller.rb` inherits `Admin::BaseController`; legacy admin controllers don't. Cleanup item in Sprint 16+ backlog.
- `bible/`, `groups/`, `groups_controller.rb`, `public/`, `notes_controller.rb`, `highlights_controller.rb`, `comments_controller.rb`, `note_shares_controller.rb`, `flags_controller.rb`, `upvotes_controller.rb`, `search_controller.rb`, `settings_controller.rb`, `memberships_controller.rb`, `locale_banners_controller.rb`.

### Models — `app/models/`

- `bitcoin_address.rb` — single source of truth for the active donation address. **`rotate_to!`** is an atomic transaction that archives the current active row (`active: false`, `archived_at: Time.current`) and creates the new active row in one go. **Partial unique index** `where active = true` enforces "at most one active" at the DB level.
- `donation_report.rb` — nullable `email` + `message`, one row per `/donate/confirm` POST.
- `bible/`, `book.rb`, `chapter.rb`, `verse.rb`, `translation.rb` — Bible domain. OSIS refs canonicalized at import time as `Bible.KJV.Book.Chapter.Verse`.
- `verse_embedding.rb` — JSON text storage + in-Ruby cosine similarity over ~62k verses (KJV + RV1909, though embeddings only generated for KJV today).
- `highlight.rb`, `note.rb`, `highlight_note.rb` — character-range highlights anchored by OsisRef; notes reach them through a join table; visibility is a four-branch enum (`private_note` / `shared_users` / `shared_groups` / `public_note`).
- `note_share.rb` — polymorphic share to User or Group.
- `group.rb`, `membership.rb` — invite-code groups. `before_destroy :refuse_destroy_of_last_owner` keeps groups owned; `Group#after_create` auto-creates the owner Membership.
- `comment.rb` — adjacency-list threading, depth cached, capped at 3 (replies beyond cap siblingize via `before_validation`).
- `upvote.rb`, `flag.rb` — community signals + moderation.
- `user.rb` — Devise + `ui_locale` / `theme` / `default_translation_id` / `display_name` / `admin` boolean.

### Views — `app/views/`

- `home/show.html.erb` — current product face. Hero, features grid (split into "For yourself" / "With others" subgroups), how-it-works (3 terse parallel-structure steps), 5-paragraph About, bottom Donate CTA. Voices section deliberately absent — see decision log.
- `layouts/application.html.erb` — site-wide chrome including the **real footer** (wordmark + tagline + nav + 2-line attribution). Footer renders on every route including `/`. The `donate_link_visible?` helper hides the Donate link when no active wallet.
- `donations/`, `admin/bitcoin_addresses/`, `admin/notes/`, `admin/flags/`.
- `bible/`, `public/bible/`, `groups/bible/` — three reader surfaces; the public reader carries community notes inline.
- `notes/_form.html.erb` — Trix editor inside a slide-in side panel.
- `shared/_flashes.html.erb` — modernized flash chrome.

### i18n — `config/locales/`

- `en.yml` and `es.yml` — **every user-facing string covered in both**. ~294 lines each, kept symmetric. Bilingual coverage is a merge gate; a missing translation does not ship.
- `devise.en.yml`, `devise.overrides.en.yml`, `devise.views.es.yml`.

### Stimulus — `app/javascript/controllers/`

`copy_controller.js` (clipboard copy on /donate), `theme_controller.js` (tri-state light / dark / system with server-rendered first paint and a `prefers-color-scheme` listener that re-resolves the palette live while in system mode; toggle reads localStorage at click time so external state mutations win over any cached mode — see Sprint 24 decisions log), `nav_select_controller.js` (custom listbox), `note_panel_controller.js`, `highlight_controller.js`, `comment_controller.js`, `upvote_controller.js`, `flag_controller.js`, `preference_form_controller.js`, `user_menu_controller.js`, `site_header_controller.js`.

### Specs — `spec/`

- `system/` — 20 system specs incl. `home_mobile_audit_spec.rb` (375px viewport, asserts no horizontal overflow, tagged `js: true`), `accessibility_spec.rb` (axe baseline across 5+ surfaces), `footer_spec.rb` (renders on /, public reader, /donate, /search; Donate gating; About anchor; Settings auth-only), `donations_public_spec.rb`, `admin_bitcoin_address_rotation_spec.rb`, `theme_toggle_spec.rb`, `bilingual_bible_spec.rb`.
- `requests/` — 25+ request specs incl. `home_i18n_spec.rb`, `donations_spec.rb`, `devise_password_reset_spec.rb` (full SMTP smoke), `locale_resolution_spec.rb`.
- `models/`, `services/`, `factories/`, `support/`.
- **~711 non-JS examples + ~60 JS-tagged system specs, 0 failures** as of Sprint 24 close (PR #90). The full non-JS suite (`bundle exec rspec --tag ~js`) runs in under 10 seconds locally; CI runs JS-tagged specs against headless Firefox + axe.

### Other

- `services/embedding-service/` — Python: `app.py`, `requirements.txt`, `run.py`. Talks JSON over HTTP.
- `render.yaml` — Render blueprint for all three services.
- `Procfile.dev` — local boot (Puma + Tailwind watcher + Solid Queue + `bin/embedding`).
- `lib/tasks/bible.rake`, `lib/tasks/embeddings.rake`.

---

## 4. Testing framework and discipline

- **RSpec + FactoryBot + Capybara + Selenium-WebDriver + geckodriver (Firefox).** Never Chrome / Chromium / chromedriver — Rule 7.
- **657 examples, all green.** CI on `main` is structurally required to be green via branch protection.
- **TDD red-first.** Write the failing test, watch it fail for the right reason, then write the minimum code to pass.
- **Rule 9 — every UI commit ships its matching system spec in the same commit.** No "request specs are green, ship it." A button moved without its spec moved is a CI fail and a process fail.
- System specs default to `rack_test`; tag `js: true` only when Stimulus/Turbo/Trix is actually exercised. The `before` hook in `spec/rails_helper.rb` swaps to headless Firefox only on JS-tagged examples.
- **375px mobile audit pattern** — `home_mobile_audit_spec.rb` resizes the window and asserts `document.body.scrollWidth <= window.innerWidth`. Re-use this pattern for any new homepage-class surface.
- **Accessibility:** `axe-core-rspec` baseline across home, public reader, signed-in reader, search, sign-in, settings. Light vs. dark themes tested separately — muted-text contrast is **not** symmetric across themes (55% alpha on dark passes AAA; same alpha on light fails AA — bumped light to 70%).
- **CI:** GitHub Actions runs RSpec, rubocop, erb_lint, Brakeman, `bundler-audit`, GitGuardian secret scan. All required checks for merge to main.

---

## 5. Development style and rules

(Full list lives in `CLAUDE.md`. The non-obvious ones:)

- **Rule 7 — no Chrome / Chromium / chromedriver.** Firefox + geckodriver, or WebKit via Playwright. The `spec/rails_helper.rb` driver registration falls back to `~/.local/opt/firefox/firefox` and `~/.local/opt/geckodriver` when env vars unset; CI exports `FIREFOX_BINARY` / `GECKODRIVER_PATH` after `setup-firefox` / `setup-geckodriver` actions install them.
- **Rule 8 — no Google-hosted third-party deps.** No `fonts.googleapis.com`, no Analytics, no Tag Manager. Inter, Instrument Serif, and JetBrains Mono are self-hosted. QR codes via `rqrcode`, never `chart.googleapis.com`.
- **Rule 9 — every UI commit updates its matching system spec in the same commit. CI green on main is non-negotiable.** Branch protection backs this structurally as of 2026-04-24.
- **Branch protection on `main`:** required checks are `test`, `lint`, `scan_ruby`, `scan_js`, GitGuardian. No exceptions.
- **Lowercase imperative commit messages.** Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`) used sparingly. No emoji. Example: `replace one-link footer with site-wide footer chrome` — not `feat(footer): ✨ Add comprehensive site-wide footer 🎨`.
- **No AI attribution anywhere in this repo.** No "Co-authored-by: Claude" lines. No `🤖 Generated with...`. No "AI-generated" comments. No Anthropic/Claude/model names in commits, PR bodies, README, code comments, error messages, or seed data. **Ever.** If you find any such reference from a prior session, remove it in its own commit titled `remove stray attribution`.
- **Each feature in its own PR, no bundled changes.** Sprint 15 shipped 14 PRs. Don't merge "homepage v2 + footer rewrite + small i18n nit" as one.
- **Decisions log in PLAN.md** for non-obvious choices. Sprint retrospectives at sprint close.
- **Bilingual i18n complete in en + es before merge.**
- **TDD red-first, always.** No "I'll add tests after."

---

## 6. Documentation system

Two living documents:

- **`CLAUDE.md`** — workflow rules, the 9 numbered rules, stack table, TDD checklist, confidence-flagging convention, Stuck Protocol, running-the-app commands. **Read on session start.**
- **`PLAN.md`** — open questions + decisions log (append-only) + sprint retrospectives + sprint roadmap + post-v1 backlog. **The single most important context document.** When in doubt about why something is the way it is, grep the decisions log.

This `PROJECT_OVERVIEW.md` is a snapshot meant to onboard a new conversation; it goes stale as soon as PLAN.md grows. After reading this, read PLAN.md's decisions log (last ~30 entries) for current context.

---

## 7. Sprint history summary

**Sprints 0–11** built the v1 product end-to-end: Bible data model + reader (1), Devise auth + preferences (2), character-level highlights + private notes via OsisRefs (3), sharing with users + groups (4), real-time group Bibles via Action Cable (5), threaded comments depth-capped at 3 (6), public Bible + upvotes + flags + admin moderation (7), `pg_search` keyword search (8), semantic search via in-Ruby cosine (9), Reina-Valera 1909 second translation (10), aesthetic polish + axe-core baseline (11).

**Sprint 12 — design pivot.** Aesthetic moved from illuminated-manuscript (Cinzel + EB Garamond, parchment + walnut + gilt, drop caps + fleurons) to modern SaaS (Inter + Source Serif 4 hybrid, near-white light / cool near-black dark, `amber-700` bronze accent). Pivot landed because the manuscript feel read as "too ancient" for a tool people would reach for in long sessions; pushed back on going fully sans-like-Grammarly in favor of hybrid (sans UI, serif body) for reading comfort.

**Sprint 13 — reader ecosystem migration.** Every reader surface (public, group, signed-in) plus search, notes panel, comments, home page visual shell migrated to the modern system. Two-tier danger pattern locked in: full-weight pill for standalone destructive actions, text-red hover for inline destructive text-buttons sitting next to non-destructive ones. Locale/translation banner shipped.

**Sprint 14 — visual migration finale.** Settings, admin, groups, shared flashes migrated. Manuscript tokens deleted from `application.css`; Cinzel/EB Garamond Google Fonts `<link>` removed from layout; grep-gated zero-reference verification. Process debt surfaced: across Sprints 12-14, `main` had been red and several UI commits had skipped system specs because Chrome/chromedriver was flaky and never properly fixed. **Three new rules** added (7, 8, 9) and branch protection turned on as the structural backstop.

**Sprint 15 — homepage content + Bitcoin donations + SMTP.** Three-track sprint that became four. 14 PRs over ~two days.

- **SMTP wiring (PRs #6–9, 5-commit cascade):** Resend SMTP plumbed in (PR #6 — deliberate `raise_delivery_errors: true`), credentials YAML nesting fix (PR #7), placeholder sender addresses fixed in `devise.rb` and `application_mailer.rb` (PR #8), swapped to a `send.bible-together.org`-scoped API key after Resend dashboard work (PR #9). **Each layer surfaced as a 500 in production immediately because of the loud-failure config — that decision is what made the cascade debuggable instead of a silent black hole.**
- **Bitcoin donations (PRs #10, #12, #13, #14):** static-wallet model (no processor, no KYC, no webhooks). `BitcoinAddress` model with atomic `rotate_to!` and partial unique index. Public `/donate` page with QR (rqrcode → inline SVG) + copy-to-clipboard + honeypot-protected confirm form. Admin rotation UI behind `ensure_admin`. Footer Donate link gated on active wallet. Dark-mode QR contrast fix.
- **Homepage progression v1 → v2 → v2.5 → v2.6 → footer (PRs #15–21):** v1 (PR #15) was mechanically correct but read as feature inventory. v2 (PR #16) reframed around purpose — *Where verses meet voices.* — features split into "For yourself" / "With others", testimony-voice copy throughout, Voices section deliberately omitted. v2.5 (PR #17) fixed a `request.path == root_path` locale-gate bug. v2.6 (PRs #18–20) restructured About into 5 paragraphs, tightened How-it-works to terse parallel-structure one-liners, sharpened the bottom Donate CTA to second-person imperative. **PR #21 — real footer:** replaced the single-link footer with site-wide chrome (wordmark + tagline + nav + 2-line attribution); renders on every route including `/`.

**High-signal lessons captured in PLAN.md decisions log:**

- **`raise_delivery_errors: true` was the right loud-failure default.** Prefer loud failure on infra wiring even when the first real-user attempt 500s; the alternative is shipping a feature that nobody knows is broken.
- **Never seed synthetic testimony on a faith product.** The Voices-section omission was the right call. Anonymous-but-published reflections will be read as real user notes; that's fabricated testimony, a worse trust violation here than on most products. Sprint 16+ rule: "implement only when real notes exist; never seed."
- **Donation rotation should be a deliberate admin choice, not a forced side-effect of adding an address.** The current behavior (every "Add address" forces a rotation) is fine for the seed case but has known sharp edges in steady state — listed in Sprint 16+ backlog.
- **Footer chrome justifies itself with content.** Sprint 15.5's per-page-hidden footer (single Donate link, hidden on `/`) was a workaround for an empty-slot footer. Once there's actual content (wordmark, nav, attribution), the chrome stands site-wide. The `donate_footer_link_visible?` helper got deleted as dead weight.

**Sprints 16–23 — Echo design system, app-wide polish, public notes, group invitations.** ~50 PRs across roughly two long autonomous sessions. PLAN.md decisions log has the full per-sprint detail; summary by cluster:

- **Sprint 16 — Echo design tokens (mint accent + Instrument Serif + JetBrains Mono).** Bronze → mint accent, Source Serif 4 → Instrument Serif, green-zinc surface, cool near-white paper. CLAUDE.md aesthetic line + Rule 8 font list updated.
- **Sprints 16.5 / 16.6 — Reader interaction grain.** Toolbar persistence (active-state ring, dismiss-only ×, color-toggle removal, click-outside dismiss, surgical Turbo streams), mobile bottom-sheet for the toolbar at < 640px, range-intersection active-state contract (replaced PR A's anchor-based detection after production friction surfaced overshoot-by-one-character drag-selects).
- **Sprint 17 — High-traffic body-chrome reskin.** Six routes brought to Echo card vocabulary (`rounded-2xl` + paper-card chrome). Pattern locked: primary CTAs → `rounded-full` pills, cards → `rounded-2xl`, text inputs / banners / alerts → keep `rounded-md`, danger buttons keep `rounded-md` for visual differentiation.
- **Sprint 17.6 — Lower-traffic sweep.** Settings, groups, admin, reader headers aligned to the same locked pattern.
- **Sprint 18 — Echo Category B content additions.** Hero secondary CTA ("See how it works"), hero meta chips below CTA row, About 2-col pull-quote layout, features-card embedded demos (4 of 7 cards), how-it-works step-screens (all 3 steps), section heading italic-em treatment matching the hero voice. Translated faithfully from the Echo prototype JSX.
- **Sprint 19 — App-wide polish pass.** /settings, /donate, /search, /groups, /admin, bible-reader headers all walked through with the same card-wrap + heading-cascade vocabulary.
- **Sprint 20 — Missing-pages audit.** Branded 404 / 422 / 500 / 400 / 406 error pages (static fallbacks + dynamic `ErrorsController#show` via `config.exceptions_app`), `/about` standalone canonical route, `/sitemap.xml` listing all bible chapters across translations.
- **Sprint 21 — SEO + social baseline.** `<meta name="description">`, Open Graph + Twitter card meta, canonical link, `og:locale` switching, `robots.txt` with sitemap directive, branded mint-disc favicon replacing the Rails red-circle placeholder.
- **Sprint 22 — Public notes enabled + Echo Category A.** Flipped the long-stale `notes_controller.rb` `ACTIVE_VISIBILITIES` gate (had been labelled "Coming in Sprint 7"); added `confirmPublic` Stimulus dialog so public is a deliberate choice. Hero verse card spotlights one admin-featured public note when one exists; community section below shows the next 3 most-recent public notes. Echo prototype is now fully translated into the codebase. Curation policy locked: post-then-moderate via existing `/admin/notes` actions.
- **Sprint 23 — Email-based group invitations.** New `GroupInvitation` model + `GroupInvitationMailer` (HTML + plaintext, bilingual) + `GroupInvitationsController` (create + destroy + accept-via-token). Owner enters friend's email on `/groups/:id`, friend gets a branded mint-accent email, click "Accept the invitation" → if signed in, joins immediately; if not, signed cookie carries the token across sign-up flow (cookies, not session, because warden rotates the session during sign-in). End-to-end signed-out → email link → sign-up → auto-join system spec. Closes the user-emphasized "bible studies" use case; original invitation-code flow stays available alongside.
- **Sprint 24 — Copy + page-descriptions cluster (#80–82) + dark/light + mobile-navbar audit cluster (#83–90).** Owner asked for an honest audit of dark mode, light mode, and the mobile navbar — "things feel not fully finished." Audit (saved at `~/.claude/plans/what-do-you-need-enumerated-ember.md`) ranked issues by impact-per-LOC; cluster shipped items 1–4 plus 6 + 8 over eight PRs. **Headline fix #83 surface-400/600 tokens** — ~100 view callsites used the muted-text pair `text-surface-600 dark:text-surface-400` but neither stop was defined in `@theme`; Tailwind tree-shook the unknown utilities and muted text fell through to inherited surface-50/900 (too bright in dark, slightly too dark in light). Added `--color-surface-400: #a3aaa4` and `--color-surface-600: #586663` to the green-zinc ramp. Single edit; biggest visual fix of the cluster. **#84 theme tri-state** — header toggle was binary (light↔dark), no way back to system; now cycles light → dark → system → light, system mode listens for OS-level `prefers-color-scheme` changes via `MediaQueryList.addEventListener("change")`. CI flake mid-PR: cached `this.mode` in connect went stale when system specs mutated localStorage afterwards; `toggle()` now reads localStorage at click time. **#85 account-menu active route** — opening the menu while on /settings rendered every item identically; added active-state pair (mint text on the same tinted bg the hover state already paints) to Settings, Admin, Sign in. Admin uses `request.path.start_with?("/admin")` so subroutes light up too. **#86 mobile tap targets** — row-level menu items at py-2 across all viewports were ~32px, below Apple's 44px touch guideline; added a `<640px` rule that bumps row items to py-3 via direct-child + `[role="menuitem"]` selectors; nested locale pill tiles stay compact. **#87 footer text-balance** — translations attribution wrapped parentheticals to an orphan third line at 375px; `text-balance` rebalances. **#88 soft theme flip** — page bg + base text snapped instantly while most chrome already animated via Tailwind's `transition-colors`; added 150ms `background-color` + `color` transition on `html`; `prefers-reduced-motion` already honored globally. **#90 about eyebrow drop** — the wordmark already sits in the header on every page; the redundant "Open Bible" eyebrow above the /about heading was dead weight. **Items 5 / 7 / 9 / 10 deferred:** language-switcher placement (owner judgment call), notes-panel anchor + tap-target (needs OSIS→human formatter + Stimulus action), hero empty-state placeholder (design call), swipe-to-dismiss bottom-sheet (substantial gesture work).

**Items still deferred (need owner content or design decisions, autonomous-shippable ones complete):** legal pages (terms / privacy / acceptable-use — needs jurisdiction + content), contact form (delivery channel TBD), Devise mailer HTML polish, public author profiles (`/authors/:slug`), FAQ, onboarding flow, pencil-bridge polish (Sprint 16.5 PR E — needs UX gesture spec), Sprint 24 audit items 5 / 7 / 9 / 10 (language-switcher placement, notes-panel anchor with tap-target, hero empty-state placeholder, swipe-to-dismiss bottom-sheet — see decision log).

---

## 8. Backlog

Items currently parked in PLAN.md, ready to pick up:

- **Bitcoin admin UX redesign.** Add row creates **inactive**; separate `Activate` action promotes (and archives the prior active) as a deliberate second step. Add `Edit notes` action that works on any row. Optional rotation reminder (target date + email N days before). Principle: rotation is deliberate, not forced.
- **Multilingual semantic search (4-step sequenced).** (1) Make `embeddings.rake` translation-agnostic. (2) Swap to `paraphrase-multilingual-MiniLM-L12-v2` (same 384 dim, schema doesn't move). (3) Regenerate embeddings for both KJV and RV1909. (4) Drop the "(English)" parenthetical and flip the homepage label back to plain `Semantic search`.
- **Devise paranoid-mode stance.** Currently `paranoid = false` — reset-password leaks account existence on unknown emails. Decide before any donation launch attracts adversarial traffic.
- **Admin controller inheritance consistency.** `bitcoin_addresses_controller.rb` inherits `Admin::BaseController`; legacy admin controllers (`notes`, `flags`) don't. Standardize.
- **Hide Concept search mode on RV1909 reader** until multilingual embeddings ship — currently the toggle exists but returns nothing useful for Spanish queries.
- **Sprint 16.5 PR E — pencil-bridge polish.** The mechanical pencil → note bridge already works; "polish" without a clear UX spec is open-ended. Deferred until a specific gesture / animation is locked.
- **Old `MembershipsController#create`** is now orphaned (Sprint 23.4 swapped the UI to the invitation flow). Future cleanup PR can drop it.
- **Various copy-audit nits** scattered in PLAN.md.

---

## 9. What's coming next

The Echo redesign (Sprint 16) and the long autonomous-feature run (Sprints 17–23) closed out the design + community + collaboration tracks. The remaining roadmap clusters are:

**Owner-blocked (need content / decisions):**
- **Legal pages** — `/terms`, `/privacy`, `/acceptable-use`. Flagged as a Sprint 15 blocker; still open. Needs jurisdiction + drafted copy.
- **Contact form** — delivery channel TBD (Resend mailer pipe? Slack hook? Ticket queue?).

**Autonomous-doable, queued:**
- **Devise mailer HTML polish** — bare `<p>` tags currently. Email-styling vocabulary now exists from the static error pages + group invitation mailer (#75). Mechanical port.
- **Public author profiles** — `/authors/:slug` showing public notes by an author. Now that public notes exist and accumulate organically, this becomes useful.
- **FAQ / Help (`/help`)** — usage guide. No clear demand yet but easy to add when needed.
- **Onboarding flow** — first-time user post-signup screen. Open question: what does it teach?
- **`/how-it-works` standalone page** — extending the homepage section into a deeper tutorial.
- **Donate section iteration.** Bitcoin admin UX redesign feeds into this; copy + disclaimer language will continue to evolve.

**Long-term vision:**
- **Social network features.** Usernames (currently `display_name` is optional and falls back to email local-part), profile pages, public feeds of what's striking other readers, follow relationships, per-item privacy controls richer than the current four-branch enum. This is scripture-as-fellowship made into a real social product. Public notes (Sprint 22) + hero verse card (Sprint 22) + community section (Sprint 22) + email-based group invitations (Sprint 23) are the foundation pieces.

---

## 10. Working norms

How the user prefers to collaborate with Claude Code:

- **Propose options before implementing for non-trivial work.** Show 2–3 paths, name the recommendation, name the tradeoff. The user will pick.
- **Distinguish your recommendation from the default.** Don't just say "I'll do X" — say "I recommend X over Y because Z; defaults to X."
- **Push back when the user's direction looks wrong.** The user values being argued with on substance. Don't roll over on a bad call to be agreeable. ("Pushed back on fully-sans-like-Grammarly in favor of hybrid" is the model.)
- **Don't bundle PRs.** Each one focused. If you've got 200 lines across unrelated files, stop and split.
- **Show diffs and reasoning before code** for non-trivial changes. The user reads diffs.
- **Verify production after every merge.** `bible-together.org` is real; production smoke is part of "done."
- **Handle merges yourself when CI is green** — standing instruction. If all required checks pass and the PR is ready, merge it. Don't ask first when the path is clean.
- **Confidence flagging** before non-trivial changes (high / medium / low + what would move it up). Low confidence = stop and write up options before coding.
- **Stuck Protocol** at ~15 min stuck or after 3 failed approaches: stop coding, write up what you tried, hypothesis, and 2–3 paths forward. Ask.
- **Commit before destructive generators.** `rails g devise User` has clobbered uncommitted factories more than once.
