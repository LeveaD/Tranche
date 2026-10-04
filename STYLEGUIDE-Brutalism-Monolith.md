# ⬛ Monolith Design System & Styleguide

> **Design Direction:** Raw Web Brutalism (Anti-Design / Typographic Brutalism)
> **Brand Identity:** Independent Publishing, Research Archive & Editorial Platform
> **Theme:** `data-theme="monolith"` (default) · `data-theme="monolith-inverted"`
> **Version:** 1.0.0 (October 2026) — third entry in the Brutalism family alongside Meridian and Kiln

---

### How Monolith relates to Meridian & Kiln

All three systems are brutalist: **zero border-radius, no gradients, no blur, honest structure, no decoration pretending to be function.** But each takes a different branch of the tradition.

| | **Meridian (Concrete)** | **Kiln (Neo-Brutalist)** | **Monolith (Raw Web)** |
| :--- | :--- | :--- | :--- |
| Inspiration | Industrial signage, mission control | Zines, stickers, screen-print | Raw HTML, newspapers, 1990s web, concrete architecture |
| Palette | Gray concrete + signage accents | Warm paper + saturated fills | **Pure black & white + one clashing accent** |
| Depth | Hard offset shadows | Hard offset shadows | **None. No shadows at all** — hierarchy by rules, scale, and inversion |
| Type | Condensed display + grotesque + mono | Chunky display + friendly sans + mono | **System serif + monospace; oversized, tight, unadorned** |
| Links | Styled buttons | Styled buttons | **Underlined, visibly links** |
| Layout | Panels on a grid | Overlapping stickers | **Asymmetric columns, tables, hard rules, raw document flow** |
| Tone | "A wall, a label, a warning." | "A sticker, a poster, a dare." | **"A document. Read it."** |

Monolith is the most austere of the three. Meridian and Kiln still build *objects* (slabs, stickers). Monolith builds *documents*: text, rules, tables, and almost nothing else.

---

## 1. Design Philosophy

Monolith is built on the concept of **"The Page Is the Interface"** — a web page is a document, and the document should look like what it is.

- **Document First:** Content is laid out the way HTML wants to lay it out — headings, paragraphs, lists, tables, rules. Components are styled HTML elements, not bespoke widgets.
- **Black on White, Full Stop:** Two colors do 95% of the work. Hierarchy is made with **size, weight, rules, and inversion** (white on black), not with tints or shadows.
- **One Clashing Accent:** A single hostile, saturated color (signal yellow-green or electric blue) is used for selection, focus, and one highlighted thing per page. It is meant to look slightly wrong.
- **Visible Links, Visible Structure:** Links are underlined. Tables have borders. Sections are separated by thick horizontal rules. Nothing is hidden behind hover.
- **Scale as Hierarchy:** Headlines are enormous and tightly leaded; body text is small, dense, and left-aligned. The contrast between them *is* the design.
- **No Motion Theatre:** Pages don't animate in, float, or parallax. State changes are instant. The only motion allowed is a blinking cursor and a marquee for ticker content.
- **Anti-Polish, Not Anti-Craft:** The roughness is deliberate and precise. Alignment is exact; spacing is on a strict scale. It looks raw because it is *stripped*, not because it is sloppy.

---

## 2. Color Palette & Token System

Monolith's palette is almost entirely **ink and paper**. The accent is the exception that proves the rule.

### 2.1 CSS Variables (`:root`)

```css
:root, [data-theme="monolith"] {
  /* Core — ink and paper */
  --paper:        #ffffff;   /* Page background */
  --ink:          #000000;   /* All text, rules, borders */
  --ink-mid:      #555555;   /* Secondary text, captions (7.5:1 on paper) */
  --ink-faint:    #d4d4d4;   /* Hairline table rows, disabled borders */
  --paper-tint:   #f2f2f2;   /* Zebra rows, code blocks, quote blocks */

  /* The Accent — deliberately aggressive */
  --accent:       #e6ff00;   /* Acid yellow-green — selection, focus, highlight */
  --accent-ink:   #000000;   /* Text on accent is ALWAYS black */

  /* Link colors — default-web inspired */
  --link:         #0000ee;   /* Unvisited — the classic browser blue */
  --link-visited: #551a8b;   /* Visited — the classic browser purple */
  --link-active:  #ff0000;   /* Active — the classic browser red */

  /* Status — stripped to the minimum, always paired with text labels */
  --ok:           #000000;   /* Shown as: [OK] on white */
  --warn:         #000000;   /* Shown as: [!] with accent highlight */
  --error:        #ff0000;   /* Shown as: ERROR on white, or white on red block */

  /* Rules & Borders */
  --rule-hair:    1px;
  --rule:         2px;
  --rule-heavy:   4px;
  --rule-monolith: 8px;      /* Reserved for page-level dividers */

  /* Radius — none. */
  --radius:       0;
}

[data-theme="monolith-inverted"] {
  --paper:        #000000;
  --ink:          #ffffff;
  --ink-mid:      #aaaaaa;
  --ink-faint:    #333333;
  --paper-tint:   #111111;
  --link:         #8ab4ff;
  --link-visited: #c9a6ff;
  --link-active:  #ff6b6b;
  --error:        #ff6b6b;
}
```

### 2.2 Color Tokens & Intent

| Token | Value | Role & Visual Intent |
| :--- | :--- | :--- |
| `--paper` | `#ffffff` | The page. Pure white — no warmth, no texture. |
| `--ink` | `#000000` | All primary text, rules, borders, and inverted blocks. |
| `--ink-mid` | `#555555` | Captions, metadata, timestamps. The only "gray" text allowed. |
| `--paper-tint` | `#f2f2f2` | Zebra striping, code, blockquotes — the only off-white. |
| `--accent` | `#e6ff00` | **The one loud color.** Text selection, focus fill, `<mark>` highlight, a single "featured" element per page. |
| `--link` | `#0000ee` | Unvisited links. Kept as the browser default on purpose. |
| `--link-visited` | `#551a8b` | Visited links. Visited state must be visible — it's wayfinding. |
| `--error` | `#ff0000` | Errors only. Always accompanied by the word `ERROR`. |

**Accent discipline:** the accent is a **highlighter**, not a theme color. It appears as a flat fill behind black text (`<mark>`, focus, selection, one featured card). It is never used for text color, borders, or large backgrounds.

---

## 3. Typography System

Monolith uses **system-first fonts** — the typefaces that ship with the machine — with one optional web display face for monumental headings. Type is the whole interface, so it must be handled with discipline.

```
Times / Georgia     Courier / Space Mono     Archivo (optional display)
(Serif Body)        (Monospace System)       (Heavy Headline)
"The archive is open."   "ISSUE 042 / 2026-10-04"   "STOP READING THE FEED"
```

### 3.1 Font Family Mapping

| Role | Font Family | Variable | Usage |
| :--- | :--- | :--- | :--- |
| **Body & Prose** | `"Times New Roman", Times, Georgia, serif` | `--font-serif` | Long-form text, article body, quotes. |
| **System & Data** | `"Courier New", Courier, "Space Mono", monospace` | `--font-mono` | Navigation, metadata, labels, buttons, tables, code, dates, issue numbers. |
| **Display** *(optional)* | `"Archivo Black", Impact, "Arial Black", sans-serif` | `--font-display` | Oversized page titles and section openers only. |

Every stack must have a real system fallback. If the web display font fails to load, the page must still look correct in Impact / Arial Black.

### 3.2 Typography Scale & Utility Classes

```css
html { font-size: 16px; }
body {
  font-family: var(--font-serif);
  font-size: 1.0625rem;
  line-height: 1.5;
  color: var(--ink);
  background: var(--paper);
}

/* Monumental page title — fills the width, breaks hard */
.text-monolith {
  font-family: var(--font-display);
  font-size: clamp(4rem, 16vw, 14rem);
  line-height: 0.82;
  font-weight: 900;
  letter-spacing: -0.05em;
  text-transform: uppercase;
  word-break: break-word;
}

/* Section Title */
.text-title {
  font-family: var(--font-display);
  font-size: clamp(2rem, 6vw, 4rem);
  line-height: 0.9;
  letter-spacing: -0.03em;
  text-transform: uppercase;
}

/* Subheading */
.text-heading {
  font-family: var(--font-mono);
  font-size: 1.125rem;
  line-height: 1.2;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0;
}

/* Body — small, dense, left-aligned */
.text-body {
  font-family: var(--font-serif);
  font-size: 1.0625rem;
  line-height: 1.5;
  max-width: 64ch;
}

/* Data, Labels, Navigation */
.text-data {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  line-height: 1.4;
  font-variant-numeric: tabular-nums;
}

/* Captions & Metadata */
.text-micro {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  line-height: 1.3;
  color: var(--ink-mid);
  text-transform: uppercase;
  letter-spacing: 0.04em;
}
```

### 3.3 Links (non-negotiable)
Links look like links. Underlined, colored, and with a visible visited state. Never remove underlines to "clean up" a design.
```css
a { color: var(--link); text-decoration: underline; text-underline-offset: 3px; text-decoration-thickness: 1px; }
a:visited { color: var(--link-visited); }
a:hover   { background: var(--accent); color: var(--accent-ink); text-decoration-thickness: 3px; }
a:active  { color: var(--link-active); }
a:focus-visible { outline: 3px solid var(--ink); outline-offset: 2px; background: var(--accent); color: var(--accent-ink); }
```

### 3.4 Selection & Highlight
```css
::selection { background: var(--accent); color: var(--accent-ink); }
mark        { background: var(--accent); color: var(--accent-ink); padding: 0 0.15em; }
```

### 3.5 Universal Text Alignment Standard
Everything is left-aligned and ragged-right. No centered body text, no justified text. Headlines may bleed to the edge or break mid-word.

```css
p, .text-body, li { text-align: left; max-width: 64ch; text-wrap: pretty; hyphens: manual; }
```

---

## 4. Structural Architecture

Monolith has **no shadows, no elevation, no panels floating above anything.** Structure comes from **rules (lines), borders, tables, inversion, and whitespace.** If a surface needs to feel different, it gets a border or flips to white-on-black.

### 4.1 Rules (`.rule`)
Horizontal rules are the primary structural device — the load-bearing walls:
```css
.rule        { border: 0; border-top: var(--rule) solid var(--ink); margin: 1.5rem 0; }
.rule--hair  { border-top-width: var(--rule-hair); }
.rule--heavy { border-top-width: var(--rule-heavy); }
.rule--monolith { border-top-width: var(--rule-monolith); margin: 3rem 0; }
.rule--dashed { border-top-style: dashed; }
.rule--double { border-top: 6px double var(--ink); }
```

### 4.2 Box (`.m-box`)
The only container. A plain bordered rectangle:
```css
.m-box {
  background: var(--paper);
  border: var(--rule) solid var(--ink);
  border-radius: 0;
  padding: 1rem;
  box-shadow: none;                 /* No shadows. Ever. */
}
.m-box--heavy { border-width: var(--rule-heavy); }
```

### 4.3 Inverted Block (`.m-block`)
Emphasis is made by flipping polarity — white on black. The inverted block is the loudest object that doesn't use the accent:
```css
.m-block {
  background: var(--ink);
  color: var(--paper);
  padding: 1rem 1.25rem;
}
.m-block a { color: var(--accent); }
```

### 4.4 Featured Block (`.m-feature`)
**One per page.** The accent as a flat fill with a black border:
```css
.m-feature {
  background: var(--accent);
  color: var(--accent-ink);
  border: var(--rule-heavy) solid var(--ink);
  padding: 1rem 1.25rem;
}
```

### 4.5 Tag / Label (`.m-tag`)
Square, bordered, monospace. Written like bracketed text, not a pill:
```css
.m-tag {
  display: inline-block;
  padding: 0 0.4em;
  border: var(--rule) solid var(--ink);
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  line-height: 1.5;
}
.m-tag--inverted { background: var(--ink); color: var(--paper); }
.m-tag--accent   { background: var(--accent); }
.m-tag--error    { background: var(--error); color: #fff; border-color: var(--error); }
```
Tags may also be written as plain text: `[NEW]`, `[DRAFT]`, `[ERROR]`.

### 4.5 Tables (`.m-table`) — the signature data structure
Tables are first-class citizens in Monolith. Full borders, no rounded anything:
```css
.m-table {
  width: 100%;
  border-collapse: collapse;
  border: var(--rule) solid var(--ink);
  font-family: var(--font-mono);
  font-size: 0.875rem;
}
.m-table th {
  background: var(--ink);
  color: var(--paper);
  text-align: left;
  text-transform: uppercase;
  padding: 0.5rem 0.75rem;
}
.m-table td { padding: 0.5rem 0.75rem; border-top: var(--rule-hair) solid var(--ink); border-left: var(--rule-hair) solid var(--ink); }
.m-table tr:nth-child(even) td { background: var(--paper-tint); }
.m-table tr:hover td { background: var(--accent); }
```

### 4.6 Inputs (`.m-input`)
Bare, square, bordered — closer to a raw `<input>` than a designed field:
```css
.m-input {
  background: var(--paper);
  color: var(--ink);
  border: var(--rule) solid var(--ink);
  border-radius: 0;
  padding: 0.5rem 0.75rem;
  font-family: var(--font-mono);
  font-size: 1rem;
  width: 100%;
}
.m-input:focus { outline: none; background: var(--accent); border-width: var(--rule-heavy); }
.m-input::placeholder { color: var(--ink-mid); }
label { font-family: var(--font-mono); font-size: 0.75rem; text-transform: uppercase; display: block; margin-bottom: 0.25rem; }
```

### 4.7 Blockquote & Code
```css
blockquote { border-left: var(--rule-monolith) solid var(--ink); margin: 1.5rem 0; padding: 0 0 0 1.25rem; font-size: 1.375rem; line-height: 1.3; }
pre, code  { font-family: var(--font-mono); background: var(--paper-tint); border: var(--rule-hair) solid var(--ink); }
pre        { padding: 1rem; overflow-x: auto; }
code       { padding: 0 0.3em; }
pre code   { border: 0; padding: 0; background: none; }
```

### 4.8 ASCII Structural Devices (optional)
Text-based ornaments for section breaks and indexes — structure made from characters, not graphics:
```
////////////////////////////////////////
== 03 / ESSAYS ===========================
----------------------------------------
[01] [02] [03] [04] ......... [NEXT →]
```

---

## 5. Interaction & Motion System

**Principle:** interaction is *immediate and legible*. No eased lifts, no floating, no fades. State changes are binary — a flip of polarity or a fill of accent.

### 5.1 Hover, Active & Focus States
Everything interactive changes on hover by **inverting or highlighting**, with zero transition:
```css
.m-hover { transition: none; }
.m-hover:hover  { background: var(--ink); color: var(--paper); }
.m-hover--accent:hover { background: var(--accent); color: var(--accent-ink); }
.m-hover:active { background: var(--accent); color: var(--accent-ink); outline: 3px solid var(--ink); }
```

### 5.2 Button Hierarchy

#### Standard Button (`.m-button`)
A square, bordered, monospace button. Looks like a button, behaves like one:
```css
.m-button {
  background: var(--paper);
  color: var(--ink);
  border: var(--rule-heavy) solid var(--ink);
  border-radius: 0;
  padding: 0.6rem 1.25rem;
  font-family: var(--font-mono);
  font-size: 1rem;
  font-weight: 700;
  text-transform: uppercase;
  cursor: pointer;
  box-shadow: none;
  transition: none;
}
.m-button:hover  { background: var(--ink); color: var(--paper); }
.m-button:active { background: var(--accent); color: var(--accent-ink); }
.m-button:focus-visible { outline: 3px solid var(--ink); outline-offset: 3px; background: var(--accent); color: var(--accent-ink); }
```

#### Primary Button (`.m-button-primary`)
Inverted at rest — heaviest object in a form:
```css
.m-button-primary { background: var(--ink); color: var(--paper); }
.m-button-primary:hover { background: var(--accent); color: var(--accent-ink); }
```

#### Text Button (`.m-button-text`)
For low-priority actions, written as a plain link-like bracket: `[ CANCEL ]`
```css
.m-button-text { background: none; border: 0; font-family: var(--font-mono); text-decoration: underline; padding: 0; }
```

#### Destructive (`.m-button-danger`)
```css
.m-button-danger { border-color: var(--error); color: var(--error); }
.m-button-danger:hover { background: var(--error); color: #fff; }
```

#### Disabled
```css
.m-button:disabled { border-style: dashed; color: var(--ink-mid); background: var(--paper); cursor: not-allowed; }
```

### 5.3 Permitted Animations (only these)

#### Block Cursor (`@keyframes blink`)
```css
@keyframes blink { 0%, 49% { opacity: 1; } 50%, 100% { opacity: 0; } }
.m-cursor::after { content: "█"; animation: blink 1s steps(1) infinite; }
```

#### Marquee Ticker (`@keyframes marquee`)
For headlines, issue updates, or a status line. Linear, never eased:
```css
@keyframes marquee { from { transform: translateX(0); } to { transform: translateX(-50%); } }
.m-marquee { background: var(--ink); color: var(--paper); border-block: var(--rule-heavy) solid var(--ink); overflow: hidden; white-space: nowrap; font-family: var(--font-mono); text-transform: uppercase; }
.m-marquee__track { display: inline-block; animation: marquee 30s linear infinite; }
```

#### Hard Cut (page/state transitions)
Content swaps instantly — no fades, slides, or skeleton shimmer. Loading states are plain text: `LOADING...` with a `.m-cursor`.

#### Reduced Motion
```css
@media (prefers-reduced-motion: reduce) {
  .m-marquee__track { animation: none; }
  .m-cursor::after  { animation: none; }
}
```

---

## 6. Signature Visual Components

### 6.1 Masthead (`Masthead`)
- **Visual:** The site name set in `.text-monolith` across the full viewport width, bleeding to both edges and breaking mid-word if necessary. Beneath it, a `.rule--monolith`, then a single line of mono metadata: `ISSUE 042 — 04.10.2026 — CHENNAI — 3,204 ENTRIES`.
- **No logo mark.** The name *is* the logo.

### 6.2 Index Navigation (`IndexNav`)
- **Visual:** a plain, left-aligned numbered list in monospace: `01 ESSAYS / 02 ARCHIVE / 03 AUTHORS / 04 ABOUT`. Active item is a `<mark>` (accent fill); hover inverts.
- **Mobile:** the full list stays visible as a stacked list — no hamburger menu.

### 6.3 Archive Table (`ArchiveTable`)
- **Visual:** a full-width `.m-table` listing entries by number, title (as a link), author, date, and word count — sortable by clicking a header, which gets an arrow (`↓`).
- **Rows:** zebra striped; hover fills with the accent; the title link retains underline and visited color.
- **Empty state:** a single row reading `NO ENTRIES FOUND.`

### 6.4 Article Layout (`Article`)
- **Visual:** an asymmetric two-column layout — a narrow left column (≈ 20%) holding mono metadata (`BY`, `DATE`, `TAGS`, `READ TIME`) separated by a `.rule--hair` stack, and a wide right column holding the title in `.text-title` and prose in `.text-body`.
- **Pull quote:** a `blockquote` with an 8px left rule, set at 1.375rem.
- **Footnotes:** numbered mono references at the bottom under a `.rule--double`.

### 6.5 Featured Entry (`Featured`)
- **Visual:** the page's single `.m-feature` — acid accent fill, 4px black border, the entry title in `.text-title`, and a `[READ →]` text button.
- **Rule:** exactly one per page. If two things are "featured," neither is.

### 6.6 Notice / Alert (`Notice`)
- **Visual:** a `.m-box--heavy` with a mono label on the first line: `NOTICE:`, `WARNING:`, `ERROR:`. Errors flip to white-on-red with a `.m-block`-style inversion.
- **No icons, no colored side-bars.** The label word *is* the severity.

### 6.7 Footer Colophon (`Colophon`)
- **Visual:** an inverted `.m-block` closing the page. Contains the site name, a plain list of links, a `.m-cursor`, and a mono line: `SET IN TIMES & COURIER. NO TRACKING. NO ANIMATIONS. VIEW SOURCE.`

---

## 7. Layout & Spacing

```css
:root {
  --space-1: 0.25rem;  --space-2: 0.5rem;  --space-3: 1rem;
  --space-4: 1.5rem;   --space-5: 2rem;    --space-6: 3rem;   --space-7: 5rem;
}
```

- **Document flow:** prefer normal block flow. Reach for Grid only to make asymmetric columns (e.g. `grid-template-columns: 1fr 4fr`), not decorative card grids.
- **Asymmetry is allowed; misalignment is not.** Columns may be unbalanced or content may bleed off an edge, but every element still snaps to the spacing scale.
- **Gutters:** `--space-4` between columns; `--space-5` or more around headlines.
- **Max measure:** body copy capped at `64ch`; headlines and tables may run full-bleed.
- **No sticky chrome:** no floating headers, FABs, cookie-banners-over-content, or sticky footers. The page scrolls; everything is in the flow.
- **Z-index:** effectively unused. If you need `z-index`, the layout is too complicated.

---

## 8. Accessibility & Performance Rules

Brutalism is *good* for accessibility when done honestly — Monolith leans into this.

### Accessibility
- **Contrast:** pure black on white = 21:1. `--ink-mid` on white = 7.5:1. Text on `--accent` is always black (≈ 17:1). Never place link blue on the accent without the hover/focus rule above.
- **Visible focus:** 3px black outline with an accent fill — impossible to miss.
- **Semantic HTML first:** real `<table>`, `<nav>`, `<article>`, `<h1>–<h6>`, `<button>`, `<a>`. No `div` soup. If a native element exists, use it.
- **Zoom & reflow:** layout must work at 400% zoom without horizontal scroll (except tables and code blocks, which scroll inside their own container).
- **No meaning by color alone:** status uses bracketed words (`[OK]`, `[ERROR]`) alongside any color.
- **Respect user settings:** honor `prefers-color-scheme` (swap to `monolith-inverted`), `prefers-reduced-motion`, and user font-size changes (use `rem`, never `px` for text).

### Performance
- **No JavaScript required for core reading.** The page must be fully usable with JS disabled.
- **System fonts first.** Web fonts limited to the single optional display face, loaded with `font-display: swap`.
- **No images required.** When used, images are high-contrast, hard-edged, `image-rendering: auto`, with `loading="lazy"` and explicit `width`/`height` to prevent layout shift. Prefer 1-bit or grayscale treatments (`filter: grayscale(1) contrast(1.2)`).
- **Target:** under 50KB of CSS+JS combined; first paint is effectively instant.

---

## 9. Component Usage Checklist

When building new components for Monolith:

- [ ] Use **black, white, and the accent only** — plus link blue/purple/red for links and red for errors.
- [ ] Set `border-radius: 0` and `box-shadow: none` everywhere. **No rounded corners. No shadows. No exceptions.**
- [ ] Build hierarchy with **scale, rules, inversion, and borders** — never with tints, blur, or elevation.
- [ ] Use `--font-serif` for prose, `--font-mono` for UI/data/navigation, and `--font-display` only for monumental headings.
- [ ] Keep links **underlined, colored, and visibly visited**. Hover = accent fill, not removal of the underline.
- [ ] Use native HTML elements (`<table>`, `<nav>`, `<button>`, `<blockquote>`) styled minimally before building custom ones.
- [ ] Use at most **one `.m-feature`** and **one accent-highlighted element** per page.
- [ ] Use `transition: none` for state changes; animate only the cursor blink and the marquee.
- [ ] Left-align all text; cap body measure at `64ch`.
- [ ] Label every state with a word (`[OK]`, `NOTICE:`, `ERROR:`) — never rely on color alone.
- [ ] Separate sections with a visible rule (`.rule`, `.rule--heavy`, or `.rule--monolith`).
- [ ] Ensure the page works with JavaScript disabled and at 400% zoom.
- [ ] Honor `prefers-color-scheme`, `prefers-reduced-motion`, and user font-size preferences.

### Don'ts
- ✗ No box shadows, text shadows, glows, or blurs of any kind.
- ✗ No gradients, glassmorphism, or translucent surfaces.
- ✗ No rounded corners, pill buttons, or circular avatars.
- ✗ No hover-only navigation, hamburger menus, carousels, or parallax.
- ✗ No fade-ins, slide-ins, easing curves, or skeleton shimmer.
- ✗ No decorative icons — if an icon doesn't carry meaning a word can't, delete it.
- ✗ No removing link underlines to make things "cleaner."
- ✗ No more than one accent element competing for attention.
