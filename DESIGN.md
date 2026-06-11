# Design System — Open Bible

## Product Context

- **What this is:** A Bible reader with character-level highlights, rich-text notes, and social sharing. Users read, annotate, and discuss scripture — privately, with specific people, in groups (Bible studies), or publicly.
- **Who it's for:** People who read the Bible with intention: devotional readers, Bible study groups, scholars, anyone who wants their margin notes to live somewhere simple and permanent.
- **Space/industry:** Digital reading / spiritual formation. Adjacent to Medium, Readwise, Kindle, Hypothes.is.
- **Project type:** Web app with editorial reading surfaces + social layer.
- **Memorable thing:** Reading here should feel like Medium feels for essays — a clean white page, beautiful serif text, and your marks living quietly in the margins. Simple and friendly, never churchy, never dashboard-y. The design must never compete with the text.

This file is the source of truth as of Sprint R1 (2026-06). The redesign rationale,
research, and remaining sprint plan live in `REDESIGN.md`.

---

## Aesthetic Direction

- **Direction:** Medium-clean editorial reading + Grammarly-soft friendliness
- **Decoration level:** Minimal — whitespace, one green, soft rounded cards. No ornament; texture comes from the reading serif.
- **Mood:** Calm, generous, friendly. A quiet page that makes the text big and comfortable and keeps every control one obvious click away.
- **What we are not:** YouVersion (feed-first/megachurch app-feel), Logos (dense reference-tool UI), the previous manuscript and parchment eras of this app.

---

## Typography

Two working families (plus mono, which is being retired from product UI in Sprint R2).

### Reading / Verse Body

- **Font:** Source Serif 4 (Variable, OFL)
- **Role:** Verse body, note bodies, long-form reading, italic emphasis accents in hero headings
- **Tailwind alias:** `font-reading` · **CSS variable:** `--font-reading`
- **Loading:** Self-hosted. `SourceSerif4Variable.woff2` + `SourceSerif4Variable-Italic.woff2` in `public/fonts/` (TTF-flavored variable woff2, weights 200–900 + optical-size axis)
- **Rationale:** At text sizes its optical-size axis renders a Charter-like cut — the same DNA as Medium's reading face — license-clean and self-hostable, with full coverage for KJV archaic forms and RV1909 Spanish diacritics.
- **Chapter body:** `clamp(1.0625rem, 0.95rem + 0.55vw, 1.25rem)` (17px mobile → 20px desktop), line-height `1.7`, measure `max-width: 42rem` (~672px)

### Display / UI

- **Font:** Inter (Variable, OFL)
- **Role:** Navbar, buttons, headings (h1–h6), labels, forms, metadata
- **Tailwind alias:** `font-ui` · **CSS variable:** `--font-ui`
- **Loading:** Self-hosted. `InterVariable.woff2` + `InterVariable-Italic.woff2`
- **Base heading tracking:** `letter-spacing: -0.01em`

### Mono (being retired)

JetBrains Mono (`font-mono`) still renders verse refs and eyebrow labels until Sprint R2
re-skins the chrome; new work should use Inter `text-xs font-medium uppercase
tracking-wide` for eyebrows/refs instead. Do not add new mono usage.

### Type Scale

| Level | Usage | Size |
|---|---|---|
| Hero H1 | Homepage headline | `clamp(40px, 5.5vw, 68px)` |
| H2 section | Section headings | `text-2xl` / `sm:text-3xl` |
| H3 | Card titles, reader chapter name | `text-xl` |
| Reading body | Chapter text, note bodies | 17→20px fluid (see above) |
| Body base | Forms, labels | `text-base` (16px) |
| Small | Nav items, metadata | `text-sm` (14px) |
| Eyebrow | Section tags, refs | `text-xs uppercase tracking-wide` |
| Verse number | In-text superscript | `0.7em` relative to verse body |

---

## Color

### Approach

Medium's formula: pure white ground, soft near-black ink, two or three grays, and **one
green that always means something** (action, link, brand). Hue budget is strict — green
= brand/action; highlight pastels = user content; red = destructive + red-letter;
everything else is gray.

### Surface palette (cool neutrals, white ground)

Token *names* are unchanged from the previous system (`surface-50…950`) — Sprint R1
re-valued them in place so no view markup changed.

| Token | Hex | Usage |
|---|---|---|
| `surface-50` | `#ffffff` | Page background (light), input fills |
| `surface-100` | `#f6f6f4` | Wells, toolbar fills, subtle hover |
| `surface-200` | `#e9e9e7` | Hairline borders (light), dividers |
| `surface-300` | `#d8d8d5` | Input borders, disabled borders |
| `surface-400` | `#9a9a98` | Placeholders, de-emphasized labels |
| `surface-500` | `#6b6b6b` | Muted text light (5.0:1 AA on white) — **dark override `#a3a3a1`** |
| `surface-600` | `#515150` | Secondary text |
| `surface-700` | `#3b3b3a` | Nav items, form text |
| `surface-800` | `#27282b` | Borders (dark), dark elevated surfaces |
| `surface-900` | `#242424` | Primary text (light) — Medium's ink |
| `surface-950` | `#101113` | Page background (dark) |

### Accent (Medium green)

Anchored on Medium's `#1A8917`. As with surfaces, the existing token names were
re-valued: light-mode interactive stays on `accent-700`, dark-mode on `accent-400`.

| Token | Hex | Usage |
|---|---|---|
| `accent-50` | `#f1f8f0` | Faint tints, outline-button hover fill |
| `accent-100` | `#dff1dd` | Badge backgrounds (light) |
| `accent-300` | `#7ece79` | Dark-mode subtle/hover |
| `accent-400` | `#53c24e` | **Dark-mode interactive** (~8.5:1 on surface-950) |
| `accent-500` | `#2ca827` | Decorative only — fails AA as text on white |
| `accent-600` | `#22991e` | Mid-range, glow effects |
| `accent-700` | `#1a8917` | **Primary brand** — light-mode interactive text, buttons, focus rings, wordmark (4.55:1 AA on white) |
| `accent-800` | `#136f10` | Hover on light |
| `accent-900` | `#0e540c` | Badge backgrounds (dark, at /40 alpha) |

Note: `accent-400` is a lightened cut of the brand hue (hue-consistent across themes),
not the teal-mint `#4CC38A` sketched in REDESIGN.md §3 — toggling themes shouldn't
shift the brand's hue.

**Rule:** interactive text on light = `accent-700`; on dark = `accent-400`/`accent-300`.
Never `accent-500` as text.

### Semantic colors

| Purpose | Light | Dark |
|---|---|---|
| Jesus's words (red-letter) | `#b42318` (6.6:1) | `#f97066` (6.9:1) |
| Focus ring | `accent-700` | `accent-400` |
| Text selection | `accent-700` @ 25% | `accent-400` @ 25% |
| Search mark | `accent-700` @ 22% | `accent-400` @ 28% |

Red-letter text is upright roman — color alone carries the signal on screen. The print
stylesheet still demotes it to italic black (mono printers).

### Highlight colors (user content)

Four-color Readwise-saturation palette (Sprint R3). Yellow is the one-click default
on the toolbar's labeled Highlight button. Legacy stored colors render-map with no
data migration: gold→yellow, sage→green, sky+lavender→blue — in CSS *and* in the
toolbar's active-swatch matching (a gold highlight marks yellow active and toggles
off through it). Other people's highlights will render as dotted underline + count,
never fill (R4).

| Name | Swatch | Overlay (light) | Overlay (dark) |
|---|---|---|---|
| Yellow (default) | `#fbda83` | 45% | 26% |
| Green | `#a9d9a4` | 40% | 24% |
| Blue | `#8dbbff` | 35% | 24% |
| Rose | `#e4938e` | 35% | 24% |

The highlight toolbar is a **dark floating pill in both themes** (tooltip chrome, not
page chrome): `Highlight | ●●●● | Note ×`. The note composer carries visibility on the
**Post-to button** (`Post to: Only me ▾` — Only me / Specific people / My studies /
Public), the Hypothes.is pattern; the amber confirm warning guards Public.

### Dark mode strategy

Unchanged mechanics: `data-theme="dark"` on `<html>` set before first paint; Tailwind's
dark variant overridden by `@custom-variant`. Dark mode inverts the surface scale and
shifts accent 700→400. Signed-in users get server-side resolution; signed-out get the
localStorage snippet.

---

## Spacing

- **Base unit:** 4px (Tailwind default)
- **Philosophy:** Let the text breathe. Reading surfaces get loose spacing; chrome gets tight. Generous padding is the friendliness — softness instead of decoration.

| Label | Size | Common usage |
|---|---|---|
| 2 | 8px | Icon-to-label gaps |
| 3 | 12px | Compact component padding |
| 4 | 16px | Form input padding |
| 6 | 24px | Horizontal page padding (`px-6`), card padding |
| 8 | 32px | Section internal spacing |
| 12 | 48px | Section gaps |
| 24 | 96px | Between major homepage sections |

---

## Layout

- **Max content width:** `max-w-5xl` (1024px) with `px-6`
- **Reader measure:** `42rem` (~672px) via `.chapter-body` — the Medium column
- **Note panel:** fixed right sidebar, `max-w-md`, slides in on `body[data-note-panel-open]`
- **Mobile menus/toolbars:** bottom-sheet pattern below 640px, popover/dropdown above

### Border radius

| Scale | Value | Usage |
|---|---|---|
| `rounded-md` | 6px | Form inputs, trix |
| `rounded-lg` | 8px | Buttons, dropdowns, small cards |
| `rounded-xl` | 12px | Cards |
| `rounded-2xl` | 16px | Section containers, panels, sheets |
| `rounded-full` | 9999px | Primary CTA pill, tags |

### Shadows

Hairline borders (`surface-200`/`surface-800`) carry edges; shadows only on floating
elements (toolbar, sheets, popovers): `0 4px 24px rgb(0 0 0 / 0.08)`-class softness.

---

## Motion

Minimal-functional, unchanged: 150ms theme crossfade, 150ms panel slide, 200–300ms
header border/background, Tailwind `transition-colors` on interactive states. Global
`prefers-reduced-motion` kill-switch. No decorative animation.

---

## Wordmark

"Open Bible" in Inter (400 "Open" / 720 "Bible") with the 20×20 accent disc
(`.wordmark-mark`) — now Medium green. Unchanged structurally.

---

## Decisions Log

| Date | Decision | Rationale |
|---|---|---|
| Sprint 1 | Three-font system (Inter / Instrument Serif / JetBrains Mono) | Superseded 2026-06 |
| Sprint 4 | Self-hosted fonts, no Google Fonts | CLAUDE.md constraint; still binding |
| Sprint 4 | data-theme dark mode | User preference wins over OS; unchanged |
| Sprint 11 | Bottom-sheet pattern for mobile menus | Unchanged |
| 2026-05-26 | DESIGN.md created from running code | Superseded by this rewrite |
| 2026-06-11 | **Design v3 (Sprint R1):** Source Serif 4 replaces Instrument Serif; pure-white/cool-neutral surfaces replace warm parchment; Medium green `#1A8917` replaces forest mint; red-letter de-italicized; reader at 17→20px/1.7/42rem | Owner directive: Medium/Grammarly direction. Full rationale in REDESIGN.md |
| 2026-06-11 | Token names kept, values swapped | ~190 view callsites already use `surface-*`/`accent-*`; re-valuing in place re-skins the app with zero markup churn (lesson of Sprints 12–14) |
| 2026-06-11 | `accent-400` = `#53c24e`, not REDESIGN's `#4CC38A` | Hue consistency across themes; toggling dark mode shouldn't shift brand hue from green to mint |
| 2026-06-11 | `accent-50/100/900` defined for the first time | They were referenced in views (notes badge, discover hover) but missing from `@theme` — Tailwind tree-shook them silently (same failure mode as the Sprint 24 surface-400/600 bug) |
