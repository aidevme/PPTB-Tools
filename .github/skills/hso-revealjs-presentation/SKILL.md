---
name: hso-revealjs-presentation
layer: atomic
scope: core
description: Generate professional Reveal.js HTML presentations with HSO branding, consistent styling, and speaker notes. Use when creating slide decks for client presentations, training materials, solution comparisons, workshops, or technical documentation. Triggers include requests for presentations, slide decks, HTML slides, training decks, or any request to visualize information in presentation format.
---

# HSO Reveal.js Presentation Generator

Generate professional HTML-based slide presentations using Reveal.js with HSO corporate design guidelines.

## Authoritative References (task → primary doc)

This skill defers to five reference docs, each the authority for a distinct first-class task. For a standalone task, read the primary doc before doing the work.

| Task | Primary authority |
|---|---|
| Styling / brand compliance (palette, typography, voice) | [references/hso-branding.md](references/hso-branding.md) |
| Slide layout / CSS classes / HTML patterns | [references/slide-components.md](references/slide-components.md) |
| Choosing deck structure by presentation type | [references/presentation-types.md](references/presentation-types.md) |
| Slide copy & speaker-note claim grounding / voice | [references/editorial-voice.md](references/editorial-voice.md) |
| Converting a deck to PowerPoint | [references/pptx-conversion.md](references/pptx-conversion.md) |

## When to Use

- Creating client-facing presentations (solution analysis, recommendations, proposals)
- Building training materials (train-the-trainer, end-user guides)
- Documenting technical comparisons (solution cost/benefit analysis)
- Workshop and meeting materials
- Any deliverable that benefits from visual slide format with speaker notes

## Discovery Questions

Before generating a presentation, gather the following information to ensure the output matches the audience and context. Ask these questions if not already provided:

### Required Questions

1. **Audience Type** - Who will be viewing this presentation?
   - Executive/Leadership (focus on ROI, strategic impact, minimal technical detail)
   - Technical (architecture, implementation details, dev considerations)
   - End Users (task-oriented, how-to, practical workflows)
   - Mixed (layered content with executive summaries + detail appendix)

2. **Duration** - How long is the presentation?
   - 15 minutes (~8-12 slides, one key message)
   - 30 minutes (~15-20 slides, 2-3 key points)
   - 60 minutes (~25-35 slides, deeper exploration)
   - 2+ hours (workshop format with practice exercises)

3. **Primary Goal** - What should the audience do or understand after viewing?
   - Inform (educate on a topic)
   - Recommend (present options, guide to a decision)
   - Train (teach skills, enable task completion)
   - Demo (showcase capabilities, inspire confidence)

### Optional Questions (ask if context is unclear)

4. **Prior Knowledge Level**
   - New to the topic (need foundational context)
   - Some familiarity (can skip basics)
   - Expert (focus on specifics, skip overview)

5. **Action Expected**
   - No action (informational only)
   - Decision needed (include clear recommendation)
   - Hands-on follow-up (include next steps, resources)

6. **Delivery Method**
   - Live presentation (speaker notes critical)
   - Self-service/async (more text on slides, less speaker notes)
   - Printed/PDF (avoid animations, ensure readability)

7. **Source Documents** — what existing material does this deck summarize?
   - One or more long-form documents (e.g., proposal markdown, design doc, SOW). Deck commitments must not be firmer than these sources — see [Editorial Voice & Factual Grounding](#editorial-voice--factual-grounding) §5.
   - Authored from scratch (no prior source). Per-claim grounding becomes the writer's responsibility, slide by slide.
   - Mixed (some slides summarize sources, others are net-new). Mark each slide accordingly.

### How Answers Affect Output

| Factor | Impact on Presentation |
|--------|----------------------|
| Executive audience | Stat boxes, ROI focus, 3-5 key points max per slide |
| Technical audience | Diagrams, architecture details, code snippets if relevant |
| End user audience | Step numbers, screenshots, practice scenarios |
| 15 min duration | 8-12 slides, aggressive prioritization |
| 60+ min duration | Section dividers, deeper content, exercise slides |
| Training goal | Use 1920x1080 size, include practice scenarios |
| Recommendation goal | Comparison tables, clear verdict slide, pros/cons cards |
| Source documents identified | Run cross-document consistency check; deck claims must not be firmer than source |
| No source documents | Per-claim grounding required; flag every numerical/named claim with provenance in speaker notes |

## Core Requirements

### File Structure

Generate a single self-contained HTML file with:
- Inline CSS (no external stylesheets except Reveal.js CDN)
- Reveal.js loaded from CDN
- Speaker notes plugin enabled
- All content embedded in the file

### Reveal.js CDN References

```html
<link rel="stylesheet" href="https://unpkg.com/reveal.js@5/dist/reveal.css">
<link rel="stylesheet" href="https://unpkg.com/reveal.js@5/dist/theme/white.css">
<script src="https://unpkg.com/reveal.js@5/dist/reveal.js"></script>
<script src="https://unpkg.com/reveal.js@5/plugin/notes/notes.js"></script>
```

### Initialization Script

```javascript
Reveal.initialize({
    hash: true,
    slideNumber: false,   // footer carries the slide number — Reveal's built-in is redundant
    transition: 'slide',
    width: 1920,          // editorial baseline is 1920×1080
    height: 1080,
    margin: 0,            // .body-region handles padding
    center: false,        // we own vertical alignment; don't let Reveal vertically center
    plugins: [ RevealNotes ]
});
```

## Reveal.js compatibility gotchas (READ FIRST)

These four traps silently broke an entire deck during this skill's first integration test. They're invisible in the markup — they only manifest at runtime against Reveal's stylesheet + JS. Bake them into every deck.

### 1. Reveal sets `style="display: block"` INLINE on the active slide

Inline styles beat any non-`!important` stylesheet rule. If a slide type needs a non-block display (e.g., `grid` for a split title), the rule must use `!important`:

```css
.reveal .slides section.slide.title-slide { display: grid !important; grid-template-columns: 1fr 1fr; }
```

Without `!important`, the grid silently collapses to block and the right column ends up height: 0.

### 2. NEVER override `position` on `.reveal .slides section`

Reveal positions slides via `position: absolute` + transforms — that's how it brings the active slide into view. If you set `position: relative` (or `static`) on the section, Reveal's positioning system breaks: every slide ends up stacked at y = N × slideHeight in document flow, off-screen.

Style colors, padding, text alignment on sections — but leave `position` alone:

```css
/* GOOD */
.reveal .slides section.slide { background: var(--paper); padding: 0 !important; text-align: left; overflow: hidden; }
/* BAD — knocks every slide off-screen */
.reveal .slides section.slide { position: relative; }
```

### 3. Sections need `box-sizing: border-box`

Reveal sets sections to the configured `width × height` (e.g., 1920×1080). Without `box-sizing: border-box`, padding inflates the section past those dimensions — content overflows the right edge, footer goes off-screen below.

```css
.reveal .slides section.slide { box-sizing: border-box; padding: 0 !important; }
.reveal .slides section.slide * { box-sizing: border-box; }
```

### 4. Reveal's `white.css` uppercases all headings

`text-transform: uppercase` is applied to `h1`–`h6`. For editorial sentence-case titles, defeat with `!important`:

```css
.reveal h1, .reveal h2, .reveal h3, .reveal h4, .reveal h5, .reveal h6 {
    text-transform: none !important;
}
```

### Bonus: HSO logo asset is white-on-transparent

`HSO Logo.png` is designed to overlay a navy/dark surface. On a white background it renders invisibly. On the editorial title-slide, place it on the dark right column over the photo, not on the white left column.

## HSO Brand Guidelines

The skill is aligned with **HSO Brand Manual v3.0 (07/2025)** and the **HSO PPT Template 2026** (`.potx`). Reveal.js decks must match the PowerPoint look & feel so HTML + PPT deliverables feel like one family.

Authority for HSO brand (palette, typography, Segoe UI, 2.5° slant, imagery, voice) — read [references/hso-branding.md](references/hso-branding.md) before styling any slide. It is the complete canonical palette, typography rules, Segoe UI requirement, 2.5° slant design element, imagery guidance, and brand voice.

**Non-negotiables:**
- Use only the canonical variables (`--hso-dark-blue`, `--hso-bluegreen`, `--hso-green`, `--hso-salmon`, `--hso-mimosa`, `--hso-steel`). Aliases exist for legacy decks but new slides should use the canonical names.
- Font is **Segoe UI** (MS 365 standard per brand manual §03).
- White + HSO Dark Blue dominate; accents (green / salmon / mimosa) are used **sparingly** and never for body text.
- Never introduce colors outside the palette (no bronze, no off-brand hues, no hyper-saturated accents).

## Slide Components

Authority for slide CSS classes and HTML patterns — read [references/slide-components.md](references/slide-components.md) before authoring any slide layout. It lists every available CSS class and HTML pattern.

## Presentation Templates

Authority for deck structure by presentation type — read [references/presentation-types.md](references/presentation-types.md) before choosing a deck outline. It gives the recommended structures by presentation type.

## Slide Type Vocabulary

Every slide in a deck belongs to one of these five types. The CSS for each lives in [references/slide-components.md](references/slide-components.md); pick the right type per slide rather than building ad-hoc layouts.

| Type | Purpose | Class | Has footer? |
|---|---|---|---|
| **Title slide** | Deck cover. Split layout: brand+title left, hero photo right. | `slide title-slide` | No |
| **Section divider** | Marks a new section. Solid color background, large title, kicker as sub-line. Variants: default ink, `.coral`, `.sand`, `.teal`. | `slide divider` (+ optional color) | No |
| **Content slide** | The workhorse. `.body-region` flex wrapper with kicker → title → body → optional trailing pinned callout, plus the navy footer bar. | `slide content` | **Yes** |
| **Stat slide** | Single huge number for emphasis (one platform, 99.9%, 4 weeks). Solid teal background. Use sparingly — 1–2 per deck max. | `slide stat` | No |
| **Closing slide** | Q&A / asks / contact. Light bg, large title, sub, optional 3-column "asks" grid. | `slide closing` | No |

### Required: `.content` flex layout + `.body-region` + `.footer`

Content slides are **two pieces** wrapped in `<section class="slide content">`:

1. **`.body-region`** — the content container. Flex column with `flex: 1 1 auto` so it fills the section above the footer. Holds kicker → title → body → content blocks → optional trailing callout/quote.
2. **`.footer`** — the navy bar at the bottom. Three slots: slide-num · section name (left), deck tag + wordmark (right). Reaches edge-to-edge via `margin: auto -100px 0` to negate the section's horizontal padding.

The section uses `display: flex !important; flex-direction: column; padding: 90px 100px 0` (note the `!important` — Reveal sets inline `display: block` on the active slide, which would otherwise win). Vertical padding is asymmetric: 90px on top, 0 on bottom — the footer fills the bottom 56px directly.

**Why not `.frame { position: absolute; inset: 0 }`?** That pattern was the first attempt. It fights Reveal's slide positioning (Reveal needs absolute on the section itself, and absolute frames inside translate-positioned sections don't render reliably). The flex approach works WITH Reveal instead of against it.

### Pinning trailing elements to the bottom

Slides with a single concluding callout, quote-box, stat-row, or workflow-pipe should pin that element to the bottom of `.body-region` so the visual weight balances. The CSS does this automatically when the trailing element is the last child:

```css
.body-region > .stat-row:last-child,
.body-region > .quote-box:last-child,
.body-region > .callout:last-child,
.body-region > .workflow-pipe:last-child,
.body-region > .pin-bottom {
    margin-top: auto !important;
}
```

For arbitrary elements you want pinned (e.g., a custom div), add the `.pin-bottom` utility class.

## Content Slide Anatomy

```html
<section class="slide content">
    <div class="body-region">
        <div class="kicker">Section 02 &middot; Architecture</div>
        <h1 class="title">Property is the durable entity.</h1>
        <p class="body muted">Home services anchors to the property, not the
            person &mdash; the platform must model that reality from day one.</p>

        <!-- middle content: .cols, .cap-grid, .personas, .roadmap, .arch, table, etc. -->

        <!-- optional trailing element — auto-pinned to bottom -->
        <div class="quote-box">"One durable anchor keeps service history attached to the right thing — across ownership changes."</div>
    </div>
    <div class="footer">
        <span class="f-left">04 &middot; Architecture</span>
        <span class="f-right">
            <span class="tag">Field Services Platform</span>
            <span class="wordmark">HSO</span>
        </span>
    </div>
    <aside class="notes">Speaker notes…</aside>
</section>
```

Rules:
- **`.content` class on the section is required** — without it, the flex layout doesn't activate and the footer won't pin to the bottom.
- **Kicker** — small-caps accent label above the title. One per slide. Defaults to `--accent` (HSO Bluegreen); `.kicker.coral` available for variant decks.
- **Title** — `h1.title`, regular weight (400), tight tracking (`-0.015em`). Editorial style favors a plain title with the kicker carrying the color rather than two-tone titles.
- **Body / lede** — `p.body` for normal copy, `p.body.muted` for the framing sentence beneath the title.
- **Trailing pin (optional)** — exactly one trailing summary element (callout / quote-box / stat-row / workflow-pipe) per slide. CSS pins it to the bottom of `.body-region` automatically.
- **Footer** — required on every content slide. Slide-number prefix is a two-digit pad (`04 · Architecture`).

## Accent Discipline

Each deck picks ONE dominant accent color and uses it consistently for
kicker labels, title accents, card titles, divider variants, and default pill
colors. Variety fights focus. Defaults:

| Use | Accent | Token |
|---|---|---|
| Most decks (architecture, platform, financial) | HSO Bluegreen | `--accent` (default) |
| Attention / warning / risk emphasis | HSO Salmon | swap to `--hso-salmon` |
| Success / opportunity emphasis | HSO Green | swap to `--hso-green` |
| Caution / contrast | HSO Mimosa | swap to `--hso-mimosa` |

Swap the deck-wide accent by redefining `--accent` at the top of the deck's
`<style>` block:

```css
:root { --accent: var(--hso-salmon); --accent-2: var(--hso-salmon-warm); }
```

Section dividers can carry a different accent than the rest of the deck via
the `.divider.coral`, `.divider.sand`, `.divider.teal` variants — that's the
intended way to inject color personality without breaking the deck-wide
discipline on content slides.

## Layout Validation (MANDATORY before declaring a deck done)

Every generated deck must be run through the bundled layout audit. The audit
walks every slide, measures content height vs the configured slide height, and
flags three failure modes:

| Failure | Threshold | Why it matters |
|---|---|---|
| **OVERFLOW** | content height > slide height + 10 px | Content is clipped or forces the user to scroll a slide |
| **WHITESPACE** | content height < slide height − 160 px (non-divider slides only) | Slide looks empty, under-uses real estate — feels unfinished |
| **WORKFLOW_WRAP** | process flow spans more than one row | Wrapping process flows look broken; flows must fit on one row |

Section dividers and title slides are allowed to be sparse and are excluded from
the WHITESPACE check.

> **The audit measures slide-level geometry only — it does not look inside an
> embedded diagram.** A passing audit says nothing about whether an SVG's own
> arrows cross its node labels, whether a flow is readable, or whether a
> diagram is clipped *inside* its box. For any slide carrying a `.drawio`/SVG
> diagram, also rasterize and eyeball the rendered slide. Diagram-internal edge
> routing is the diagram author's job — see the
> [hso-diagram-drawio Edge Routing Rule](../hso-diagram-drawio/SKILL.md#edge-routing-rule--critical)
> and its mandatory render-verify step.

### Running the audit

The audit is a single async arrow-function expression in [scripts/audit-slide-layout.js](scripts/audit-slide-layout.js). Run it via a small Node wrapper that drives Playwright directly — `playwright-cli eval "$(cat ...)"` was tried and has serialization issues with scripts of this size.

```javascript
// run-audit.js — keep next to the deck, or in scripts/
const { chromium } = require('playwright');
const fs   = require('fs');
const path = require('path');

(async () => {
    const deck = process.argv[2];
    if (!deck) { console.error('usage: node run-audit.js <deck.html>'); process.exit(2); }

    const browser = await chromium.launch();
    const page    = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    await page.goto('file://' + path.resolve(deck));
    await page.waitForFunction(() => window.Reveal && Reveal.isReady && Reveal.isReady());

    const auditFn = fs.readFileSync(
        path.resolve(__dirname, '../.claude/skills/hso-revealjs-presentation/scripts/audit-slide-layout.js'),
        'utf8'
    );
    const problems = await page.evaluate(`(${auditFn})()`);

    console.log(JSON.stringify(problems, null, 2));
    await browser.close();
    process.exit(problems.length ? 1 : 0);
})();
```

```bash
node run-audit.js path/to/deck.html
```

The result is `[]` if the deck passes. Otherwise it is a list of `{index, title, contentH, availableH, overflowPx, whitespacePx, status}` entries identifying the slides to fix.

### Fix patterns (ordered by preference)

1. **OVERFLOW** on a card grid with 8 items → convert `card-grid cols-2`
   (4 rows) to `card-grid cols-4 dense` (2 rows).
2. **OVERFLOW** on a table-heavy slide → add `compact-table` class.
3. **OVERFLOW** on a cards-with-callout slide → add `compact` modifier to the
   `card-grid` (see [slide-components.md → Density Classes](references/slide-components.md#density-classes)).
4. **WHITESPACE** on a sparse-table slide → add `lg-table` class.
5. **WHITESPACE** on a simple bullet-list slide → mark the `<ul class="lead-list">`
   to enlarge items.
6. **WHITESPACE** on a workflow/bullets slide → add a short supporting
   `callout` beneath the content.
7. **WORKFLOW_WRAP** → the workflow CSS in this skill already sets
   `flex-wrap:nowrap` + equal-width nodes. If a wrap still happens, the deck
   is using the old CSS — resync the workflow rules from
   [slide-components.md → Workflow Diagrams](references/slide-components.md#workflow-diagrams).

## Local-file Preview with playwright-cli

To open `file://` URLs directly (no HTTP server), keep
`.playwright/cli.config.json` at the repo root:

```json
{ "allowUnrestrictedFileAccess": true }
```

Always open decks headed in Edge for visual review:

```bash
playwright-cli open --headed --browser=msedge \
    --config=.playwright/cli.config.json \
    "file:///absolute/path/to/deck.html"
```

Chrome is NOT the default browser — user preference is Edge.

## Quick Start Template

The editorial baseline assumes a **1920×1080** stage. Body text is sized in absolute pixels (not `em`), so display sizes stay consistent across deck lengths. For 1280×720, scale `--t-*` and `--pad-*` tokens by 0.667.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>[Presentation Title]</title>
<link rel="stylesheet" href="https://unpkg.com/reveal.js@5/dist/reveal.css">
<link rel="stylesheet" href="https://unpkg.com/reveal.js@5/dist/theme/white.css">
<script src="https://unpkg.com/reveal.js@5/dist/reveal.js"></script>
<script src="https://unpkg.com/reveal.js@5/plugin/notes/notes.js"></script>
<style>
/* === HSO editorial baseline — Reveal-compatible flex layout ===
   See references/hso-branding.md for the canonical palette and display scale.
   READ the four Reveal compatibility gotchas at the top of SKILL.md before
   touching this CSS — every "obvious" simplification has been tried and broke
   something. */
:root {
    --hso-dark-blue: #00395F;
    --hso-bluegreen: #079FC3;
    --hso-bluegreen-bright: #11B6D9;
    --hso-steel:     #7F9CAF;
    --hso-green:     #00B294;
    --hso-salmon:    #F1554B;
    --hso-salmon-warm: #F58974;
    --hso-mimosa:    #F2B949;
    --hso-mimosa-edge: #F9DC95;
    --text: #505050;
    --text-muted: #737373;
    --bg: #FFFFFF;
    --card-bg: #F7FAFC;
    --border: #E6E6E6;

    /* Editorial semantic tokens */
    --ink:       var(--hso-dark-blue);
    --ink-2:     #1B4A70;
    --accent:    var(--hso-bluegreen);
    --accent-2:  var(--hso-bluegreen-bright);
    --paper:     #FFFFFF;
    --muted:     #5A6B78;
    --line:      #E4E8EC;
    --code-bg:   #F4F7FA;

    /* Display scale @ 1920×1080 */
    --t-hero: 84px; --t-title: 64px; --t-subtitle: 44px;
    --t-body: 30px; --t-small: 26px; --t-kicker: 24px; --t-foot: 20px;

    --footer-h: 56px;

    /* Aliases */
    --hso-navy: var(--hso-dark-blue); --hso-blue: var(--hso-bluegreen);
    --hso-teal: var(--hso-green); --hso-coral: var(--hso-salmon); --hso-amber: var(--hso-mimosa);
}

.reveal { font-family:'Segoe UI','Segoe UI Web (West European)',system-ui,-apple-system,sans-serif; color:var(--ink); font-size:32px; }
/* GOTCHA #4: Reveal's white.css uppercases all headings. Defeat with !important. */
.reveal h1, .reveal h2, .reveal h3, .reveal h4, .reveal h5, .reveal h6 { text-transform:none !important; }
.reveal h1, .reveal h2 { color:var(--ink); font-weight:400; letter-spacing:-0.015em; line-height:1.05; margin:0; }
.reveal h3 { color:var(--accent); font-weight:600; font-size:1.05em; }
.reveal h4 { font-weight:600; }

/* GOTCHA #2 + #3: Style colors/padding/text on sections, but DO NOT touch
   `position` (Reveal needs absolute), and DO use `box-sizing: border-box`
   (otherwise padding inflates the section past 1920×1080). */
.reveal .slides section.slide { box-sizing:border-box; background:var(--paper); color:var(--ink); padding:0 !important; text-align:left; overflow:hidden; }
.reveal .slides section.slide * { box-sizing:border-box; }

/* GOTCHA #1: Reveal sets style="display:block" inline on the active slide.
   Slide types needing other display must use !important. */
.reveal .slides section.slide.title-slide { display:grid !important; grid-template-columns:1fr 1fr; height:100%; }
.reveal .slides section.slide.divider { background:var(--ink); color:#fff; height:100%; }
.reveal .slides section.slide.divider.teal { background:var(--accent); }
.reveal .slides section.slide.stat { background:var(--accent); color:#fff; height:100%; }
.reveal .slides section.slide.closing { background:var(--paper); height:100%; }

/* === Content slide layout === */
/* Force flex column on content slides; defeat Reveal's inline display:block. */
.reveal .slides section.slide.content { display:flex !important; flex-direction:column; height:100%; padding:90px 100px 0 !important; }
.reveal .slides section.slide.content > .footer { margin:auto -100px 0; }

/* Body region — flex-grow fills the section above the footer. Pin trailing
   "summary" elements (callout, quote, stat-row) to the bottom of the body
   region with margin-top:auto, so the slide reads as content-on-top with a
   pinned takeaway-on-bottom rather than content floating in the middle. */
.body-region { flex:1 1 auto; min-height:0; display:flex; flex-direction:column; padding-bottom:36px; }
.body-region > .stat-row:last-child,
.body-region > .quote-box:last-child,
.body-region > .callout:last-child,
.body-region > .callout.info:last-child,
.body-region > .callout.success:last-child,
.body-region > .workflow-pipe:last-child,
.body-region > .pin-bottom {
    margin-top:auto !important;
}

/* Footer — required on every content slide. Three slots. */
.footer { height:var(--footer-h); background:var(--ink); color:#fff; display:flex; align-items:center; justify-content:space-between; padding:0 36px; font-size:var(--t-foot); letter-spacing:0.02em; }
.footer .f-left { color:rgba(255,255,255,0.78); }
.footer .f-right { display:inline-flex; align-items:center; gap:14px; color:rgba(255,255,255,0.88); }
.footer .tag { color:rgba(255,255,255,0.7); font-size:16px; letter-spacing:0.14em; text-transform:uppercase; }
.footer .wordmark { display:inline-flex; align-items:center; padding:5px 12px; background:#fff; color:var(--ink); font-weight:700; letter-spacing:0.04em; border-radius:2px; font-size:18px; }

/* Kicker, title, body, bullets */
h1.title { font-size:var(--t-title); font-weight:400; color:var(--ink); line-height:1.05; letter-spacing:-0.015em; margin:0 0 20px; }
.kicker { font-size:var(--t-kicker); font-weight:700; color:var(--accent); letter-spacing:0.12em; text-transform:uppercase; margin:0 0 14px; }
.kicker.coral  { color:var(--hso-salmon); }
p.body { font-size:var(--t-body); line-height:1.35; color:var(--ink); margin:0 0 18px; }
p.body.muted { color:var(--muted); }
ul.bullets { list-style:none; padding:0; margin:8px 0 0; }
ul.bullets li { position:relative; padding-left:26px; margin-bottom:10px; font-size:var(--t-body); line-height:1.4; }
ul.bullets li::before { content:""; position:absolute; left:0; top:0.55em; width:8px; height:8px; background:var(--ink); border-radius:999px; }

/* Columns */
.cols { display:grid; grid-template-columns:1fr 1fr 1fr; gap:50px; align-items:start; }
.cols.two { grid-template-columns:1fr 1fr; }
.cols > .col { display:flex; flex-direction:column; }

/* Cards — sized for 1920×1080 legibility. Cards stay content-height (DO NOT
   auto-stretch with flex:1 — produces giant empty tiles). Tune visual weight
   via padding + font sizes instead. */
.card { background:var(--card-bg); border:1px solid var(--border); border-radius:6px; padding:38px 42px; }
.card h4 { color:var(--ink); font-size:34px; font-weight:600; margin:0 0 16px; line-height:1.2; }
.card p, .card li { font-size:27px; line-height:1.5; color:var(--ink); margin:0; }
.card ul { list-style:none; padding:0; margin:14px 0 0; }
.card ul li { position:relative; padding-left:28px; margin:12px 0; font-size:25px; line-height:1.45; }
.card ul li::before { content:""; position:absolute; left:0; top:0.6em; width:9px; height:9px; background:var(--accent); border-radius:999px; }
.card-grid { display:grid; gap:22px; }
.card-grid.cols-2 { grid-template-columns:1fr 1fr; }
.card-grid.cols-3 { grid-template-columns:1fr 1fr 1fr; }

/* Tables — sized to match card body (27px) so tables don't read as
   "less important" than cards on the same slide. */
.reveal table { font-size:26px; border-collapse:collapse; width:100%; margin:10px 0; }
.reveal table th { background:var(--ink); color:#fff; padding:14px 20px; text-align:left; font-weight:600; font-size:20px; letter-spacing:0.04em; text-transform:uppercase; }
.reveal table td { padding:14px 20px; border-bottom:1px solid var(--line); color:var(--ink); }
.reveal table tr:nth-child(even) td { background:var(--card-bg); }
.reveal table.compact-table { font-size:23px; }
.reveal table.compact-table th, .reveal table.compact-table td { padding:10px 14px; }

/* Section divider — large title centered. Variants: default ink, .teal, .coral, .sand. */
.reveal .slides section.slide.divider .div-inner { display:flex; flex-direction:column; justify-content:center; height:100%; padding:0 100px; }
.reveal .slides section.slide.divider .kicker.section { color:var(--accent-2); letter-spacing:0.12em; text-transform:uppercase; font-size:var(--t-kicker); font-weight:700; margin-bottom:18px; }
.reveal .slides section.slide.divider h1 { font-size:var(--t-hero); color:#fff; margin:0 0 16px; font-weight:400; letter-spacing:-0.02em; }
.reveal .slides section.slide.divider .sub { font-size:var(--t-subtitle); color:rgba(255,255,255,0.85); font-weight:400; line-height:1.25; max-width:1500px; }
.reveal .slides section.slide.divider.teal .kicker.section,
.reveal .slides section.slide.divider.teal .sub { color:var(--ink); opacity:0.85; }

/* Stat slide */
.reveal .slides section.slide.stat .div-inner { display:flex; flex-direction:column; justify-content:center; height:100%; padding:0 100px; }
.reveal .slides section.slide.stat .big { font-size:260px; line-height:1; font-weight:300; letter-spacing:-0.04em; color:#fff; margin-bottom:24px; }
.reveal .slides section.slide.stat .cap { font-size:var(--t-subtitle); color:var(--ink); opacity:0.9; max-width:1100px; font-weight:400; line-height:1.25; }

/* Title slide split — text left, photo right */
.title-left { position:relative; padding:72px 80px; display:flex; flex-direction:column; }
.title-left::before { content:""; position:absolute; left:0; top:120px; bottom:120px; width:7px; background:var(--accent); }
.title-left .block { margin:auto 0; }
.title-left h1 { font-size:var(--t-hero); font-weight:400; letter-spacing:-0.02em; color:var(--ink); line-height:1.02; margin:0 0 24px; }
.title-left .sub { font-size:var(--t-subtitle); color:var(--accent); font-weight:400; line-height:1.25; max-width:700px; }
.title-left .foot { color:var(--muted); font-size:22px; margin-top:24px; }
.title-left .foot .who { color:var(--ink); font-weight:500; }
.title-right { position:relative; background:var(--ink); overflow:hidden; }
.title-right .hero-img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; }
.title-right::after { content:""; position:absolute; inset:0; background:linear-gradient(180deg, rgba(0,57,95,0) 55%, rgba(0,57,95,0.55) 100%), linear-gradient(90deg, rgba(0,57,95,0.45) 0%, rgba(0,57,95,0) 35%); pointer-events:none; }
/* IMPORTANT: HSO Logo.png is white-on-transparent. Place over the dark photo
   side, NEVER on the white .title-left side (it would render invisibly). */
.title-right .logo-overlay { position:absolute; top:50px; left:50px; z-index:2; }
.title-right .logo-overlay img { height:48px; filter:drop-shadow(0 2px 4px rgba(0,0,0,0.4)); }

/* Closing */
.reveal .slides section.slide.closing .div-inner { display:flex; flex-direction:column; justify-content:center; height:100%; padding:0 100px; }
.reveal .slides section.slide.closing h1 { font-size:var(--t-hero); color:var(--ink); margin:0 0 24px; font-weight:400; letter-spacing:-0.02em; max-width:1500px; line-height:1.05; }
.reveal .slides section.slide.closing .sub { font-size:var(--t-subtitle); color:var(--accent); margin-bottom:50px; max-width:1200px; line-height:1.25; }
.reveal .slides section.slide.closing .asks { display:grid; grid-template-columns:repeat(3,1fr); gap:50px; max-width:1500px; }
.reveal .slides section.slide.closing .asks .ask-n { font-family:'Consolas','SF Mono',monospace; font-size:18px; color:var(--accent); letter-spacing:0.1em; margin-bottom:10px; }
.reveal .slides section.slide.closing .asks .ask-t { font-size:26px; font-weight:500; color:var(--ink); line-height:1.3; }

/* Hide Reveal default chrome — footer carries the slide number */
.reveal .controls, .reveal .progress, .reveal .slide-number { display:none !important; }

/* See references/slide-components.md for: cap-grid, roadmap, arch, personas,
   stories, callout-mono, callout (advisory), quote-box, workflow-pipe,
   diagram-box, step-row, badges, skill-tag. */

/* Print-PDF: prevent blurry text from CSS transform scaling */
@media print {
    .reveal .slides { transform:none !important; width:100% !important; height:auto !important; }
    .reveal .slides section { transform-style:flat !important; -webkit-backface-visibility:hidden !important; backface-visibility:hidden !important; }
    * { -webkit-print-color-adjust:exact !important; print-color-adjust:exact !important; }
}
</style>
</head>
<body>
<div class="reveal">
<div class="slides">

<!-- 01: Title slide — split layout (text left, photo right) -->
<!-- HSO logo goes on the DARK side (.title-right), not on the white .title-left. -->
<section class="slide title-slide">
    <div class="title-left">
        <div class="block">
            <h1>[Main Title]</h1>
            <div class="sub">[Subtitle — one sentence positioning]</div>
        </div>
        <div class="foot"><span class="who">[Author]</span> &middot; [email] &middot; [Audience] &middot; [Date]</div>
    </div>
    <div class="title-right">
        <img class="hero-img" src="[hero.jpg]" alt="[Description]">
        <div class="logo-overlay"><img src="[HSO Logo.png]" alt="HSO"></div>
    </div>
    <aside class="notes">Cover. Set context, name the audience.</aside>
</section>

<!-- 02: Section divider — full-bleed solid color, kicker + title + sub centered -->
<section class="slide divider">
    <div class="div-inner">
        <div class="kicker section">Section 01</div>
        <h1>[Section title].</h1>
        <div class="sub">[One-sentence section frame.]</div>
    </div>
    <aside class="notes">Hand-off into the next section.</aside>
</section>

<!-- 03: Content slide — flex column with .body-region + .footer.
     Note the `content` class on the section — it triggers the flex layout
     that pins the footer to the bottom and lets .body-region distribute
     vertical space (including margin-top:auto on trailing callouts). -->
<section class="slide content">
    <div class="body-region">
        <div class="kicker">[Section] &middot; [NN]</div>
        <h1 class="title">[Slide title.]</h1>
        <p class="body muted">[One-sentence frame.]</p>

        <!-- content: .cols, .cap-grid, .personas, .roadmap, .arch, table, etc. -->

        <!-- Optional trailing element — auto-pinned to the bottom of body-region -->
        <div class="quote-box">"[One-line takeaway in the slide's voice.]"</div>
    </div>
    <div class="footer">
        <span class="f-left">[NN] &middot; [Section]</span>
        <span class="f-right">
            <span class="tag">[Deck name]</span>
            <span class="wordmark">HSO</span>
        </span>
    </div>
    <aside class="notes">Speaker notes…</aside>
</section>

<!-- 04: Stat slide — 1–2× per deck max -->
<section class="slide stat">
    <div class="div-inner">
        <div class="big">1</div>
        <div class="cap">[Caption — what the number stands for.]</div>
    </div>
    <aside class="notes">Pause. Let the number land.</aside>
</section>

<!-- 05: Closing slide -->
<section class="slide closing">
    <div class="div-inner">
        <h1>[Closing question or call to action.]</h1>
        <div class="sub">[One-sentence wrap.]</div>
        <div class="asks">
            <div><div class="ask-n">01</div><div class="ask-t">[First takeaway.]</div></div>
            <div><div class="ask-n">02</div><div class="ask-t">[Second takeaway.]</div></div>
            <div><div class="ask-n">03</div><div class="ask-t">[Third takeaway.]</div></div>
        </div>
    </div>
    <aside class="notes">Q&amp;A.</aside>
</section>

</div>
</div>
<script>
Reveal.initialize({
    hash: true,
    slideNumber: false,           // footer carries the slide number
    transition: 'slide',
    width: 1920,                  // editorial baseline is 1920×1080
    height: 1080,
    margin: 0,                    // section flex layout handles padding
    center: false,                // we own vertical alignment
    plugins: [ RevealNotes ]
});
</script>
</body>
</html>
```

## Editorial Voice & Factual Grounding

Every load-bearing claim on a slide (or in a speaker note) has two parts: a **status** (proposed, decided, recommended, considered, mandated, observed) and **evidence** that the status is accurate. The verb has to match the status, and the status has to trace to evidence.

This rule applies whether the deck is a proposal, training piece, workshop artifact, or status update on already-decided work. It does not push a default register — a decided approach should be described as decided when there is evidence the decision was made; a proposed approach should be described as proposed when no decision has been recorded.

Digest only — [references/editorial-voice.md](references/editorial-voice.md) is the authority for editorial voice and factual grounding (full status vocabulary, banned-phrase tables, person-reference rules, competitor-neutrality patterns, self-credential rules, and the pre-delivery checklist). Read it before writing any slide copy or speaker notes. The five principles below are an actionable recap, not a replacement for the reference.

### 1. Status fidelity — the verb matches the actual status

Match the language of every claim to its actual status:

| Status | Phrasing | Evidence required |
|---|---|---|
| Decided / committed | "X is committed in [SOW]"; "the client has agreed to X" | SOW, approval record, prior commitment |
| Proposed | "the proposal contemplates X"; "the recommended approach is X" | The proposal itself + rationale on the slide |
| Recommended | "X is recommended because Y" | Stated rationale + evidence for the rationale |
| Under consideration | "X is under consideration; decision gate at [date]" | Open question, owner, target date |
| Mandated by client / regulation | "X is required by [policy / regulation]" | The policy or regulation citation |
| Observed | "the discovery materials show X" | Discovery artifact citation |

The fault to avoid: a claim that asserts commitment ("we will deliver X", "X is decided", "HSO is the choice") when the evidence supports only a softer status ("X is considered", "HSO is one of the candidates").

When summarizing a long-form document, the deck cannot upgrade the source's status — see §5 below.

### 2. Banned phrases — colloquialisms, idioms, marketing superlatives

Some phrases fail regardless of claim status. The full list with replacement patterns lives in [references/editorial-voice.md](references/editorial-voice.md). Examples:

- **Colloquialisms / idioms** to avoid: "earns its keep", "stays honest", "babysitting", "rides [the roadmap]", "in the room", "lands hardest", "the homework's done", "hand-wave", "natural next chapter".
- **Superlatives without evidence** to avoid: "the single highest X", "the only honest position", "the safe choice", "best-in-class". A superlative is permitted only when the claim is substantiated on the same slide by a numeric basis or explicit comparison.
- **Conversational shortcuts** to avoid: "no VC pressure", "every dollar of X is a dollar of Y" — replace with direct cause/effect language grounded in evidence.

### 3. Person references — roles, not first names

Refer to client and HSO people by **role and division**, not first name, unless one of the following holds:

1. The person has been formally introduced earlier in the deck (e.g., a named author block, an org chart, a sponsorship slide).
2. The person is the deck's named author/owner.
3. The reference is a documented direct quote attributed to a cited discovery artifact.

"the [Utility platform owner]'s roadmap", not "Chris's roadmap". "the [executive sponsor]", not "Jason". This is generic professionalism — first-name references in client-facing material assume a familiarity that may not be reciprocal.

### 4. Competitor neutrality

The deck never:

- Names a competitor.
- Uses coded references to competitors ("Big Four", "the incumbent", "another vendor", "most CRM proposals", "generic MSPs").
- Characterizes a competing approach as ignorant, lazy, or motivated by fee revenue.

Differentiation is asserted by describing what HSO does and why, with evidence — not by describing what others fail to do.

This rule applies to **speaker notes equally**. Notes are exposed when a deck is exported in trainer mode, distributed in PDF, or screen-shared in demo mode.

### 5. Cross-document consistency

If the deck summarizes a long-form document (proposal markdown, design doc, SOW), the deck's status claims must not be firmer than the source.

- If the source says "considered", the deck cannot say "committed".
- If the source says "up to N weeks", the deck cannot say "N weeks".
- If the source flags an open question, the deck cannot present a closed answer.

This catches deck/source-doc drift. The source documents are identified at discovery question 7 above; the writer should compare the deck's status verbs against the source documents before publishing.

### Pre-delivery checks (mechanical)

The full checklist is in [references/editorial-voice.md](references/editorial-voice.md). Three mechanical checks worth running before declaring a deck done:

1. **Banned-phrase grep** — search the deck HTML for the banned-phrase list; replace each match.
2. **Numerical-claim grounding** — for every number, named entity, percentage, date, or attributed quote on a slide, the speaker notes (or a deck-level source list) cite the discovery artifact or source document the claim traces to.
3. **Source-doc verb diff** — when the deck summarizes a source document, compare the deck's status verbs against the source's. Any verb that's firmer in the deck is a defect.

Judgment-call checks (the verb-matches-status check in particular) remain the writer's responsibility. The mechanical checks catch the common offenders; they do not catch absent claims, mis-attributed claims, or claims the writer should have made differently.

## Speaker Notes Guidelines

Every content slide MUST include `<aside class="notes">`. Section dividers, title slides, and video-placeholder slides follow relaxed rules (see end of this section).

### The one rule that drives everything else

**Speaker notes answer why/so-what, not recite slide content.**

The audience can read the slide. Your notes must add what the slide cannot:

1. **Why does this matter to this audience?** What specific operational pain, decision, or risk does the design address for the people in the room?
2. **Why did we design it this way?** What alternative did we reject, and what pressure (business, audit, regulatory, scale) forced this shape?
3. **How will it help them run the business better?** Concrete before/after — what stops being manual, what stops requiring a spreadsheet, what stops being late?

If a reader of the notes couldn't tell which slide it belongs to because the prose only talks about the user's problem and the design decision, you're doing it right.

### Anti-patterns — do NOT do these

**Reciting the slide.** Never walk field tables, bullet lists, or card grids item-by-item in the notes. ("`hso_amountdue` is the invoice amount due. `hso_amountpaid` is what's been collected…") The table is on the slide. Explain the *decisions* the fields enable and the *pain* they remove instead.

**Count-and-structure preambles.** Never open with sentences that count or announce visible structure:
- "Three tables under the pricing engine."
- "Five numbers to hold in your head."
- "Four reasons on the left."
- "Two stories on one slide."
- "Eleven rows. Walk them with me."
- "Nine fields and Finance lives in all of them."

The count-plus-vague-claim variant is just as bad — pairing a number with a generic platitude ("Finance lives in all of them", "every one matters") is still throat-clearing. Open with substance directly; use connective tissue ("On the right, X carries…") not enumeration.

**Walking diagram nodes one-by-one** unless the walk *is* the insight. If the diagram's reading order is obvious, skip the walk and narrate why the shape exists.

**Repeating slide copy in slightly different words.** If the bullet says "Rate locked at quote acceptance," do not say in the notes "The rate is locked when the quote is accepted." Instead: "We lock the rate at sale because the alternative — retroactive rate changes from corporate — introduces franchisor-franchisee disputes we've seen cost real money on other franchise platforms."

### Two-tier structure for high-stakes decks

> **Client-facing means HSO internals stay off the slides.** When the deck or its notes will be shown outside HSO, state the *recommendation*, not the HSO SOP rationale or Override text behind it, and keep SOP/skill paths and `agent/wiki/` citations out of the rendered output. Those are HSO IP — see `hso-client-deliverable-standards.md` §7 "What may not leave the building".

Client-facing presales and training decks benefit from a two-version structure in each `<aside class="notes">`:

- **TIGHT (primary) — target ~60 seconds of spoken delivery.** This is the version the presenter uses by default. Trim beats ruthlessly; do not sacrifice the why/so-what.
- **FULL (backup) — ~1:30 to 2:00.** Extended version with deeper examples and auditor-grade detail; used when the room wants depth or when the presenter has extra time.

75-second "tight" versions drift into overpacked delivery. 60 seconds is the discipline. Intro/framing slides may run longer by exception (e.g., a thesis slide where landing the frame is the whole point).

Optional sections in the same `<aside>`: a short Anticipated-Questions table (likely Q / crisp A) and a Timing table that tells the presenter which version to use when.

For lower-stakes decks (internal training, informal reviews) a single block is fine — still follow the why/so-what rule.

### Demo cues and transitions

When the slide drives a live demo, prefix the relevant portion with `DEMO:`. Describe exactly what to click, what to say while the UI loads, and the recovery path if the environment is flaky.

Transition cues belong at the end of the notes — a one-line handoff to the next slide. Don't bury the transition in the middle of narration.

### Minimal acceptable shape

```html
<aside class="notes">
    <p><strong>Why this matters:</strong> Partial collections are ~12% of monthly volume
       and today require manual spreadsheet reconciliation. The split between amount-due
       and amount-paid retires that spreadsheet — Collections sees the residual, aging
       scores it, no Excel in the loop.</p>

    <p><strong>Design decision:</strong> A native boolean `paid` flag couldn't represent
       partial payment; we rejected it. The pair of currency fields is what makes the
       retry batch and aging logic composable.</p>

    <p>DEMO: open the Brown Family billing event, show $75 in amount-paid against
       $149 due, aging bucket 1-30 days.</p>

    <p>Transition: "Next, the lifecycle state machine that ties these fields together."</p>
</aside>
```

### Editorial Voice rules apply to notes equally

Speaker notes are not a relaxed-tone zone. They are exposed when a deck is exported to PDF, demoed in trainer mode, or distributed alongside the slides. The [Editorial Voice & Factual Grounding](#editorial-voice--factual-grounding) rules — status fidelity, banned phrases, person references, competitor neutrality, cross-document consistency — apply to notes equally.

Three failure modes specific to speaker notes that the audit should flag:

- **Trust / room framings.** Avoid "this is the slide where they trust us or don't", "this lands hardest in the room", "this is what we need them to believe". These reveal posture rather than substance. Replace with specific framings: "this slide will be examined most closely on technical detail", "the data on this slide is the basis for the recommendation in the next section".
- **Coded competitor jabs.** "Most CRM proposals do X", "a generic Managed Services answer would Y", "Big-Four pricing", "any vendor who […] is [ignorant / fee-driven]". Same rule as on-slide: differentiation is asserted by describing what HSO does and why, not by characterizing competitors.
- **First-name attributions** to client people who haven't been formally introduced. Use roles. (See Editorial Voice §3.)

### Section dividers, title slides, video placeholders

- **Section dividers:** ~15-20 seconds of speaker notes — announce the section and the through-line in one sentence.
- **Title/cover slides:** ~20 seconds — audience orientation, not content.
- **Video-placeholder slides:** presenter cues for transition-in, transition-out, and skip-gracefully-if-behind. These do not need why/so-what depth because the video is the content; the notes exist to frame the video.

## PDF Export & Print Quality

### How to Export to PDF

Use Chrome's built-in **Print > Save as PDF** (not "Microsoft Print to PDF" — the latter produces significantly worse output):

1. Open your presentation with `?print-pdf` in the URL, e.g. `file:///path/to/deck.html?print-pdf`
2. Open the print dialog (Ctrl+P / Cmd+P)
3. Set **Destination** to **Save as PDF**
4. Set **Layout** to **Landscape**
5. Set **Margins** to **None**
6. Enable **Background graphics**
7. Click **Save**

> **Important**: Only Chrome/Chromium is supported for PDF export. Firefox produces broken output. "Microsoft Print to PDF" renders at lower DPI and produces blurry text — always use Chrome's native "Save as PDF" destination.

### Preventing Blurry Text in Print

Reveal.js uses `transform: scale()` to fit slides into the browser viewport. When Chrome prints, this CSS transform causes text to be rasterized as a bitmap instead of crisp vector text. To fix this, **always include the following `@media print` block** in every presentation:

```css
/* Print-PDF: prevent blurry text from CSS transform scaling */
@media print {
    .reveal .slides {
        transform: none !important;
        width: 100% !important;
        height: auto !important;
    }
    .reveal .slides section {
        transform-style: flat !important;
        -webkit-backface-visibility: hidden !important;
        backface-visibility: hidden !important;
    }
    * {
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
    }
}
```

**What each rule does:**
- `transform: none` — removes the scale transform so Chrome renders text as native vector instead of scaling a bitmap
- `transform-style: flat` + `backface-visibility: hidden` — eliminates 3D rendering artifacts that cause sub-pixel blurriness
- `print-color-adjust: exact` — ensures backgrounds and colors print faithfully

### Alternative: decktape

For highest quality PDF output, [decktape](https://github.com/astefanutti/decktape) is a command-line tool that renders slides at full resolution without going through the browser print pipeline.

---

## PowerPoint Conversion

When collaborators require `.pptx` format (Microsoft co-sell partners, client teams on PowerPoint), convert a Reveal.js deck to PowerPoint using the bundled helpers module and the pptx skill.

Authority for Reveal.js→PowerPoint conversion (color mapping, component translation, dimensions, QA) — read [references/pptx-conversion.md](references/pptx-conversion.md) before converting a deck to .pptx. It is the complete color mapping, component translation cheat sheet, dimensions, and QA checklist.

### When to Convert

- Microsoft co-sell partners need to edit or present from PowerPoint
- Client stakeholders are on PowerPoint-only workflows
- The deck needs to be embedded in a SharePoint/Teams channel where `.html` isn't practical

### Conversion Workflow

1. **Read the source `.html` deck** to understand slide count, structure, and component types used
2. **Invoke the pptx skill** — it provides the pptxgenjs creation guide and QA pipeline
3. **Write a per-deck generation script** that imports the helpers module:
   ```javascript
   const { C, helpers } = require(".claude/skills/hso-revealjs-presentation/scripts/revealjs-to-pptx-helpers");
   const pres = helpers.createPresentation("Deck Title", "Author Name");
   ```
4. **Map each HTML slide** to the appropriate helper function:
   - `<section class="title-slide">` → `helpers.addTitleSlide(pres, { ... })`
   - `<section class="section-divider">` → `helpers.addSectionDivider(pres, ...)`
   - Content `<section>` → `helpers.addContentSlide(pres, "Title", footerText)`
   - Then populate with `helpers.card()`, `helpers.addWorkflow()`, `helpers.addTable()`, etc.
5. **Run the script** with `NODE_PATH` set to global modules:
   ```bash
   NODE_PATH="$(npm root -g)" node generate_deck.js
   ```
6. **QA** via the pptx skill's pipeline: `python -m markitdown output.pptx` for content, visual inspection for layout
7. **Delete the generation script** — it's disposable; the helpers module is the durable asset

### Available Helpers

| Function | Maps to Reveal.js | Description |
|---|---|---|
| `addTitleSlide()` | `.title-slide` | HSO-branded title with context line, title, subtitle, meta |
| `addSectionDivider()` | `.section-divider` | Navy background with section label + title + subtitle |
| `addContentSlide()` | Content `<section>` | White bg, blue top accent line, navy footer bar |
| `addClosingSlide()` | Q&A slide | Navy background with title + subtitle |
| `card()` | `.card` with border-left | Accent-bordered box with title + bullet list |
| `cardSmall()` | `.card-grid.dense .card` | Compact card for 4×2 grids and agenda layouts |
| `addWorkflow()` | `.workflow` | Horizontal flow boxes with arrow separators |
| `addLayerStack()` | `.layer-stack` | Stacked horizontal bars for architecture layers |
| `addBullets()` | `<ul>` bullets | Text array with `bullet: true` |
| `addCallout()` | `.callout` / `.callout.info` | Colored left-bar callout (info/amber/warn) |
| `addTable()` | `<table>` | Navy header row, alternating fills |
| `addStatBoxes()` | `.stat-row .stat-box` | Large numbers with small labels |
| `embedSvg()` | `<img src="*.svg">` | SVG→PNG via sharp, base64-embedded |

### Dependencies

```bash
npm install -g pptxgenjs react-icons react react-dom sharp
```

### Key Rules

- **Never use `#` in hex colors** — pptxgenjs corrupts files with `#` prefix
- **Never reuse shadow/option objects** between calls — pptxgenjs mutates them in place
- **Always use `makeShadow()` factory** for consistent shadow across cards
- **Rasterize SVGs at 2400px width** for crisp rendering on HD displays
- **Font is Segoe UI throughout** — matches the HTML deck and HSO brand manual

---

## Best Practices

1. **Slide-type discipline**: Pick from the five [slide types](#slide-type-vocabulary) per slide. Don't author ad-hoc layouts.
2. **Footer on every content slide**: The navy footer bar is required — it carries the slide number, section, and brand wordmark. Skipping it breaks the deck's family resemblance.
3. **Content density**: One main concept per slide. Editorial whitespace is the look — fight the urge to fill every pixel.
4. **One accent per deck**: Pick a dominant accent and stay with it (see [Accent Discipline](#accent-discipline)). Inject color personality through `.divider.coral` / `.sand` / `.teal` between sections, not on every content slide.
5. **Speaker notes**: Include `<aside class="notes">` on every slide.
6. **Sequential timelines → Roadmap, not Workflow**: Use `.roadmap` (dots on a line) for phases/quarters/releases. Reserve `.workflow` for true process flows with parallel inputs/outputs.
7. **Stat slides are punctuation**: 1–2 per deck max. More and they lose force.
8. **Comparisons**: `.cols.two` for two-up, `.cols` (3-up) for three-up.
9. **Accessibility**: Alt text on every image; the title-slide hero photo gets a real description, not "image".
10. **Print quality**: Always include the `@media print` CSS block (see [PDF Export](#pdf-export--print-quality) above).
11. **Voice and factual grounding**: Every claim's verb matches its actual status; every status claim and every numerical claim traces to evidence; every superlative is substantiated; every person reference uses role, not first name; no competitor references (named or coded) anywhere in the deck. See [Editorial Voice & Factual Grounding](#editorial-voice--factual-grounding) before declaring a deck done.
