# Open Bible

A Ruby on Rails web app for reading, highlighting, annotating, and sharing the
Bible — collaboratively or publicly. Bilingual (English KJV + Spanish RV1909),
with character-level highlights, rich-text notes, threaded community
discussion, keyword and semantic search, and a modern reading-focused design
(Inter UI sans, Instrument Serif body + verse, JetBrains Mono refs, mint
accent on cool near-white paper / cool near-black dark).

## Features

**Reading**
- Two public-domain translations shipped: King James Version (KJV) and
  Reina-Valera 1909 (RV1909). Translation picker preserves book and chapter
  across switches.
- Red-letter Jesus words, rendered from character-offset ranges captured at
  import time. RV1909 inherits KJV's red coverage at verse granularity (its
  source doesn't tag `<q who="Jesus">`).
- Modern reading chrome — Inter UI, Instrument Serif for verse + italic
  accents, JetBrains Mono for refs and labels, mint accent (`#0F5C3F`)
  on a cool near-white paper. Cool near-black dark mode.
- Bilingual interface (English + Spanish), independent of the translation
  being read.

**Annotation**
- Character-level highlights in five muted colors. OSIS-ref anchoring means
  highlights survive schema changes and map cleanly across translations at
  the verse level.
- Action Text rich-text notes attached to one or more highlights.
- Visibility controls per note: private, shared with specific users, shared
  with groups, or public.
- Threaded comments on any visible note.

**Collaboration**
- Group Bibles with real-time broadcast via Action Cable — a note shared
  with a group appears immediately for others reading the same chapter,
  with edits + new comments broadcast through the same channel.
- Two ways to grow a group: copy-paste a 6-8-char invitation code, or
  send an email invitation that delivers a tokenized "Accept" link
  (signed cookie carries the token across sign-up so brand-new users
  can join in one flow). Owner cancels any pending invite from the
  group page.

**Community**
- Public Bible view surfaces featured + recent community notes beside
  the text. Homepage spotlights one admin-featured public note in the
  hero verse card; a 3-card community section below shows the next
  most-recent public notes.
- Upvoting, flagging, and admin moderation (feature/hide notes, resolve
  flags, soft-delete abusive content).
- Custom branded 404 / 422 / 500 pages (static fallbacks + dynamic
  views inside the application layout).

**Search**
- Keyword search over verse text and public note bodies via `pg_search`
  (Postgres full-text), with `ts_headline` highlight wrapping.
- Semantic search via a local Python embedding service
  (`sentence-transformers/all-MiniLM-L6-v2`), with cosine similarity
  computed in Ruby over JSON-stored vectors. Graceful fallback to keyword
  when the embedding service is unavailable.
- Scope radios: verses only / notes only / both; current translation only /
  all translations.

**Accessibility**
- WCAG 2.1 AA compliant (automated check via `axe-core-rspec` on every
  major surface).
- Mint-accent focus indicators on `:focus-visible` (mint-700 light,
  mint-400 dark).
- Honors `prefers-reduced-motion` globally — covers the 150ms theme-flip
  crossfade and any future Tailwind transition.
- Tri-state theme toggle (Light / Dark / System); System mode tracks OS
  `prefers-color-scheme` live.
- Print stylesheet for typeset chapter output.

## Stack

- **Ruby** 3.4.9 / **Rails** 8.1.3
- **PostgreSQL** 16 (with `pg_search`)
- **Hotwire** (Turbo + Stimulus) + **Tailwind CSS v4**
- **Import maps** (no esbuild or webpacker)
- **Action Text** for note bodies, **Action Cable** for real-time,
  **Solid Queue** for background jobs, **Solid Cache** for caching
- **Devise** + **devise-i18n** for authentication
- **Python** embedding service: FastAPI + uvicorn +
  `sentence-transformers/all-MiniLM-L6-v2`
- **Testing**: RSpec, FactoryBot, Capybara, Selenium, WebMock,
  axe-core-rspec

## Getting started

Requirements: Ruby 3.4.9 (via asdf or similar), PostgreSQL 16+, Python 3.11+
(only if you want semantic search).

```bash
bin/setup                          # install gems, prepare dev + test DBs
bin/rails bible:import[kjv]        # ~30s; downloads + imports KJV
bin/rails bible:import[rv1909]     # ~10s; downloads + imports RV1909,
                                   # auto-mirrors red-letter ranges from KJV
bin/dev                            # Rails server + Tailwind watcher +
                                   # Python embedding service via Procfile
```

Visit `http://localhost:3000` and the public bible at
`/public/bible/kjv/john/3`. Sign up to create highlights and notes.

If you don't need semantic search, skip the Python dependency:

```bash
EMBEDDING_SERVICE_SKIP=1 bin/dev   # embedding slot no-ops, foreman keeps
                                   # web + css running
```

Generating embeddings (one-time, ~15–20 min on CPU):

```bash
bin/rails embeddings:generate      # KJV only for now; runs against the
                                   # running Python service
```

## Development

```bash
bundle exec rspec                  # full test suite (~18s)
bundle exec rubocop                # omakase style
bundle exec rubocop -a             # autocorrect safe offenses
bundle exec erb_lint --lint-all    # view templates
bundle exec brakeman               # security scan
```

Run a single spec file:

```bash
bundle exec rspec spec/services/bible/osis_importer_spec.rb
```

The suite includes automated WCAG 2.1 AA checks on key surfaces via
`spec/system/accessibility_spec.rb`.

## Bible content and provenance

Both shipped translations are public domain, SHA-pinned at import, and
documented in `config/bible_sources.yml`:

- **KJV** — 1769 standardised text. Source:
  [seven1m/open-bibles](https://github.com/seven1m/open-bibles)
  (`eng-kjv.osis.xml`), re-encoded from eBible.org's USFX via Haiola.
- **RV1909** — Reina-Valera 1909 Spanish. Source:
  [gratis-bible/bible](https://github.com/gratis-bible/bible)
  (`es/sparv.xml`). The upstream file is labeled only "Spanish Reina-Valera"
  without a year; text-level markers (archaic `crió` at Gen 1:1, unaccented
  `JEHOVA` at Ps 23:1, `á su Hijo unigénito` at John 3:16) identify it as
  the 1909 edition and rule out RVA (1989), SEV (1865), and the
  copyrighted RVR1960.

The OSIS importer handles both milestone-style (seven1m/Haiola flavor) and
container-style (ZefToOsis flavor) OSIS 2.1.1 dialects.

## Architecture

- **Models** in `app/models/` — core domain. `Verse`, `Highlight`, `Note`,
  `Comment`, `Group`, `Membership`, etc.
- **Services** in `app/services/` — domain operations that don't belong on
  a model. `Bible::OsisImporter`, `Bible::RedLetterMirror`, `SearchService`,
  `SemanticSearchService`, `EmbeddingService`, `OsisRef`.
- **Controllers** thin; business logic pushed to services.
- **Stimulus controllers** in `app/javascript/controllers/`, one per concern.
- **Python embedding service** in `services/embedding-service/`, launched
  via `bin/embedding` from `Procfile.dev`.
- **I18n keys** mirror view paths (`app.bible.reader.chapter_heading` for
  `app/views/bible/reader/chapter.html.erb`).

Development history and decision log live in `PLAN.md`. Project conventions
(TDD discipline, commit style, confidence flagging) are in `CLAUDE.md`.

## License

MIT. See `LICENSE`.
