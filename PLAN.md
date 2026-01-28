# PLAN.md

## Current sprint

**Sprint 0 — Foundation.** See [Sprint 0](#sprint-0--foundation) below.

---

## Open questions

- **Semantic search provider for Sprint 9** — decide before Sprint 8 ends. Options: Anthropic Voyage, OpenAI embeddings, or a local open-source model (e.g., `all-MiniLM-L6-v2` via pgvector). Tradeoffs: cost, latency, privacy, quality.
- **Moderation staffing model for Sprint 7** — single admin (you) for v1, or early invite of trusted moderators? Affects admin UX.
- **Group Bible default visibility** — when a user creates a group, are notes from members auto-shared to the group, or opt-in per note? Current default in Sprint 4 plan: opt-in per note. Revisit after dogfooding.
- **Chapter-level vs passage-level pagination** — Sprint 1 ships chapter pages. Consider "continuous scroll with chapter markers" later.

---

## Decisions log

Append-only. Each entry: date-ish, decision, rationale.

- **Sprint 0 setup** — **Project name: Open Bible.** Repo slug `open-bible`. Display name "Open Bible" in UI (Cinzel, all caps where appropriate). Name signals the public-domain-first philosophy and invites contribution.

- **Sprint 0 setup** — **KJV only for v1.** Public domain, clean OSIS source from ebible.org, no licensing friction. Reina-Valera 1909 (also public domain) lands in Sprint 10. RV1960 is explicitly excluded — copyrighted by United Bible Societies.
- **Sprint 0 setup** — **Email + password auth only.** No OAuth, no SMS, no phone fields anywhere in the schema. If a future feature wants a phone, flag it; do not add.
- **Sprint 0 setup** — **OsisRef-based highlight anchoring.** Highlights are stored as canonical OSIS references (e.g., `Bible.KJV.John.3.16!1-Bible.KJV.John.3.17!23` for character-range spans). This is more upfront work than raw `start_verse_id + offset` FKs but pays off when RV1909 arrives in Sprint 10, since a highlight on KJV John 3:16 can map directly to the same reference in RV1909. A parser and reverse-resolver service will be built in Sprint 3.
- **Sprint 0 setup** — **Character-level highlight granularity from day one.** Avoids rework. Verse-level is a trivial subset of character-level.
- **Sprint 0 setup** — **Rubocop style: `rubocop-rails-omakase`.** Rails 8 default. Not a decision worth bikeshedding.
- **Sprint 0 setup** — **Import maps over esbuild.** Rails default, fewer moving parts. Revisit only if blocked.
- **Sprint 0 setup** — **Ancient manuscript aesthetic specifics:** Cinzel for display headings, EB Garamond for body, parchment `#f4ecd8` light mode, walnut `#2a1f14` dark mode. Dark mode treated as "candlelit manuscript" — warm amber text on deep brown, not cold grey-on-black.
- **Sprint 0 setup** — **Real-time scope limited to group Bibles.** Public Bible view and private reading do not get live updates; they'd add load with little UX benefit.

- **2026-04-17 Sprint 1** — **OSIS source: `seven1m/open-bibles` (GitHub).** eBible.org doesn't publish OSIS for KJV; they publish USFX only. seven1m re-encodes that USFX as OSIS via the Haiola tool. Provenance documented in `config/bible_sources.yml`. SHA256 pinned.
- **2026-04-17 Sprint 1** — **Canonical `osis_ref` format: `Bible.KJV.Book.Chapter.Verse`.** Source uses bare form (`John.3.16`); importer normalizes to the full form at import time. This is Sprint 3's highlight-anchoring contract and must not change.
- **2026-04-17 Sprint 1** — **Apocrypha intentionally excluded for v1.** The KJV OSIS source ships 81 books (39 OT + 15 Apocrypha + 27 NT); `config/books.yml` lists only the 66 canonical books, and any book whose OSIS code isn't listed is logged at INFO and skipped during import. Deuterocanonical support is possible later as a feature with a per-user toggle.
- **2026-04-17 Sprint 1** — **`<transChange type="added">` markup stripped; inner text preserved.** KJV renders translator-supplied words in italic; we keep the text, drop the formatting for Sprint 1. `# TODO(post-v1): render <transChange type="added"> as italics per KJV convention` left at the handler.
- **2026-04-17 Sprint 1** — **Red-letter spans treated as cross-verse-capable in the parser even though the KJV source restarts `<q>` at every verse boundary.** The real source never exercises the carry-over code path, but other translations may; fixture has an explicit cross-verse Jesus span as a defensive invariant.
- **2026-04-17 Sprint 1** — **Red-letter color #8a1c1c is intentionally distinct from the UI rubric red #8b2e2e.** The in-text red is slightly darker and more saturated for body-copy legibility. A CSS comment calls this out so future work doesn't unify them by accident.
- **2026-04-17 Sprint 1** — **Ruby 3.4.9 via asdf.** Dropped 3.2.3 (EOL 2026-03-31), deleted `config/brakeman.ignore`. Bundler path pinned to `vendor/bundle` via `.bundle/config` to keep gems inside the repo.

- **2026-04-17 Sprint 2** — **Devise 5.0.3 with modules `database_authenticatable, registerable, recoverable, rememberable, validatable`.** `:confirmable` / `:lockable` / `:trackable` / `:omniauthable` explicitly off per the plan. Turbo integration needs no `responders` gem — 5.x handles the 422-on-invalid / turbo_stream formats natively.
- **2026-04-17 Sprint 2** — **Preference columns live on `users` via the same Devise migration.** `ui_locale` and `theme` carry Postgres check constraints as belt-and-suspenders against application-code bypass; `display_name` uses a partial unique index (`where display_name IS NOT NULL`) so many users can leave it blank.
- **2026-04-17 Sprint 2** — **Locale precedence: `current_user.ui_locale` > session > params > default.** Params still writes-through to session for signed-out visitors so the header language switcher keeps working. Signed-in users get a `button_to` that PATCHes `/settings` and redirects back.
- **2026-04-17 Sprint 2** — **Theme resolution server-side when the user pinned `light`/`dark`.** `resolved_theme` sets `<html data-theme>` on first paint, which the Stimulus controller respects before falling back to localStorage / prefers-color-scheme. `system` (and signed-out) leaves the attribute unset so the client decides.
- **2026-04-17 Sprint 2** — **Test fixture bible-source config isolated to `spec/fixtures/bible_sources.yml`.** Merged only when `Rails.env.test?`. Dev/prod attempting to import `kjv_mini` fails loudly — test data can't leak into real runs.
- **2026-04-17 Sprint 2** — **i18n inside `render do...end` blocks resolves against the partial's virtual path, not the caller's.** A Rails quirk that bit the Devise views; the fix is to precompute `t(".key")` before opening the block and pass the value through.

---

## Retrospectives

### Sprint 1

- What worked: fixture-first TDD caught my own bad assertion (`body_text.index("lifted up")` finding the wrong occurrence) before I shipped a wrong parser; SAX-based importer handled the full KJV in 12.7s at ~31k verses on first try; splitting the rake-task download/verify/unzip helpers out of the task body made them testable.
- What didn't: assumed ebible.org published OSIS (it doesn't — only USFX), lost ~20 min finding the seven1m redistribution; assumed the housekeeping step (Ruby 3.4, bundler path) was already done and had to stop and flag that; spent real time on Chrome-for-Testing + `--no-sandbox` to get system specs running in this container.
- Change next sprint: verify environment claims against the actual filesystem before trusting them, even (especially) for "already done" items; when a brief lists an external resource, WebFetch it before writing code.
- Size vs actual: estimated load-bearing sprint; actual 13 commits, roughly on target.

### Sprint 2

- What worked: Devise 5 + Turbo + devise-i18n was genuinely friction-free in 2026 — none of the older "Devise + Turbo needs responders" pain appeared; the `resolved_theme` + server-rendered `data-theme` pattern eliminated the flash-of-wrong-palette cleanly; pre-sprint cleanup as its own commit kept it tidy; the `update` responds-to-format split (JSON / Turbo-Frame / HTML) let theme toggle, settings frames, and the header switcher all share one action.
- What didn't: `rails generate devise User` clobbered a not-yet-committed factory + spec — lost ~5 min rewriting; t(".key") inside a `render do...end` block resolving against the partial's virtual path was a genuine surprise that showed up only in the system spec (fine at the unit level); text-transform: uppercase on headings kept biting Capybara `have_content`/`click_on` matchers — ended up sprinkling `/regex/i` and explicit selectors.
- Change next sprint: commit factories + specs before running any destructive generator; for any shared partial that yields, either pass translated strings in as locals or document the virtual-path quirk at the top; consider a RSpec matcher or shared helper for uppercase-text assertions.
- Size vs actual: estimated M (6-8 commits); actual 9 commits including pre-sprint cleanup + retro.

---

## Sprint roadmap

### Sprint 0 — Foundation

**Goal:** a booting Rails app with testing, linting, CI, base layout, i18n scaffold, and these docs.

- [ ] `git init`, `.gitignore`, `README.md`, `LICENSE` (MIT — confirm before creating)
- [ ] `rails new . --database=postgresql --css=tailwind --skip-test`
- [ ] RSpec + FactoryBot + Shoulda + Capybara + Selenium installed; smoke spec green
- [ ] Rubocop (omakase) + Brakeman + erb_lint installed and clean
- [ ] GitHub Actions CI running all of the above
- [ ] i18n configured for `:en, :es` with placeholder locale files
- [ ] Base Tailwind layout with manuscript theming: Cinzel + EB Garamond, parchment/walnut palette, Stimulus-driven theme toggle backed by localStorage, language switcher in header (non-functional beyond cosmetic for now)
- [ ] `CLAUDE.md` and `PLAN.md` committed
- [ ] `bin/dev` boots cleanly, `bundle exec rspec` green, `bundle exec rubocop` clean, CI green

**Acceptance:** fresh clone → `bin/setup` → `bin/dev` serves a styled landing page with the theme toggle and language switcher working visually. All checks green.

---

### Sprint 1 — KJV Bible data model + read-only reader

**Goal:** import the full KJV into the database with red-letter tagging, and render chapters.

**Models:**
- `Translation` — `code` (e.g., `KJV`), `name`, `language`, `license_notes`, `public_domain` boolean
- `Book` — `translation`, `osis_code` (e.g., `John`), `name_en`, `name_es`, `position`, `testament` enum
- `Chapter` — `book`, `number`, `verse_count`
- `Verse` — `chapter`, `number`, `body_text` (plain), `body_html` (with red-letter `<span class="jesus-words">` already rendered), `red_letter_ranges` JSONB (array of `[start_char, end_char]` pairs into `body_text`), `osis_ref` string

**Importer:**
- `lib/tasks/bible.rake` with `bible:import[translation_code]`
- Service: `app/services/bible/osis_importer.rb`
- Source: KJV OSIS XML from ebible.org (document the exact URL/version in the importer)
- Extracts `<q who="Jesus">` runs, converts to character ranges, stores both rendered HTML and ranges (ranges are the source of truth; HTML is a cache)
- Idempotent: re-running updates rather than duplicates

**Reader:**
- Routes: `GET /bible/:translation/:book/:chapter` (e.g., `/bible/kjv/john/3`)
- Next/prev chapter navigation
- Renders verses with red letters visibly styled (Cardo or EB Garamond italic, deep crimson `#8a1c1c`)
- No auth, no highlights, no comments yet

**Tests (TDD, non-negotiable):**
- Model specs for all four models (associations, validations)
- Importer spec against a small fixture OSIS file committed to `spec/fixtures/`
- Request spec for reader: routes, renders, red-letter styling present, 404 on bad refs
- System spec: visit `/bible/kjv/john/3`, see John 3:16, see Jesus's words in red

**Acceptance:** `bin/rails bible:import[kjv]` completes in under 5 minutes and populates all 66 books; `/bible/kjv/john/3` renders correctly with red letters; chapter nav works; all specs green.

---

### Sprint 2 — Authentication + user preferences

**Goal:** users can sign up, log in, and set UI preferences.

- Devise with email + password only (strip phone/SMS from generator output)
- `User` gets `ui_locale` (`en`/`es`), `theme` (`light`/`dark`/`system`), `default_translation_id`
- `/settings` page to edit preferences
- `ApplicationController` resolves locale from `current_user.ui_locale` when signed in, else session, else default
- Theme toggle persists to user record when signed in

**Tests:** request specs for sign up / sign in / sign out, model specs for preferences, system spec for the settings page updating theme and language.

---

### Sprint 3 — Character-level highlights + private notes

**Goal:** authenticated users can highlight any character range across verses and attach a rich-text note. Private only.

**OsisRef work:**
- `app/services/osis_ref.rb` — parser and builder. Handles simple refs, verse spans, and character-offset extensions (`Bible.KJV.John.3.16!12-Bible.KJV.John.3.17!45`)
- Thorough spec coverage; this is load-bearing for the next 3 sprints

**Models:**
- `Highlight` — `user`, `translation`, `osis_ref` (string, indexed), `color` enum, timestamps
- `Note` — `user`, Action Text `body`, `visibility` enum (`private`, `shared_users`, `shared_groups`, `public`)
- `HighlightNote` join — a note can anchor to one or more highlights

Only `private` visibility works this sprint. Sharing comes in Sprint 4.

**Frontend:**
- Stimulus controller `highlight_controller.js` handles `selectionchange`, computes character offsets relative to each verse span's plain text (use `data-verse-id` and walk the range), submits via Turbo
- Verse spans wrap `body_html` with `data-verse-id` and `data-osis-ref` attrs for offset resolution
- Click existing highlight → opens note panel (Turbo Frame) with Action Text editor
- Highlight colors: gold, rose, sage, lavender, sky — all muted, manuscript-appropriate

**Tests:** OsisRef parser spec (many cases), Highlight model spec, Note model spec, system spec for select-and-highlight flow with offset accuracy assertions.

---

### Sprint 4 — Sharing with users and groups

**Goal:** notes can be shared with specific users or with a group.

- `Group` — `name`, `description`, `owner`, private/invite-only
- `Membership` — `user`, `group`, `role` (`owner`, `member`)
- `NoteShare` polymorphic — `note`, `shareable` (User or Group)
- `visibility` enum on Note now honors `shared_users` and `shared_groups`
- UI: note editor gets visibility selector; when shared, multi-select for users/groups
- Group Bible view: `/groups/:id/bible/:translation/:book/:chapter` — shows all notes shared with that group inline
- Group creation, invitation (by email of existing user — no SMS), member list

**Tests:** authorization specs (Pundit or explicit `authorized?` methods — pick in sprint), system specs for group creation, invitation, shared-note visibility.

---

### Sprint 5 — Real-time group Bibles

**Goal:** in a group Bible chapter, members see each other's highlights, notes, and presence live.

- Action Cable channel keyed on `(group_id, translation, book, chapter)`
- New highlights/notes broadcast Turbo Streams to subscribers
- Presence indicator: small avatar stack in the header showing who's currently viewing
- Debounce presence updates; tear down on disconnect

**Tests:** channel specs, system spec with two browser sessions verifying cross-session updates.

---

### Sprint 6 — Threaded comments

**Goal:** notes can be commented on. Replies thread.

- `Comment` — `note`, `user`, `body` (Action Text), `parent_id` (adjacency list), `depth` (cached, capped at 5)
- Comments visible to whoever can see the note (reuse visibility from Sprint 4)
- Display: nested indentation with depth cap; replies beyond depth 5 collapse into the parent
- Real-time: if the note is in a group Bible, comments broadcast via the same channel

**Tests:** model specs for threading + depth cap, system specs for reply flow.

---

### Sprint 7 — Public Bible + moderation + upvoting + curation

**Goal:** public notes surface on the public Bible view with upvoting, flagging, and admin curation.

- `Upvote` — `user`, `note`, unique index on the pair
- `Flag` — `user`, `flaggable` (note or comment), `reason` enum, `resolved_at`
- `User#admin` boolean
- `/admin` dashboard: flag queue, feature/unfeature notes, soft-delete abusive content
- Public Bible view: `/bible/:translation/:book/:chapter` shows featured notes pinned, then top-voted public notes inline with the passage
- Logged-out users see the public Bible by default

**Tests:** upvote uniqueness, flag workflow, admin authorization, public view specs.

---

### Sprint 8 — Keyword search

**Goal:** search across verse text and public notes.

- `pg_search` scopes on `Verse#body_text` and public `Note` Action Text bodies
- Search page `/search?q=...` with filters: verses only, notes only, both
- Result highlighting (`<mark>` around matches)
- Paginated results, ranked by relevance then recency

**Tests:** search service specs with varied inputs; system spec for search UI.

---

### Sprint 9 — Semantic / topical search *(tentative)*

**Goal:** "I feel anxious" surfaces thematically relevant passages and notes.

- pgvector extension
- `VerseEmbedding` and `NoteEmbedding` models
- Embedding provider chosen before this sprint starts (see Open Questions)
- Background job to generate embeddings on create/update
- Search UI gains a "semantic" toggle; results combine keyword + semantic scores
- Cost monitoring: log embedding API usage

**Tests:** service specs with mocked embedding API; end-to-end spec hitting a small local model if feasible.

---

### Sprint 10 — Reina-Valera 1909 Spanish Bible

**Goal:** second translation lands; highlights and notes port cleanly via OsisRef.

- Import RV1909 OSIS from ebible.org
- **Verify at import time:** does the source tag Jesus's words? If not, mirror KJV's Jesus ranges by verse ref (same OSIS refs, so mapping is 1:1)
- Full Spanish UI translation pass — every i18n key reviewed and translated
- User can switch translations independently of UI language
- Translation selector on reader pages

**Tests:** importer spec for RV1909 fixture, cross-translation highlight portability spec (highlight on KJV verse renders at same ref on RV1909).

---

### Sprint 11 — Aesthetic polish

**Goal:** the app looks and feels like a real manuscript.

- Drop caps on chapter openings (CSS `::first-letter`)
- Decorative section dividers between chapters (SVG, not bitmap)
- Subtle aged-paper texture via CSS (SVG noise filter, no external images)
- Dark mode refinement: candlelit warmth, amber text on deep brown, soft page-edge gradient
- Accessibility audit: WCAG AA contrast, keyboard nav, screen reader labels, focus rings that match the theme
- Print stylesheet for chapters (people will want this)

**Tests:** accessibility assertions via `axe-core-rspec`; visual regression is manual.

---

## Backlog (post-v1)

- Reading plans (Bible in a year, topical plans)
- Original-language (Hebrew / Greek) tooltips on hover
- Mobile PWA / native wrappers
- Export notes to Markdown / PDF
- Cross-references (auto-linking verses to related passages)
- Strong's concordance integration
- Audio reading (TTS or licensed audio)
- Additional public-domain translations (ASV, WEB, Darby, YLT)
- Paid ESV/NIV API adapters once there's a business case
