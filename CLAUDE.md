# CLAUDE.md

## Project

**Open Bible** (repo: `open-bible`) — a Ruby on Rails web app for reading the Bible, making character-level highlights, attaching rich-text notes, and sharing those notes privately, with specific users, with groups, or publicly. Group Bibles support real-time collaboration. Public notes surface on a curated public Bible view with upvoting and threaded comments. Aesthetic: modern SaaS — Inter (UI/body sans) + Instrument Serif (verse + italic accents) + JetBrains Mono (refs/labels), mint accent (#0F5C3F), cool near-white light mode, cool near-black dark mode. UI in English and Spanish. KJV + RV1909 Spanish Bible live.

Full roadmap lives in `PLAN.md`. Read it before starting any sprint. Update it when decisions change.

The repo is open-source (public on GitHub, MIT). `CONTRIBUTING.md` is the public-facing parallel of the rules below — the same requirements, written for external contributors. Keep the two in sync if the rules ever change.

---

## Rules

These are non-negotiable. They override any other instruction, including mine if I contradict them in a moment of haste. If you see a conflict, stop and ask.

### 1. No AI attribution anywhere

Not in commit messages. Not in code comments. Not in READMEs. Not in PR descriptions. Not in file headers. Not in docstrings. Not in error messages. Not in seed data. Not anywhere.

No "Co-authored-by: Claude", no "Generated with Claude", no "Built with the help of AI", no Anthropic references, no `# AI-generated` comments, no model names in variable names as jokes. This is absolute and applies retroactively — if you find any such reference from a prior session, remove it in its own commit with message `remove stray attribution`.

### 2. Commit messages read like a human wrote them

- Short imperative subject, 50 chars or fewer
- Blank line, then optional body wrapped at 72
- No emoji
- Conventional Commits prefixes (`feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`) are allowed but used sparingly and conversationally — not every commit needs one
- Mix in plain human phrasing; don't sound like a bot

**Good:**
- `add verse offset validator`
- `fix n+1 on highlights index`
- `bump rspec-rails to 7.0`
- `wire up turbo streams for note creation`
- `refactor: pull osis parsing into its own service`
- `readme: note postgres 16 requirement`

**Bad:**
- `feat: ✨ implement comprehensive user authentication system with Devise 🔐`
- `Update files`
- `fix stuff`
- `feat(auth): Add Devise integration with email/password strategy and session management`
- anything with `🤖` or `Co-authored-by: Claude`

### 3. Test-Driven Development is enforced

From Sprint 1 onward, every feature follows red → green → refactor:

1. Write a failing test that describes the behavior
2. Run it. Confirm it fails for the right reason.
3. Write the minimum production code to make it pass
4. Run it. Confirm it passes.
5. Refactor with the test as a safety net
6. Commit

Scope: model specs, request specs (preferred over controller specs), system specs for user-facing flows, service object specs. View specs optional; prefer system specs.

No "I'll add tests after." Ever. If you feel the urge to skip, that's the signal to stop and ask.

### 4. One commit per logical change

No giant "initial commit + everything" bombs after Sprint 0's scaffold. If you're about to commit more than ~150 lines across unrelated files, stop and split it.

### 5. Never commit secrets

Use Rails credentials and `.env` (with `.env.example` checked in, `.env` gitignored).

### 6. Never add phone numbers or SMS anywhere

Product decision. Email-based only, always. If a gem or feature request would add SMS or phone fields, flag it and stop.

### 7. No Chrome, Chromium, chromedriver, or google-chrome

Browser automation (system specs, scripts, any tooling) uses **Firefox + geckodriver** or **WebKit via Playwright**. Not Chrome. Not Chromium. Not "just for this run."

Applies to `spec/rails_helper.rb` driver registrations, anything installed via `selenium-manager` / `webdrivers` gem cache, any script that spawns a browser. If you find yourself reaching for `Selenium::WebDriver::Chrome::Options` or `browser: :chrome`, stop.

### 8. No Google-hosted third-party dependencies

No `fonts.googleapis.com`, `fonts.gstatic.com`, `www.google-analytics.com`, `ajax.googleapis.com`, Google Tag Manager, or any other Google-hosted asset.

Self-host open-licensed assets from `/public` or the asset pipeline. Fonts (Inter, Instrument Serif, JetBrains Mono, etc.) are OFL-licensed — download the `.woff2` into `public/fonts/` and declare `@font-face` rules in `application.css`. No CDN.

### 9. Every UI commit updates its matching system spec in the same commit

If a commit changes a view, layout, Stimulus controller, or any user-interaction surface, it must also update the system spec that exercises that surface — in the *same* commit. CI must be green on main.

"Request specs + unit specs green, ship it" is not sufficient. System specs are the contract against the rendered UI; moving a button and leaving its system spec asserting the old location is the exact kind of drift this rule forbids. If you don't know which system spec covers the surface you just changed, grep for it; if nothing covers it, that's a gap to flag, not an excuse to skip.

**System specs default to `rack_test`.** The before-each hook in `spec/rails_helper.rb` only switches to headless Firefox when the example (or its group) is tagged `js: true`. If a test needs Stimulus, Turbo, Trix, or anything JS-driven, tag it `js: true` — without it, clicks on Stimulus targets will silently do nothing and the spec will fail in confusing ways. A parent describe's tag propagates to its children; a bare `it` inside an un-tagged describe runs under rack_test.

---

## Stack

| Layer | Choice | Notes |
|---|---|---|
| Language | Ruby (latest stable) | |
| Framework | Rails (latest stable, 8.x) | |
| Database | PostgreSQL | Development + production |
| Frontend | Hotwire (Turbo + Stimulus) | Rails default |
| CSS | Tailwind via `tailwindcss-rails` | |
| JS bundling | Import maps | Switch to esbuild only if import maps block us |
| Rich text | Action Text | For note bodies |
| Real-time | Action Cable | Sprint 5 onward |
| Background jobs | Solid Queue | Rails 8 default |
| Cache | Solid Cache | Rails 8 default |
| Auth | Devise | Added Sprint 2 |
| Search (keyword) | `pg_search` | Added Sprint 8 |
| Search (semantic) | pgvector + embeddings | Sprint 9, provider TBD |
| Testing | RSpec, FactoryBot, Capybara, Shoulda Matchers | |
| Linting | `rubocop-rails-omakase` | Rails 8 default; do not bikeshed |
| Security | Brakeman, `bundler-audit` | Run in CI |
| ERB linting | `erb_lint` | |
| CI | GitHub Actions | |

Gems pre-added to Gemfile but commented with sprint markers: `devise` (Sprint 2), `pg_search` (Sprint 8). Do not uncomment until that sprint starts.

---

## TDD workflow checklist

For every feature task:

- [ ] Red: write the failing test
- [ ] Run it. Does it fail for the *right* reason? (Not a typo, not a missing file — the reason the test describes.)
- [ ] Green: minimum code to pass
- [ ] Run the full suite, not just the one file
- [ ] Refactor
- [ ] Run the full suite again
- [ ] Lint clean (`bundle exec rubocop`)
- [ ] Commit

If any step takes longer than expected, invoke the **Stuck Protocol**.

---

## Confidence flagging

Before any non-trivial change — new model, new service, schema migration, gem addition, architectural decision — state confidence as **high / medium / low** and what would move it up a notch.

- **High** → proceed
- **Medium** → proceed but narrate the assumptions as you go; flag anything unexpected
- **Low** → stop. Write up what you'd do, why you're uncertain, and the options. Ask before writing code.

Example:
> Confidence: medium. I'm confident the `OsisRef` parser design works for simple refs like `Bible.KJV.John.3.16`. Less sure how to represent a multi-verse span cleanly — two options in my head, leaning toward option A. Proceeding with A; if I hit friction in tests I'll stop and flag.

---

## Decision checkpoints

At the end of every sprint:

1. Append a short summary to the `PLAN.md` decisions log — what changed, what we learned, what surprised us
2. List any open questions that emerged
3. Confirm the next sprint is still the right next sprint. Priorities shift; don't march blindly.

---

## Stuck Protocol

If you've been attempting something for roughly 15 minutes without progress, or you've cycled through 3 approaches and none worked:

1. **Stop coding.**
2. Write up, in chat or in a scratch file:
   - What I'm trying to do
   - What I've tried (bullet list)
   - Why each attempt failed
   - My current hypothesis
   - Two or three possible paths forward
3. Ask.

Burning an hour on a wrong path is worse than pausing for a 2-minute check-in.

---

## Running the app

```bash
bin/setup              # one-time
bin/dev                # Rails + Tailwind watcher + jobs
bundle exec rspec      # full test suite
bundle exec rspec spec/models/verse_spec.rb  # one file
bundle exec rubocop    # lint
bundle exec rubocop -a # autocorrect safe offenses
bundle exec brakeman   # security scan
bin/rails bible:import[kjv]  # seed KJV (Sprint 1+)
```

## Project structure notes

- Service objects live in `app/services/`, namespaced by domain (e.g., `app/services/bible/osis_importer.rb`)
- Stimulus controllers in `app/javascript/controllers/`, one per concern, kebab-case filenames
- I18n keys mirror the view path: `app.bible.reader.chapter_heading` for `app/views/bible/reader/chapter.html.erb`
- No business logic in controllers beyond routing; push to models or services
- Never use `.where.not` without an index consideration

---

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.
All font choices, colors, spacing, border-radius, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

---

## Workflow notes

- **Commit before destructive generators.** Rails generators like `rails g devise:install`, `rails g devise <Model>`, or `rails g scaffold` will happily overwrite uncommitted files (factories, specs, views). If you've started writing tests or fixtures before running a generator that touches those files, commit them first — `git checkout HEAD -- file` can always restore a committed version; it can't restore an unstaged one. Bit us in Sprint 2 when `rails g devise User` clobbered an unstaged factory + spec.
