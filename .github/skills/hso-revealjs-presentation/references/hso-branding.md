# HSO Branding for Reveal.js Presentations

Aligned with **HSO Brand Manual v3.0 (07/2025)** and the official **HSO PPT Template 2026** (`.potx`). Reveal.js decks should match the look and feel of the PowerPoint templates so HTML and PPT decks feel like one family.

> **Templates on disk (Windows):** `%OneDrive%\Documents\Practice\Templates\HSO PPT Template Full 2026.potx` and `HSO PPT Template Lite 2026.potx`. The full brand manual PDF lives alongside them.

## Color Palette

All colors below come directly from the brand manual and/or the `.potx` theme. Do not introduce new hues.

### CSS Variables (canonical names)

```css
:root {
    /* Primary palette — brand manual §02 */
    --hso-dark-blue: #00395F;   /* HSO Dark Blue — logo, H1/H2, section dividers */
    --hso-bluegreen: #079FC3;   /* HSO Bluegreen — accents, links, stat numbers */
    --hso-white:     #FFFFFF;

    /* Secondary / accent palette — use sparingly (CTAs, bullets, icons, separators) */
    --hso-green:   #00B294;     /* HSO Green  — success, "won" states */
    --hso-salmon:  #F1554B;     /* HSO Salmon (edge) — errors, "lost" states (matches .potx) */
    --hso-mimosa:  #F2B949;     /* HSO Mimosa — caution, callouts */
    --hso-tagline: #4A4A4A;     /* HSO Tagline grey — used under the logo */

    /* Edge / gradation companions */
    --hso-green-edge:  #008272;
    --hso-salmon-warm: #F58974;  /* brand-manual "Salmon" (warm) — hero accent */
    --hso-mimosa-edge: #F9DC95;
    --hso-grey-edge:   #737373;

    /* Blue-grey supporting tone (used in the .potx for metadata, arrows) */
    --hso-steel: #7F9CAF;

    /* Backgrounds — brand manual §02 */
    --hso-light-grey: #E3E3E3;   /* preferred for office/PPT-style surfaces */
    --hso-web-grey:   #ECEFF3;   /* preferred for web */

    /* Neutrals */
    --text:       #505050;
    --text-muted: #737373;
    --bg:         #FFFFFF;
    --card-bg:    #F7FAFC;
    --border:     #E6E6E6;

    /* Back-compat aliases — existing decks may still reference these.
       Keep them pointing at the canonical brand values. */
    --hso-navy:  var(--hso-dark-blue);
    --hso-blue:  var(--hso-bluegreen);
    --hso-teal:  var(--hso-green);
    --hso-coral: var(--hso-salmon);
    --hso-amber: var(--hso-mimosa);
}
```

> **Removed:** `--hso-bronze` (#B07330) was never an HSO brand color — do not reintroduce. If you need a warm accent, use `--hso-mimosa` or `--hso-salmon-warm`.

### Color Ratio Rule (brand manual §02)

> White and HSO Dark Blue always have a **higher proportion** than HSO Bluegreen. Accent colors (green / salmon / mimosa) are used **sparingly** and **never as body text color**.

Practical rules for decks:
- Body text: `--text` on white/light-grey. Never color body paragraphs with an accent.
- H1/H2: `--hso-dark-blue`. H3: `--hso-bluegreen`.
- Reserve green/salmon/mimosa for badges, stat numbers, CTA borders, workflow end-states.
- Gradations of primary colors are allowed in graphics at 80 / 60 / 40 / 20 % steps.

### Color Usage Quick Reference

| Color | CSS var | Use |
|---|---|---|
| HSO Dark Blue #00395F | `--hso-dark-blue` | H1/H2, section divider bg, table headers, logo-tier elements |
| HSO Bluegreen #079FC3 | `--hso-bluegreen` | H3, links, active nodes, stat numbers, primary bullets |
| HSO Steel #7F9CAF | `--hso-steel` | Metadata text, arrows, sub-bullets (from .potx) |
| HSO Green #00B294 | `--hso-green` | Success, "won", positive deltas |
| HSO Salmon #F1554B | `--hso-salmon` | Errors, "lost", important warnings |
| HSO Mimosa #F2B949 | `--hso-mimosa` | Callouts, caution, "could have" priority |
| HSO Light Grey #E3E3E3 | `--hso-light-grey` | PPT-style full-surface backgrounds |
| HSO Web Grey #ECEFF3 | `--hso-web-grey` | Web-style surfaces |

## Typography

The brand manual specifies **Segoe UI** as the standard font for all Microsoft 365 applications (Outlook / PowerPoint / Word). Reveal.js decks follow the same rule so HTML output matches `.potx` output.

```css
.reveal {
    font-family: 'Segoe UI', 'Segoe UI Web (West European)', system-ui, -apple-system, sans-serif;
    color: var(--text);
}
```

> Mr Eaves San and Asap (brand manual §03) are print fonts and should **not** be referenced in HTML — they require font licensing. Stick with Segoe UI for parity with PowerPoint.

### Editorial Display Scale (1920×1080)

Titles read as **regular-weight display type with tight tracking**, not bold headlines. This is the "editorial" feel — it lets generous whitespace do the visual work and keeps slides from shouting. Sizes are absolute pixels at 1920×1080; scale proportionally for 1280×720 (multiply by 0.667).

**Display tokens:**

| Token | px | Use |
|---|---|---|
| `--t-hero` | 84 | Title-slide hero, closing-slide headline, divider title |
| `--t-title` | 64 | Content-slide `h1.title` |
| `--t-subtitle` | 44 | Title-slide sub, divider sub-line, stat caption, closing sub |
| `--t-body` | 30 | Body paragraphs and bullet items in `ul.bullets` |
| `--t-small` | 26 | Sub-bullets, dense column body |
| `--t-kicker` | 24 | Eyebrow / kicker labels (small-caps) |
| `--t-foot` | 20 | Footer bar text |

**Component-level sizes** — these are NOT tokens but absolute pixels tuned for presentation legibility on a 1920×1080 stage. The values were calibrated against an actual 25-slide deck — undersized cards/tables read as "this matters less" against neighboring kickers and titles. Don't drop below these without re-verifying.

| Element | Font | Padding | Notes |
|---|---|---|---|
| `.card` | h4 34, body 27, li 25 | `38px 42px` | Cards stay content-height; tune visual weight via padding + fonts, NOT auto-stretch (`flex: 1` produces empty tiles) |
| `.cap-grid .cell` | name 30, desc 20, num 18 | `28px 30px 26px` | Numbered grid cells, min-height 240px |
| `.reveal table` | body 26, header 20 | `14px 20px` | Match card body so tables don't read as secondary |
| `.reveal table.compact-table` | body 23 | `10px 14px` | When you have 6+ rows or table sits next to dense content |
| `.quote-box` | 28 italic | `24px 32px` | Trailing summary, often pinned to bottom |
| `.callout` | 22 | `18px 24px` | Advisory boxes; bigger than legacy 18px |
| `.workflow-pipe .pipe-node` | 26 | `14px 28px` | Pipeline nodes |
| `.diagram-box` | 26 (small 20) | `22px 32px` | Vertical-flow boxes |
| `.step-num` | 24 in 48px circle | — | Numbered steps |
| `.stat-box .stat-num` | 96 light | — | Stat numbers in content slides; section.slide.stat .big is 260px |

### Heading Styles

```css
.reveal h1, .reveal h2 {
    color: var(--hso-dark-blue);
    font-weight: 400;                /* editorial — not bold */
    letter-spacing: -0.015em;        /* tighten for display sizes */
    line-height: 1.05;
}
.reveal h2 { font-size: var(--t-title); margin-bottom: 0.4em; }
.reveal h3 {
    color: var(--hso-bluegreen);
    font-weight: 600;                /* h3 keeps weight — it's a sub-label */
    font-size: 1.05em;
}
```

> **Why weight 400 on titles?** The editorial reference deck uses regular-weight Helvetica display sizes; we keep Segoe UI but adopt the same weight + tracking. Bold headlines fight the whitespace and read as "PowerPoint-y". Reserve `font-weight: 700` for emphasis spans inside body text.

### Eyebrow / Kicker

The small-caps accent label that sits above titles. One per slide max.

```css
.kicker {
    font-size: var(--t-kicker);
    font-weight: 700;
    color: var(--hso-bluegreen);
    letter-spacing: 0.12em;
    text-transform: uppercase;
    margin-bottom: 16px;
}
.kicker.coral  { color: var(--hso-salmon); }
.kicker.mimosa { color: var(--hso-mimosa); }
```

### Body Text

```css
.reveal p, .reveal li {
    font-size: var(--t-body);
    line-height: 1.4;
    font-weight: 400;
}
```

### Code Styling

```css
.reveal code {
    background: #EDF2F7;
    color: var(--hso-dark-blue);
    padding: 0.1em 0.4em;
    border-radius: 4px;
    font-size: 0.9em;
}
```

## Design Elements (brand manual §04)

The HSO PPT templates use a distinctive **2.5° oblique edge** paired with **soft rounded corners** on hero / section surfaces. Replicate this in Reveal.js for title slides and section dividers:

```css
/* Oblique side slant used on title + section surfaces */
.hso-slant {
    position: relative;
    overflow: hidden;
    border-radius: 18px;      /* soft rounded corners — brand manual §04 */
}
.hso-slant::before {
    content: "";
    position: absolute;
    inset: 0;
    background: var(--hso-dark-blue);
    transform: skewY(-2.5deg);   /* the signature angle */
    transform-origin: top left;
    z-index: -1;
}
```

Rules of thumb:
- Use the slant **once per deck maximum** (title slide or cover section).
- The slanted surface can be white, solid HSO color, or a photo (brand manual §04).
- Do **not** apply the slant to content slides — it becomes noise.

## Imagery (brand manual §05)

When selecting or generating images for decks:
- Clean & corporate: neutral backgrounds (white, soft grey, light wood).
- Cool tones (blue/grey/white) with subtle warmth.
- Even, bright lighting — minimal shadow.
- Minimal human presence; real HSO employees/clients/partners only, not stock models.
- **Avoid**: clichéd handshakes, hyper-saturated filters, oversized logos/watermarks, AI-generated imagery that doesn't match photographic style.

## Brand Voice (brand manual §04)

Every paragraph and speaker note should read as: **Professional & trustworthy · Innovative & forward-thinking · Client-centric · Globally expert, locally aware · Clear & accessible.**

When writing deck content:
- **Active voice** — direct, dynamic statements.
- **Consistent terminology** — pick one term and use it throughout.
- **Structured** — short sentences, narrow columns, clear headings, bullets for readability.
- **Positive framing** — lead with solutions and benefits.
- **Audience-aware** — tailor depth to the audience selected in the Discovery Questions.

## Presentation Sizes

### Editorial baseline: 1920×1080

The default. The display scale and component sizes in this document are calibrated for this stage:

```javascript
Reveal.initialize({
    hash: true,
    slideNumber: false,   // footer carries the slide number
    transition: 'slide',
    width: 1920,
    height: 1080,
    margin: 0,            // section flex layout handles padding
    center: false,        // we own vertical alignment
    plugins: [ RevealNotes ]
});
```

> **`margin: 0` and `center: false` are required** for the editorial layout. Reveal's default `margin: 0.04` shrinks the slide content area; `center: true` vertically centers slides which fights `.body-region`'s flex-grow. Don't change these without re-verifying every slide.

### Compact: 1280×720

For embedded contexts or quick decks where 1080p detail isn't needed. Multiply `--t-*` tokens and component sizes by 0.667.

```javascript
Reveal.initialize({ width: 1280, height: 720, margin: 0, center: false });
```

## Complete Base CSS

```css
:root {
    /* Canonical palette */
    --hso-dark-blue: #00395F;
    --hso-bluegreen: #079FC3;
    --hso-bluegreen-bright: #11B6D9;   /* brighter cyan for use on dark surfaces */
    --hso-steel:     #7F9CAF;
    --hso-green:     #00B294;
    --hso-salmon:    #F1554B;
    --hso-salmon-warm: #F58974;
    --hso-mimosa:    #F2B949;
    --hso-mimosa-edge: #F9DC95;
    --hso-tagline:   #4A4A4A;
    --hso-light-grey:#E3E3E3;
    --hso-web-grey:  #ECEFF3;

    --text:       #505050;
    --text-muted: #737373;
    --bg:         #FFFFFF;
    --card-bg:    #F7FAFC;
    --border:     #E6E6E6;

    /* Editorial semantic tokens */
    --ink:        var(--hso-dark-blue);
    --ink-2:      #1B4A70;             /* mid-tone secondary text on light */
    --accent:     var(--hso-bluegreen);
    --accent-2:   var(--hso-bluegreen-bright);
    --paper:      #FFFFFF;
    --muted:      #5A6B78;             /* cool grey for secondary copy */
    --line:       #E4E8EC;
    --code-bg:    #F4F7FA;

    /* Display scale (px @ 1920×1080) */
    --t-hero:     84px;
    --t-title:    64px;
    --t-subtitle: 44px;
    --t-body:     30px;
    --t-small:    26px;
    --t-kicker:   24px;
    --t-foot:     20px;

    /* Footer height — slide-content layout uses absolute pixel padding (90px top,
       100px sides) rather than tokens, since component sizes are also pixel-tuned. */
    --footer-h:   56px;

    /* Aliases (legacy decks) */
    --hso-navy:  var(--hso-dark-blue);
    --hso-blue:  var(--hso-bluegreen);
    --hso-teal:  var(--hso-green);
    --hso-coral: var(--hso-salmon);
    --hso-amber: var(--hso-mimosa);
}

.reveal {
    font-family: 'Segoe UI', 'Segoe UI Web (West European)', system-ui, -apple-system, sans-serif;
    color: var(--ink);
    font-size: 32px;
}
.reveal h1, .reveal h2 {
    color: var(--ink);
    font-weight: 400;
    letter-spacing: -0.015em;
    line-height: 1.05;
}
.reveal h3 { color: var(--accent); font-weight: 600; }
.reveal h2 { font-size: var(--t-title); margin: 0 0 20px; }
.reveal h3 { font-size: 1.05em; }
.reveal p, .reveal li { font-size: var(--t-body); line-height: 1.4; }

/* Filled-dot bullets (editorial) — replaces the legacy ▸ triangle.
   Triangles are still available via `ul.legacy-bullets`. */
.reveal ul.bullets { list-style: none; padding: 0; margin: 12px 0 0; }
.reveal ul.bullets li {
    position: relative;
    padding-left: 28px;
    margin-bottom: 14px;
}
.reveal ul.bullets li::before {
    content: "";
    position: absolute;
    left: 0; top: 0.55em;
    width: 8px; height: 8px;
    background: var(--ink);
    border-radius: 999px;
}

.reveal code {
    background: var(--code-bg);
    color: var(--ink);
    padding: 0.1em 0.4em;
    border-radius: 4px;
    font-size: 0.9em;
}
```
