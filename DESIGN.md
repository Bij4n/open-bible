# Design System — Open Bible

## Product Context

- **What this is:** A Bible reader with character-level highlights, rich-text notes, and social sharing. Users read, annotate, and discuss scripture — privately, with specific people, in groups, or publicly.
- **Who it's for:** People who read the Bible with intention: devotional readers, Bible study groups, scholars, anyone who wants their margin notes to live somewhere beautiful and permanent.
- **Space/industry:** Digital reading / spiritual formation. Adjacent to Readwise, Kindle, Logos Bible Software, YouVersion.
- **Project type:** Web app with editorial reading surfaces + social layer.
- **Memorable thing:** A quiet, devotional space. Reading here should feel different from using a digital product — calm, unhurried, made for dwelling. The design must never compete with the text.

---

## Aesthetic Direction

- **Direction:** Editorial / Devotional Minimal
- **Decoration level:** Intentional — the warm parchment surface and mint accent carry the aesthetic without layered decoration. Texture and character come from the serif reading font.
- **Mood:** Quiet authority. Not religious-institution stiff. Not SaaS-dashboard clinical. Warm enough for devotion, precise enough for scholarship. The design should feel like a well-made hardcover with a bookmark still in it.
- **What we are not:** YouVersion (consumer/megachurch app-feel), Logos Bible Software (dense reference-tool UI), Readwise (cold productivity tool).

---

## Typography

Three fonts, each with a specific role. No substitutions without architectural discussion.

### Display / UI

- **Font:** Inter (Variable)
- **Role:** Navbar, buttons, headings (h1–h6), labels, form elements, metadata, settings UI
- **Tailwind alias:** `font-ui`
- **CSS variable:** `--font-ui`
- **Loading:** Self-hosted. `InterVariable.woff2` + `InterVariable-Italic.woff2` in `public/fonts/`
- **Rationale:** Inter's variable axis covers every weight from 100–900 in one file. It's the right choice for UI chrome — legible at small sizes, neutral without being characterless. The warmth comes from the reading font; Inter's job is to get out of the way.
- **Base heading tracking:** `letter-spacing: -0.01em` (set globally in `@layer base`)

### Reading / Verse Body

- **Font:** Instrument Serif (400 regular + 400 italic)
- **Role:** Verse body, note body text, long-form reading, italic emphasis accents in hero headings
- **Tailwind alias:** `font-reading`
- **CSS variable:** `--font-reading`
- **Loading:** Self-hosted. `InstrumentSerif-Regular.woff2` + `InstrumentSerif-Italic.woff2` in `public/fonts/`
- **Rationale:** Serif type sustains dwell-reading attention better than sans at extended reading lengths. Instrument Serif has a contemporary cut that reads as modern editorial, not fusty or religious. Its italic is used expressively in the hero headline (`<em>` in `welcome_html`) and in red-letter Jesus words styling.
- **Chapter body line height:** `1.8` (generous — scripture is meant to breathe)
- **Chapter body max-width:** `70ch` (keeps lines inside the 50–75ch reading-comfort band)

### Code / Metadata / References

- **Font:** JetBrains Mono (Variable, 100–800)
- **Role:** Verse references (chapter:verse labels), eyebrow labels, code-like UI metadata
- **Tailwind alias:** `font-mono`
- **CSS variable:** `--font-mono`
- **Loading:** Self-hosted. `JetBrainsMonoVariable.woff2` in `public/fonts/`
- **Rationale:** Verse refs are structured identifiers — `John 3:16`, `Gen 1:1`. Monospace renders them as labels, not prose. The slight tracking at small sizes (~10–12px) reinforces the reference-label reading. JetBrains Mono has more character than Courier at small sizes without feeling like code.

### Type Scale

| Level       | Usage                            | Size                          |
|-------------|----------------------------------|-------------------------------|
| Hero H1     | Homepage headline                | `clamp(40px, 5.5vw, 68px)`    |
| H2 section  | Community, donate headings       | `text-2xl` / `sm:text-3xl`    |
| H3          | Card titles, reader chapter name | `text-xl`                     |
| Body large  | Hero subhead                     | `text-lg sm:text-xl`          |
| Body base   | Notes, form labels               | `text-base` (16px)            |
| Small       | Nav items, metadata, bylines     | `text-sm` (14px)              |
| Eyebrow     | Translation labels, section tags | `text-xs uppercase tracking-widest` |
| Verse number| In-text superscript refs         | `0.7em` (relative to verse body) |

---

## Color

### Approach

Restrained. One accent + warm neutrals. Color is used sparingly — it should feel significant when it appears.

### Surface Palette (Warm Parchment)

The surface scale is warm gray with a faint parchment tint. Not pure neutral, not obviously beige. Editorially warm without looking dated.

| Token              | Hex       | Usage                                               |
|--------------------|-----------|-----------------------------------------------------|
| `surface-50`       | `#f2f2ee` | Page background (light mode), input fills           |
| `surface-100`      | `#e8e7e2` | Trix toolbar, subtle hover fills                    |
| `surface-200`      | `#d4d3ce` | Borders (light mode), dividers                      |
| `surface-300`      | `#bebcb7` | Input borders, disabled state borders               |
| `surface-400`      | `#969490` | Placeholder text, de-emphasized labels              |
| `surface-500`      | `#696765` | Light mode muted text (4.8:1 AA on surface-50)      |
| `surface-500`      | `#8c8a86` | **Dark mode override** — lighter for dark bg contrast |
| `surface-600`      | `#535150` | Secondary text                                      |
| `surface-700`      | `#3c3b38` | Nav items, form text                                |
| `surface-800`      | `#252421` | Borders (dark mode), dark elevated surfaces         |
| `surface-900`      | `#181714` | Primary text (light mode)                           |
| `surface-950`      | `#0f0e0c` | Page background (dark mode), darkest chrome         |

### Accent (Mint)

The mint accent is the only brand color. It reads devotional-but-not-churchy — more like a forest than a medical green. Used for interactive states, the wordmark disc, and text selection tints.

| Token          | Hex       | Usage                                                              |
|----------------|-----------|--------------------------------------------------------------------|
| `accent-300`   | `#8ee1bc` | Dark mode subtle tints                                             |
| `accent-400`   | `#5dd4a0` | Dark mode interactive text, hover states, active locale pill       |
| `accent-500`   | `#15a06a` | Decorative/highlight only — 3.14:1 contrast, **fails AA as text** |
| `accent-600`   | `#0f8056` | Mid-range, used in mint glow effects                               |
| `accent-700`   | `#0f5c3f` | **Primary brand** — light mode interactive text, buttons, focus rings, wordmark |
| `accent-800`   | `#0a4530` | Hover state on dark accent-700 surfaces                            |

**Rule:** For interactive text on light surfaces, always use `accent-700`. For text on dark surfaces, use `accent-400` or `accent-300`. Never use `accent-500` as text color — it fails WCAG AA.

### Semantic Colors

| Purpose            | Light mode         | Dark mode          |
|--------------------|--------------------|--------------------|
| Jesus's words (red-letter) | `#991b1b` (red-800) | `#fca5a5` (red-300) |
| Focus ring         | `accent-700`       | `accent-400`       |
| Text selection     | `accent-700` at 25% | `accent-400` at 25% |
| Search mark        | `accent-700` at 22% | `accent-400` at 28% |

### Highlight Colors

Five highlight swatches for verse annotation. Each has a semi-transparent overlay (55% light / 35% dark) for in-text rendering and a full-opacity swatch for the toolbar.

| Name       | Swatch hex  | Overlay (light)              | Overlay (dark)               |
|------------|-------------|------------------------------|------------------------------|
| Gold       | `#e6c784`   | `rgba(230, 199, 132, 0.55)`  | `rgba(212, 165, 116, 0.35)`  |
| Rose       | `#e8b9b9`   | `rgba(232, 185, 185, 0.55)`  | `rgba(184, 138, 138, 0.35)`  |
| Sage       | `#b9d4b1`   | `rgba(185, 212, 177, 0.55)`  | `rgba(138, 160, 126, 0.35)`  |
| Lavender   | `#c6bfe0`   | `rgba(198, 191, 224, 0.55)`  | `rgba(138, 138, 184, 0.35)`  |
| Sky        | `#a7c6d4`   | `rgba(167, 198, 212, 0.55)`  | `rgba(126, 160, 176, 0.35)`  |

These colors are muted, desaturated, and warm. They should read as scholarly marginalia, not neon highlighters.

### Dark Mode Strategy

Dark mode is driven by `data-theme="dark"` on `<html>`, set synchronously before first paint to prevent flicker. Tailwind's media-query dark variant is overridden with `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))`.

Dark mode inverts the surface scale (50→950 for backgrounds, 900→100 for text). Accent colors shift from 700 to 400 — same hue, higher luminance against near-black. The result is a warm near-black that reads editorial rather than void.

Signed-in users get server-side theme resolution (no flash); signed-out users get a JS snippet that reads `localStorage` before any CSS fires.

---

## Spacing

- **Base unit:** 4px (Tailwind default)
- **Density:** Comfortable — generous reading space in the chapter view, tighter in nav/toolbar chrome
- **Spacing philosophy:** Let the text breathe. The reader spends minutes or hours on a single chapter; cramping the layout causes fatigue. UI chrome gets tighter spacing; reading surfaces get loose.

### Scale reference (Tailwind 4px-base)

| Label | Size | Common usage |
|-------|------|--------------|
| 1     | 4px  | Tiny gaps between inline elements |
| 2     | 8px  | Icon-to-label gaps, tight spacing |
| 3     | 12px | Internal padding on compact components |
| 4     | 16px | Standard card padding, form input padding |
| 5     | 20px | Wordmark mark shadow radius |
| 6     | 24px | Horizontal page padding (`px-6`) |
| 7     | 28px | Chapter header bottom padding |
| 8     | 32px | Section internal spacing |
| 10    | 40px | Card/panel generous padding |
| 12    | 48px | Section gaps within a page |
| 24    | 96px | Between major homepage sections (`space-y-24`) |

---

## Layout

### Page Structure

- **Max content width:** `max-w-5xl` (1024px) with `px-6` (24px each side) → 976px usable
- **Nav height:** ~57px (`py-4` on a 16px line-height element + 8px label)
- **Main padding:** `py-12` (48px top/bottom)
- **Reader container:** `max-w-3xl` (~768px) — narrower than the page container; chapter text is centered within the page

### Grid Patterns

| Surface | Layout |
|---------|--------|
| Homepage hero | `md:grid-cols-[1.1fr_1fr]` with `gap-x-12` at md+ |
| Settings page | Single column, centered at `max-w-5xl` |
| Bible reader | Single column, centered at `max-w-3xl` |
| Note panel | Fixed sidebar, `max-w-md` from right edge, `sm:rounded-l-2xl` |

### Key Surfaces

**Sticky header:** Position sticky, top 0, z-50. Background: `color-mix(surface-50/50 85%, transparent)` with `backdrop-filter: blur(12px)`. Bottom border is `transparent` at rest, gains `surface-200` color once `.scrolled` class is added (past 16px scroll). Same pattern in dark mode with `surface-950`.

**Note panel:** Fixed sidebar, slides in from the right via `translate: 0` on `body[data-note-panel-open="true"]`. 150ms ease-out. At `sm+` the panel is `max-w-md` with a rounded left edge; at mobile it's full-width and full-height inset.

**Account menu:** Bottom-sheet on mobile (`position: fixed`, `inset-inline: 0`, `bottom: 0`, `border-radius: 1rem 1rem 0 0`), floating dropdown at `sm+` (`position: absolute`, `right: 0`, `top: 100%`, `width: 15rem`). Shape change is pure CSS — no JS involved.

**Highlight toolbar:** Same bottom-sheet / floating-popover pattern as the account menu. Bottom-sheet on mobile, JS-positioned popover above the selection on desktop.

### Border Radius

| Scale | Value | Usage |
|-------|-------|-------|
| `rounded` | 4px | Tight chips, verse number labels |
| `rounded-md` | 6px | Form inputs, small cards, trix toolbar/editor |
| `rounded-lg` | 8px | Dropdowns, nav hovers, larger cards |
| `rounded-xl` | 12px | Hero empty state cards |
| `rounded-2xl` | 16px | Section containers, modal panels, note panel corner |
| `rounded-full` | 9999px | CTA buttons, hero meta pills, locale badges |

---

## Motion

- **Approach:** Minimal-functional. Motion only when it aids comprehension (panel slides, menu appear) or when it's architectural (theme transition). No decorative animation.
- **Philosophy:** The reading experience should be still. A blinking cursor in a feature demo is enough personality.

### Timing

| Type | Duration | Easing | Usage |
|------|----------|--------|-------|
| Theme transition | 150ms | ease | Background-color, color on `html` |
| Header border fade | 200ms | ease | border-color when scrolling |
| Header background | 300ms | ease | Background shift on scroll |
| Note panel slide | 150ms | ease-out | Panel translate |
| Nav hover colors | (Tailwind default `transition-colors`) | | Interactive states |
| Echo cursor blink | 1.1s | infinite | Decorative typing cursor (homepage only) |

### Reduced Motion

Global `@media (prefers-reduced-motion: reduce)` kills all animation and transition durations to `0.01ms`. This is a hard override — no per-component exceptions.

---

## Wordmark

The Open Bible logotype is the word "Open Bible" in Inter semibold with a mint disc preceding it — a 20×20px `border-radius: 50%` span with `background: accent-700` (light) / `accent-400` (dark) and two concentric shadow rings at 25% and 10% opacity. The disc is an `aria-hidden` decorative element; it renders brand presence without being a PNG asset.

```html
<span class="wordmark-mark" aria-hidden="true"></span> Open Bible
```

The glyph is the simplest possible expression of the mint brand color as a structural mark, not an icon.

---

## Special Text Treatments

### Red-Letter (Jesus's Words)

Verses attributed to Jesus are wrapped in `.jesus-words` which applies `color: #991b1b` (red-800) in light mode and `color: #fca5a5` (red-300) in dark mode, both WCAG AA. Font style is italic (Instrument Serif italic cuts sharp here).

Print stylesheet overrides `.jesus-words` to plain black italic — red ink prints muddy on B&W.

### Hero Emphasis (`<em>` in headings)

The hero H1 uses Instrument Serif italic via `.hero-emphasis em` — the `<em>` tag swaps the Inter run to Instrument Serif italic in `accent-700` (light) / `accent-400` (dark), breaks the heading weight back to 400 so the italic renders correctly, and tightens letter-spacing to `-0.02em` for serif rhythm against the surrounding sans.

### Verse Numbers

Verse numbers are rendered inline, `0.7em` relative to verse body, Inter medium weight, `line-height: 0` (no line-height contribution), `color-mix(surface-900 70%, transparent)` in light mode (~#5a5a5c, 5.7:1 AA), `color-mix(surface-100 55%, transparent)` in dark mode (~7:1 AAA).

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| Sprint 1 | Inter + Instrument Serif + JetBrains Mono | Three-font system: UI sans, devotional serif, monospace refs. Each has a distinct role; no font doubles up. |
| Sprint 1 | Warm parchment surface scale, not pure neutral gray | Editorially warm without looking old-fashioned. Competes less with the text. |
| Sprint 4 | Mint accent (#0f5c3f) over prior bronze | More distinctive against SaaS blue/teal field. Reads devotional-natural, not corporate. |
| Sprint 4 | Self-hosted fonts, no Google Fonts | CLAUDE.md constraint (no Google-hosted dependencies). All three fonts are OFL-licensed. Variable fonts = one file covers every weight. |
| Sprint 4 | data-theme dark mode, not prefers-color-scheme | User preference wins over OS setting. Stored in user model (signed-in) and localStorage (signed-out). Server-side resolution prevents first-paint flash for signed-in users. |
| Sprint 11 | Bottom-sheet pattern for mobile menus | Account menu and highlight toolbar both use fixed bottom-sheet on mobile, standard dropdown/popover on desktop. Pure CSS shape change, no JS controller changes. |
| Sprint 16 | accent-500 restricted to decorative use only | accent-500 (#15a06a) is 3.14:1 contrast on surface-50 — fails WCAG AA. Documented in CSS to prevent future misuse. Use accent-700 for interactive text on light. |
| 2026-04-24 | verse-number alpha: 70% light / 55% dark | 55% on light surface produced 3.88:1 — axe failure. 70% lands at 5.7:1. Asymmetry between modes is intentional (dark bg is darker). |
| 2026-05-26 | DESIGN.md created from running code | Codified the evolved design system that existed in CSS without documentation. Memorable thing: "a quiet, devotional space." |
