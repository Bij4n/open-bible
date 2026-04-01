# PLAN.md

## Current sprint

**Sprint 9 — Semantic / topical search.** See [Sprint 9](#sprint-9--semantic--topical-search-tentative) below. Provider choice (per Open Questions) is the gating decision before writing code.

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

- **2026-04-18 Sprint 3** — **Sprint 3 highlights scoped to same-chapter OsisRefs.** Multi-chapter grammar parses but is rejected at Highlight creation (via `OsisRef.parse(..., strict: :same_chapter)` and a corresponding client-side check). Revisit in Sprint 4 if cross-chapter shared notes become a use case.
- **2026-04-18 Sprint 3** — **OsisRef has two parse modes:** permissive (default) accepts cross-chapter refs so future features (shared notes, search) can operate on them; `strict: :same_chapter` raises `ScopeError` (a subclass of `ParseError`) and is used by the `Highlight` validator and the `HighlightsController#create` translation-resolver. Keeps domain constraints at the value-object boundary.
- **2026-04-18 Sprint 3** — **Chapter-prefix LIKE query for highlight lookup.** `current_user.highlights.for_chapter("Bible.KJV.John.3.")` uses the B-tree index on `osis_ref` as a prefix scan. Same-chapter constraint guarantees every highlight's full ref starts with that prefix by construction.
- **2026-04-18 Sprint 3** — **Highlight mutation → full-chapter re-render via `Turbo.visit(same URL)`.** Server-side `render_verse_with_highlights` remains the source of truth for the DOM; the Stimulus controller doesn't mutate the chapter body locally. Simpler, always correct; can be refined to in-place Turbo Stream frames later if the reload cost becomes visible.
- **2026-04-18 Sprint 3** — **Overlapping highlights: highest-id color wins visually; all touching ids land in `data-highlight-ids`.** Most-recent intent is usually what the user wants to see, and the click-disambiguation list covers removal and note-attachment on overlapping regions.
- **2026-04-18 Sprint 3** — **Note visibility enum uses `private_note` / `public_note` storage keys** to avoid Ruby-keyword and AR-predicate collisions (`note.private?` would shadow the `private` keyword). UI still labels them "Private" / "Public".
- **2026-04-18 Sprint 3** — **Selection inspector shipped to main, gated on `Rails.env.development? || params[:debug] == "1"`.** Fixed-position panel shows the live computed OsisRef and DOM endpoints as the selection changes. Only echoes data already on the page.
- **2026-04-18 Sprint 3** — **Note editor UI deferred to Sprint 4.** Sprint 3 builds the model, CRUD controller, and a read-only Turbo Frame show endpoint; the Action Text editor lands alongside the sharing UX so the panel is designed once against both concerns.

- **2026-04-18 Sprint 4** — **Plain-Rails authorization, no Pundit.** Scoped queries (`current_user.highlights.find`, `current_user.notes.find`, `current_user.groups.where`) plus `before_action :ensure_group_owner` / `:ensure_group_member` callbacks. Non-members get 404 — membership of a private group shouldn't be leakable via 403. Revisit if admin/moderator roles emerge.
- **2026-04-18 Sprint 4** — **Group Bible URL: `/groups/:id/bible/:translation/:book/:chapter`.** Explicit namespace, separate controller (`Groups::BibleController`), breadcrumb matches URL. Query-param variant rejected — would make shareable URLs lie about who sees them.
- **2026-04-18 Sprint 4** — **Invitation codes (one per group, regenerable), no email invitations yet.** 6-8 char alphanumeric codes auto-generated on create; owner shares out-of-band. Avoids configuring a production mailer in Sprint 4 and works for invitees without an existing account (they sign up, then enter the code).
- **2026-04-18 Sprint 4** — **Group ownership preserved via a cascade-safe callback pattern.** `Membership` has a `before_destroy :refuse_destroy_of_last_owner` and a `:keeps_at_least_one_owner` update validator. When the whole group is going away, `Group has_many :memberships, dependent: :delete_all` bypasses the callback — nothing to preserve if the group is vanishing.
- **2026-04-18 Sprint 4** — **Group#after_create ensures the owner has a Membership row.** So `user.groups` through memberships cleanly covers owned + joined in one association; `visible_to` doesn't need a second pluck of `owned_groups`.
- **2026-04-18 Sprint 4** — **Slide-in note editor panel from the right edge; 28rem on sm+, full-width on mobile.** Turbo Frame inside a fixed aside; `body[data-note-panel-open]` toggles the CSS transform. Escape closes, Cmd/Ctrl+Enter submits; Trix auto-focus wrapped in rAF so the frame-load timing doesn't leave it blank.
- **2026-04-18 Sprint 4** — **`Note.visible_to(user)` is a single SQL OR across four branches** (own / direct share / group share / public). Distinct so multi-path shares don't duplicate. Anonymous visitors get `where("1=0")` — nothing private leaks, and downstream `.includes`/`.where` still compose naturally.
- **2026-04-18 Sprint 4** — **User sharing inputs accept comma-separated emails in Sprint 4.** Unknown emails silently drop; autocomplete + not-found hinting layers on in Sprint 5. Keeps the form simple while email infrastructure is still deferred.

- **2026-04-18 Sprint 5** — **Action Cable adapter: async in dev, solid_cable in prod (deferred config), test adapter in test.** Rails 8 defaults; production Solid Cable setup (second DB) is a post-v1 concern.
- **2026-04-18 Sprint 5** — **Custom `GroupBibleChannel` extends `Turbo::StreamsChannel`.** Decodes the signed streamable tuple's leading base64-encoded GID to recover the Group, then rejects subscriptions where `current_user` isn't a member. Broadcasts continue to use `Turbo::StreamsChannel.broadcast_*_to` with the same tuple — one signed-streams plumbing, one authorization gate.
- **2026-04-18 Sprint 5** — **Group bible view is group-shared-only.** Dropped the Sprint 4 union of viewer's own highlights with group-shared. Simpler mental model, and critically: uniform content across members lets one broadcast update everyone without per-user rendering. Private markup stays on `/bible/...`. A future sprint can layer personal highlights as a client-side overlay on top of the shared base.
- **2026-04-18 Sprint 5** — **Per-verse `turbo_stream.replace` for highlight changes.** Each `<span class="verse">` carries `dom_id(verse) = "verse_<id>"`. Broadcasts re-render just that verse, preserving precise highlight positioning without re-rendering the whole chapter. Notes list is append/remove-targeted at `#group_notes_list`.
- **2026-04-18 Sprint 5** — **Presence indicators deferred.** Heartbeat + cleanup + UI complexity not worth it at current group sizes. Subscribe-counter version stays on the backlog if users later ask.
- **2026-04-18 Sprint 5** — **Multi-session cable tests replaced by broadcast integration specs + subscription wiring assertion.** `have_broadcasted_to(stream).from_channel(Turbo::StreamsChannel)` verifies the server-side broadcast contract; request spec checks the view includes a `<turbo-cable-stream-source channel="GroupBibleChannel">`. Two-browser Selenium tests are slow and flaky; the two-layer coverage is the standard Rails pattern and catches regressions just as well.
- **2026-04-18 Sprint 5** — **Destructive broadcasts snapshot their targets in `before_destroy`.** `Highlight#snapshot_broadcast_targets` and `NoteShare#snapshot_share` capture the shared_groups + affected verses list before `dependent: :destroy` cascades wipe the join rows. Without the snapshot, `after_destroy_commit` would find no groups and no broadcast would fire.

- **2026-04-19 Sprint 6** — **Threaded comments: depth cap 3, siblingize beyond.** Replies to a depth-3 comment become siblings (child of the depth-2 parent). Mobile-friendly nesting; `before_validation` enforces the cap so any client path (controller, console, seeds) lands in the same place.
- **2026-04-19 Sprint 6** — **Chronological ordering end-to-end.** Top-level comments oldest first; replies oldest first within each parent. `Note#comments_in_thread_order` does a depth-first walk in Ruby — the comment count per note is small and the tree is at most 4 levels deep, so no DB-side CTE is needed.
- **2026-04-19 Sprint 6** — **Comments inherit note visibility.** `Comment.visible_to(user)` merges `Note.visible_to(user)`; commenting requires being able to see the parent note. No per-comment share controls.
- **2026-04-19 Sprint 6** — **Realtime scope: group channels only.** Direct-user shares don't receive comment broadcasts yet; the recipient sees comments on next page load. Per-user channels stay on the backlog with the union-overlay work.
- **2026-04-19 Sprint 6** — **`User#author_name` = display_name → email local-part.** Centralises public attribution; full email never leaves the server for display. Retrofitted onto Sprint 4's group members list and note attribution for consistency.
- **2026-04-19 Sprint 6** — **Partial `viewer` local with `current_user rescue nil` fallback.** Broadcast renders have no Warden in the env, so `current_user` raises `Devise::MissingWarden`. The rescue lets the partial render without author controls during broadcasts (correct — non-authors shouldn't see edit/delete anyway) and falls through to `current_user` in normal view contexts.

- **2026-04-19 Sprint 7** — **Separate `/public/bible/...` route for the community view.** `/bible/...` remains the signed-in personal reader; signed-out visitors at `/bible/...` redirect to the public variant. Preserves Sprint 3-6 semantics, matches the existing `/groups/:id/bible/...` namespacing, and avoids rewriting the personal-reader specs.
- **2026-04-19 Sprint 7** — **Boolean `users.admin` column; admin seeded via `bin/rails runner`.** Smallest footprint for a single-role system; enum migration is trivial when/if moderator + editor roles appear. `ensure_admin` heads `:not_found` (not 403) so admin route existence isn't advertised.
- **2026-04-19 Sprint 7** — **Both flagging and soft-delete, independent workflows.** Users flag via `Flag` (polymorphic Note/Comment, reason enum, idempotent per-user); admins moderate via `notes.hidden_at` / `hidden_by_id`. Admin can hide without a flag; admin can resolve a flag without hiding. The two channels are orthogonal.
- **2026-04-19 Sprint 7** — **Upvotes only, no downvotes.** Religious content attracts brigading; positive-signal-only is the community norm we want. `sorted_for_public` is featured desc → upvote count desc → created_at desc, with the count pulled in via a correlated subquery so featured/non-featured ties break by popularity without a full outer join.
- **2026-04-19 Sprint 7** — **Per-note `featured` boolean; pin-to-top of the public bible chapter view.** No separate "featured notes" list surface; that's a different feature (editorial roundup) for another sprint.
- **2026-04-19 Sprint 7** — **`Note.visible_to(user)` short-circuits to `all` for admins.** Admins see every note (hidden, private, group-shared) from one unified scope — the admin interface piggybacks on the same query. Non-admins get the four-branch union that excludes hidden-public.
- **2026-04-19 Sprint 7** — **No DB-level FK on `hidden_by_id` / `featured_by_id`.** Moderation audit should outlive the admin's account deletion; referential purity loses to the audit trail here. `belongs_to ... optional: true` captures the model-level association without the cascade risk. strong_migrations' concurrent-index requirement also pushed us to split the FK from the reference.
- **2026-04-19 Sprint 7** — **Admin::UsersController deferred.** Admin-promote/demote happens via `bin/rails runner User.find_by(email: ...).update!(admin: true)`. Single-admin reality at current scale; the UI surface isn't worth its specs yet.

- **2026-04-17 Sprint 8** — **Verse + note results in separated sections, verses first.** One visual hierarchy per type, rather than an interleaved relevance-merged list. Verses are stable public-domain content (canonical citations), notes are community commentary — merging them masked the distinction and made "showing top N" per-type scoping harder to explain.
- **2026-04-17 Sprint 8** — **Search is fully public (signed-out accessible).** Matches the public-domain nature of the content and the existing `/public/bible/...` surface. Note results go through `Note.visible_to(current_user)` (or `Note.public_visible` when anonymous), so no private content leaks regardless of auth state.
- **2026-04-17 Sprint 8** — **`Note.visible_to(current_user)` reused verbatim for search visibility.** The Sprint 4 scope already handles the four-branch union (own/direct/group/public) and the Sprint 7 admin short-circuit. Duplicating that logic into a search-specific scope was the obvious anti-pattern; the two-step pattern (pluck pg_search-matching ids, then filter through `visible_to`) lets us compose without tangling pg_search's `associated_against` JOINs with the union.
- **2026-04-17 Sprint 8** — **Top 20 per type, no pagination, "refine your search" copy instead.** At v1 scale a chapter-level result set is small and users refine faster than they page. A real pagination surface belongs after we see actual usage distributions.
- **2026-04-17 Sprint 8** — **Verse highlighting via ts_headline (`<mark>` wrapping), note highlighting via a plain-text custom helper.** Verse `body_text` is already plain, so pg_search's `with_pg_search_highlight` + `StartSel`/`StopSel` is safe and idiomatic. Action Text note bodies are HTML — letting ts_headline slice through a rich document would mangle tags — so `SearchHelper#highlight_terms` takes `body.to_plain_text`, escapes it, and wraps each term manually.
- **2026-04-17 Sprint 8** — **Action Text search via `associated_against: { rich_text_body: [:body] }`, not `against: :body`.** Action Text's `has_rich_text :body` creates a `rich_text_body` association pointing at the `action_text_rich_texts` table. `against: :body` on the Note model would look for a column that doesn't exist. The `associated_against` form is the pg_search idiom for joining through a belongs_to and searching a column on the joined table.
- **2026-04-17 Sprint 8** — **Known caveat on note search: HTML tag names match as tokens.** Since Action Text stores rendered HTML (`<p>`, `<strong>`, `<em>`), a search for "strong" hits the tag as well as the word. Acceptable for v1 — the ranking still surfaces actual matches first, and the plain-text preview hides the tags in the UI. If this becomes a real problem, a before_save hook that mirrors the plain-text into a dedicated searchable column is the next step.

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

### Sprint 3

- What worked: writing 35 OsisRef specs before the implementation paid off immediately — the "backwards offset in same verse" and the `!end` sentinel both broke on the first run and were trivial to fix because every expected behaviour was already asserted; the event-list boundary-sweep in the highlight renderer handled overlapping highlights and jesus-words nesting in one pass, no edge-case patching; Stimulus+DOM TreeWalker inside verse spans landed on the first full iteration thanks to the brief's explicit "skip [data-ignore-selection] subtrees" rule; test-selection via `execute_script` + a walker that mirrors the controller's offset math gave deterministic, no-flake system specs; the workflow-notes commit from earlier in the sprint paid for itself 15 minutes later when `action_text:install` clobbered `spec/rails_helper.rb` and I restored it from HEAD without thinking.
- What didn't: first highlight-renderer spec expected `"Love"` where the actual fragment was `"Love "` (trailing space) — had to slow down and re-trace the ranges by hand; `COLORS.index_by(&:itself)` mapped the enum to string keys when the column is integer, wasted 3 minutes chasing a NOT NULL violation before spotting it; the `render turbo_stream: ""` vs `head :created` mismatch for turbo-stream media type caught me once — `head` doesn't set the turbo-stream content type; ended up keeping the Turbo Stream responses minimal (Turbo.visit-same-URL pattern) because full in-place frame updates for highlight mutation would need the chapter's verse HTML to be re-rendered on the server anyway, which is where we already compute it for first paint.
- Change next sprint: when a spec asserts exact string content, include the boundary whitespace deliberately — trailing spaces are real characters and easy to drop; for enum columns, the one-liner `COLORS.each_with_index.to_h` is what I want, not `index_by(&:itself)`; Sprint 4 should land the in-page Action Text note editor in a proper side panel since the show-only Turbo Frame is a stopgap; consider whether to back `render_verse_with_highlights` with a fragment cache keyed on `(verse.id, highlight_ids_digest)` — only worth doing if a real page's render time shows up.
- Size vs actual: estimated L (10-14 commits); actual 14 commits including the three pre-sprint cleanups. Roughly on target. The Stimulus selection resolver and the highlight renderer each took under an hour thanks to the explicit algorithm in the brief.

### Sprint 4

- What worked: plain-Rails authorization was the right call for this complexity — four before_action callbacks and a few `current_user.x.find` scopes did everything Pundit would have, with zero ceremony; the `Note.visible_to(user)` single-SQL-OR scope is surprisingly readable and handles the four visibility paths in one query; having `Group#after_create` auto-create the owner Membership row means `user.groups` transparently spans owned+joined without needing union tricks elsewhere; the Sprint 3 workflow-note ("commit before destructive generators") paid off a second time — Rails generator for the next migration again clobbered a local file that was safe because it was in the index; the Sprint 3 retro reminder about `each_with_index.to_h` for enums saved me from the same hash-type trap this time.
- What didn't: initial `has_many :memberships, dependent: :destroy` on Group plus the at-least-one-owner callback meant the first `Group#destroy` spec refused to cascade — had to flip to `:delete_all` for the group-going-away case and lose one line of time chasing `ActiveRecord::RecordInvalid` traces; backticks inside a `git commit -m` body got shell-expanded and dropped part of the message before I noticed (switched to HEREDOC mid-sprint); `render :form` in a controller looks for a top-level template `notes/form.html.erb` but my partial is `_form.html.erb` — wasted a few minutes on `ActionView::MissingTemplate` before fixing to `render partial: "form"`; Capybara can't assert HTTP status under Selenium, so the "non-member 404" system spec had to shift to content-absence assertions; the slide-in-panel CSS visibility quirk (trix-editor present but 0-height before Trix finishes mounting) needed a `visible: :all` in the system spec.
- Change next sprint: add `bundle exec erb_lint --lint-all` to my personal mid-sprint check since it caught the autocomplete-missing issue on the emails input before commit; when writing git commit message bodies with technical content (backticks, dollar-signs), default to HEREDOC form; prefer `render partial:` over `render :name` for non-action templates; when a system spec needs to assert "page doesn't render" for an authorization 404, do it via content-absence, not status; consider extracting an `AuthorizationConcern` mixin if a fifth or sixth controller picks up the same `ensure_owner` / `ensure_member` pattern — three isn't enough to justify the abstraction yet.
- Size vs actual: estimated M (8-10 commits); actual 9 commits (no pre-sprint cleanup this sprint). Right on target. The visible_to scope and the Membership at-least-one-owner constraint were the two judgment calls; both resolved within their first attempt.

### Sprint 5

- What worked: extending `Turbo::StreamsChannel` instead of building a parallel channel meant broadcasts could use the stock `Turbo::StreamsChannel.broadcast_replace_to` / `broadcast_append_to` class methods — authorization slotted in at subscribe time with no rewiring; the `GroupBibleBroadcastable` concern kept all four touchpoints (Highlight × 3 callbacks, Note, NoteShare × 2 callbacks) pointing at the same broadcast shapes; dropping the Sprint 4 union of own+group highlights on the group bible turned out to simplify the broadcast story dramatically (uniform content per group) and the UX argument held up — private markup lives on `/bible/...`, group markup on the group page; the browser-log-dump helper I added to diagnose the importmap regression is going to keep earning its keep; using `have_broadcasted_to(stream).from_channel(Turbo::StreamsChannel)` instead of attempting two-browser Selenium tests gave tight, fast coverage of the contract.
- What didn't: the `import "channels"` → `channels/index.js` → `./consumer` indirection worked in dev but silently 404'd in test, because `pin_all_from` doesn't alias `channels` to `channels/index` and the browser's relative-URL resolution fell back to an un-pinned `/assets/channels/consumer` path — caught only when nine system specs started failing simultaneously and the newly added browser-log dump revealed the 404; my first Highlight destroy callback tried to read `notes` after `dependent: :destroy` had already cascaded through `highlight_notes`, so I got an empty broadcast target list — fixed by snapshotting in `before_destroy`; Turbo's signed stream names are base64-encoded GIDs colon-joined, not plain strings, so my first `group_from_stream_name` implementation tried to split on `:` and parse `gid://...` fragments as-is; initial `note.highlights.includes(chapter: { book: :translation })` failed because `Highlight` has no direct `chapter` association (the chapter lives through `osis_ref` → `affected_verses`).
- Change next sprint: when adding new JS entry points, test both dev AND test explicitly before committing — they diverge more than I expected; keep the browser-log-dump helper around (already in the repo); for any destroy callback that needs associated records, check whether `dependent: :destroy` has already fired — snapshot before, or switch to `dependent: :delete_all` for rows that don't need their own callbacks; inspect Turbo internals once up front when extending its channel, rather than reverse-engineering the encoding from failing specs.
- Size vs actual: estimated S-M (6-8 commits); actual 8 commits including the importmap-regression fix that was itself diagnostic scaffolding I kept. Right on target — the Cable setup itself was short; the subtlety was in the broadcast shape decisions.

### Sprint 6

- What worked: `Comment.visible_to(user)` piggybacking on `Note.visible_to(user)` via `joins(:note).merge(...)` was a one-liner that reused all the Sprint 4 SQL — no second 4-way-union to maintain; the siblingize-beyond-MAX_DEPTH rule in `before_validation` means every call path (controller, seeds, console) hits the same cap without the controller having to branch; the depth cache on write combined with inline `margin-left: N * 20px` in the partial gave correct indentation without a recursive view partial; `before_destroy` snapshot pattern from Sprint 5 transferred cleanly to Comment destroys; `author_name` as a one-line User method made the retrofit onto Sprint 4's group members list and note attribution trivially consistent.
- What didn't: broadcast render of `_comment.html.erb` triggered `Devise::MissingWarden` because `current_user` isn't accessible without a request context — fixed with a `viewer` local that rescues the error, but it's a subtle trap that any future partial rendered via `ApplicationController.renderer` will hit; first system spec used `dom_id(note)` directly from the example group and got `NoMethodError` because `ActionView::RecordIdentifier` isn't mixed into `RSpec::ExampleGroups` — had to fully qualify; the initial `Comment.create_reply` class method from the brief got replaced by a `before_validation` callback since the controller never had to branch on "is this a reply to a depth-cap comment" — one-path handling turned out to be simpler.
- Change next sprint: when writing a partial that's ever rendered via `broadcast_*_to`, default to taking any user-context as a local (`viewer:`, `current_user:`) rather than relying on the helper method — the rescue works but is a code smell; include `ActionView::RecordIdentifier` (or `Rails.application.routes.url_helpers`) in the spec helper when specs need `dom_id` at the top level; when a brief suggests a `create_reply` class method, check whether a `before_validation` callback can reach the same goal first — usually the callback wins on uniformity.
- Size vs actual: estimated S (5-7 commits); actual 6 commits. Right on target. Sprint 5's channel infrastructure paid off — the only net-new runtime complexity was the depth-cap rule and the partial-viewer workaround.

### Sprint 7

- What worked: the separate-route decision saved real time — the Sprint 1-6 specs and URL semantics stayed intact, and the public bible landed as a new controller + view pair without any rewrites elsewhere; `Note.visible_to` short-circuiting to `all` for admins means the admin moderation UI reuses the same scope the public surface uses, which is the right invariant ("admins see what anyone else can plus the hidden stuff"); `sorted_for_public` with a correlated upvotes subquery is readable and keeps the ordering logic co-located with the model rather than spread across the controller; the decision to skip downvotes and Admin::UsersController kept the sprint tight; strong_migrations fired on the moderation migration and pushed us toward a production-safer pattern (`disable_ddl_transaction!` + concurrent indexes, no blocking FK) that I wouldn't have reached unprompted.
- What didn't: first `/bible/...` anonymous-redirect change triggered eight existing spec regressions — the Sprint 1 reader specs, Sprint 2 theme/settings specs, and locale_resolution specs all assumed anonymous access worked there; ended up reverting the HomeController redirect and adding sign-in to the Sprint 1 specs instead; first attempt at the Note factory in the public bible request spec reused one author across multiple notes and hit the Highlight uniqueness constraint (`user_id`/`osis_ref`/`color`) — caught only at the integration level because the factory created each highlight with the same color; the admin hide system spec needed `click_button "Sign out"` followed by an explicit `have_link(text: /sign in/i)` wait before the next `visit`, otherwise the signout hadn't settled and the anonymous check asserted against a still-admin session; strong_migrations' `add_reference`-with-FK check required learning the `disable_ddl_transaction!` + concurrent indexes pattern mid-sprint.
- Change next sprint: when adding a redirect/route change that affects anonymous access, grep for `visit "/"` and `get "/"` in all specs first — cheaper than fixing after the fact; in factories and integration specs with Highlight, explicitly vary either color or user when creating multiple highlights on the same osis_ref; for system specs with auth state transitions, assert the transition (signed-out link appears) before the next navigation — don't rely on timing; for any admin action that cascades to many indexes, use `disable_ddl_transaction!` + `algorithm: :concurrently` from the start rather than waiting for strong_migrations to flag it.
- Size vs actual: estimated L (12-15 commits); actual 10 commits (admin, upvote, flag, moderation fields, public controller, public view+JS combined, admin moderation, admin flags, system specs, retro). Came in under on commit count because several pieces folded naturally together (moderation fields + scopes + methods in one commit; admin notes + flags + views in one commit). Real scope was still L — the sprint touched schema, models, controllers, views, JS, and specs across two new surfaces.

### Sprint 8

- What worked: separating verse and note search behind one `SearchService` with a `VALID_SCOPES` constant kept the controller trivial (4 lines) and the view could iterate the constant for its filter radios — single source of truth for "what filters exist"; the two-step note search (pluck matching ids via pg_search, then filter through `Note.visible_to`) cleanly composed pg_search's associated_against join with Sprint 4's visibility union without either getting tangled in the other's SQL; ts_headline for verses and a separate plain-text helper for notes removed the HTML-slicing risk entirely — one path renders safe pg_search output via `html_safe`, the other escapes then wraps; `SearchHelper#highlight_terms` centering the preview window on the first matched term (with `focus_window`) gave a meaningfully better result preview than naive `truncate(180)` — the match is always visible in the snippet; the Sprint 7 admin short-circuit in `Note.visible_to` meant admin search "just works" without any search-specific authorization code.
- What didn't: first `SearchService#search_verses` called `Verse.with_pg_search_highlight.search_text(query)` but `with_pg_search_highlight` is a method on the pg_search relation, not on the class — had to flip the chain order to `search_text(query).with_pg_search_highlight`; initial request spec asserted `include("For God so loved the world")` but the rendered HTML was `"For God so <mark>loved</mark> the world"` — substring span interrupted by the `<mark>` wrap; split into three adjacent assertions instead; header "Search" link + form "Search" submit button both matched `click_on "Search"` in system specs (`Capybara::Ambiguous`) — switched to `find("input[type='submit'][value=...]").click`; the note-body-stores-HTML caveat (tag names hit as search tokens) is live but accepted for v1 with a documented remediation.
- Change next sprint: for pg_search scopes, write a "usage example" line in the model comment showing the exact chain order for highlights — `Model.search_x(q).with_pg_search_highlight`, not the other way around; when asserting substring content on a page that applies highlighting wrapping, split into boundary + inner-tag assertions up front rather than composing one big string; for any two page elements sharing a label (nav link + submit button), prefer `find("input[type=submit][value=...]")` from the start in system specs — saves the ambiguity round-trip; when Action Text becomes search-target content, decide upfront whether to live with HTML-tag-token noise or mirror plain text into a column — the "mirror to column" path is small and future-us might want it for Sprint 9 embeddings anyway.
- Size vs actual: estimated S (5-7 commits); actual 3 commits (pg_search scopes + model specs, SearchService + specs, search UI + controller + views + request/helper/system specs + i18n + layout link). Came in under on commit count because UI pieces (controller + view + partials + helper + tests + routes + layout + locales) all belong to one coherent search-page surface; splitting would have been churn. Real scope was right at S — the hard thinking was in the six upfront decisions, the code was short.

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
