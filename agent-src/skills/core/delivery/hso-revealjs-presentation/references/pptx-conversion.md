# Reveal.js → PowerPoint Conversion Guide

When a Reveal.js deck needs to be shared with collaborators who require `.pptx` format (e.g., Microsoft co-sell partners, client teams on PowerPoint), use this guide to produce a faithful conversion.

## Approach

Each conversion is a **per-deck generation script** that imports reusable helpers from `scripts/revealjs-to-pptx-helpers.js`. Full automation (HTML parsing → PPTX) is not attempted — each deck has enough layout variation that a human-in-the-loop script produces better results.

**Workflow:**
1. Read the source `.html` deck
2. Write a Node.js script that uses `pptxgenjs` + the helpers module
3. Map each slide to the appropriate helper functions
4. Run the script → `.pptx` output
5. QA via the pptx skill's visual inspection pipeline
6. Delete the generation script (it's disposable; the helpers are the durable asset)

## HSO Color Mapping

CSS variable → 6-char hex for pptxgenjs (no `#` prefix — pptxgenjs corrupts files with `#`).

| CSS Variable | Alias | Hex (pptxgenjs) | Use |
|---|---|---|---|
| `--hso-dark-blue` | `--hso-navy` | `00395F` | Titles, section divider backgrounds, footer bars, table headers |
| `--hso-bluegreen` | `--hso-blue` | `079FC3` | Accent color, stat numbers, card titles, top accent line |
| `--hso-steel` | — | `7F9CAF` | Muted text, arrows, footer text, subtitle text |
| `--hso-green` | `--hso-teal` | `00B294` | Success states, recommended options, highlighted workflow end-nodes |
| `--hso-salmon` | `--hso-coral` | `F1554B` | Warnings, ruled-out options, error states |
| `--hso-mimosa` | `--hso-amber` | `F2B949` | Caution callouts, gap callouts, anchor bands |
| `--hso-tagline` | — | `4A4A4A` | Logo tagline grey (rarely used in slides) |
| `--text` | — | `505050` | Body text |
| `--text-muted` | — | `737373` | Subtitles, captions, descriptions |
| `--card-bg` | — | `F7FAFC` | Card and shape fill backgrounds |
| `--border` | — | `E6E6E6` | Card outlines, table cell borders |
| `--bg` | — | `FFFFFF` | Slide backgrounds |
| Dark amber | — | `8B6A00` | Text on mimosa-accented cards (contrast-safe) |

### Callout Background Colors

| Type | Background | Border |
|---|---|---|
| Info | `E1F5FE` | `079FC3` (blue) |
| Amber (default) | `FFF8E1` | `F2B949` (amber) |
| Warning | `FFEBEE` | `F1554B` (coral) |

### Layer Stack Background Colors

| Layer | Background | Border | Text Color |
|---|---|---|---|
| Top (enterprise/configure) | `E1F0FF` | `079FC3` | `00395F` |
| Middle (orchestrated/extend) | `E6FFF9` | `00B294` | `006654` |
| Bottom (native/customize) | `F0F4F8` or `FFF8E1` | `7F9CAF` or `F2B949` | `00395F` or `8B6A00` |

## Component Translation Cheat Sheet

| Reveal.js Component | pptxgenjs Helper | Notes |
|---|---|---|
| `<section class="slide title-slide">` (split) | `addTitleSlide()` | Text + accent bar left, hero photo + logo overlay right |
| `<section class="slide divider">` | `addSectionDivider(label, title, sub, variant)` | Full-bleed colored bg, LEFT-aligned kicker + h1 + sub. variant: ink/teal/coral/sand |
| `<section class="slide stat">` | `addStatSlide(big, caption, note)` | Full-bleed teal, 200pt centered number, navy caption |
| `<section class="slide content">` | `addContentSlide({kicker, title, sub, footerLeft, deckTag})` | Kicker → title → sub → body zone, three-slot navy footer |
| `<section class="slide closing">` | `addClosingSlide({title, sub, asks, contact})` | Light bg, big title, sub in accent, 3-col asks grid, contact line |
| `.card` | `card(slide, x, y, w, h, title, bullets, borderColor)` | Bordered box with title + bullets |
| `.card-grid.cols-N.dense` cell | `cardSmall(slide, x, y, w, h, title, desc, color, side)` | Compact card variant |
| `.cap-grid` (numbered capability map) | `addCapGrid(slide, x, y, w, h, cells)` | 4×N grid; cells: `{num, name, desc, skill}` |
| `.roadmap` (timeline with dots) | `addRoadmap(slide, x, y, w, phases)` | phases: `{dot:'done'|'current'|'future', q, title, desc}` |
| `.workflow` / `.workflow-pipe` | `addWorkflow(slide, y, nodes, highlightLast)` | Horizontal flow boxes with arrows |
| `.arch` / `.layer-stack` | `addLayerStack(slide, y, layers)` | Stacked horizontal bars |
| `.stat-row .stat-box` (inline) | `addStatBoxes(slide, y, stats)` | Large numbers + small uppercase labels |
| `<table>` | `addTable(slide, x, y, w, rows, colW)` | Navy header (uppercase), alternating row fills |
| `.callout` / `.callout.info` / `.callout.success` | `addCallout(slide, x, y, w, h, text, type)` | Colored left bar + light bg. type: info/amber/warn/success |
| `.quote-box` (italic editorial quote) | `addQuoteBox(slide, x, y, w, h, text)` | Italic quote with accent left bar |
| Bare `<ul>` bullets | `addBullets(slide, x, y, w, h, items, fontSize)` | Text array with `bullet: true` |
| SVG diagrams | `embedSvg(slide, path, x, y, w, h)` | sharp → SVG→PNG (2400px) → base64 |

## Slide Dimensions & Spacing

**Layout: `LAYOUT_WIDE` = 13.33" × 7.5"** (the editorial 16:9 widescreen, matches HTML 1920×1080 proportions). Helpers automatically use this layout via `createPresentation()`.

### Content Slide Anatomy (editorial)

| Element | Position | Size |
|---|---|---|
| Kicker (small-caps accent) | x=0.6, y=0.5, w=12, h=0.35 | 16pt Segoe UI bold, blue, charSpacing 2 |
| Title (`h1.title`) | x=0.6, y=0.95, w=12, h=0.85 | 40pt Segoe UI regular, navy, charSpacing -0.2 |
| Subtitle (muted lede) | x=0.6, y=1.9, w=12, h=0.5 | 20pt Segoe UI regular, muted |
| Body zone | y≈2.5 to y≈6.9 | ~4.4" vertical space — place cards/tables/diagrams here |
| Footer bar | x=0, y=7.08, w=13.33, h=0.42 | Navy bg, three slots (left text · deck tag · HSO pill) |

### Card Dimensions (tuned for LAYOUT_WIDE editorial)

| Layout | Card Width | Card Height | Gap |
|---|---|---|---|
| 2-column | 5.8" | 3.5"–4.6" (content-dependent) | 0.5" between columns |
| 3-column | 3.9" | 3.0"–4.6" | 0.3" between columns |
| 4×2 dense grid | 2.95" | 1.2" | 0.2" gap |
| 4×N cap-grid (numbered) | use `addCapGrid()` — auto-laid out | min height 2.0" | 0.18" gap |

## Font Conventions (editorial)

All sizes available as constants under the exported `FS` object — import via:

```javascript
const { FS } = require("./revealjs-to-pptx-helpers");
// FS.title === 40, FS.body === 17, FS.kicker === 16, etc.
```

| Element | Constant | Size | Weight | Color |
|---|---|---|---|---|
| Title-slide hero, divider/closing h1, stat caption | `FS.hero` | 54pt | Regular (`bold:false`) | Navy/white per slide type |
| Content-slide title | `FS.title` | 40pt | Regular | Navy |
| Subtitle (title-slide / divider / closing) | `FS.subtitle` | 28pt | Regular | Accent / muted per context |
| Body, table cells | `FS.body` / `FS.tableTd` | 17pt | Regular | Navy |
| Card h4 | `FS.cardH4` | 22pt | Bold | Navy or accent |
| Card body (`li`, `p`) | `FS.cardLi` | 16pt | Regular | Navy |
| Cap-grid name | `FS.capName` | 20pt | Bold | Navy |
| Cap-grid number tag (mono) | `FS.capNum` | 12pt | Regular | Blue |
| Stat slide big number | `FS.statBig` | 200pt | Regular | White |
| Stat-box (inline) num / label | `FS.statNum` / `FS.statLbl` | 60pt / 13pt | Regular / Regular | Blue / muted uppercase |
| Table header (uppercase) | `FS.tableTh` | 13pt | Bold | White on navy |
| Kicker / eyebrow | `FS.kicker` | 16pt | Bold uppercase | Blue (accent) |
| Footer left text | `FS.footer` | 13pt | Regular | Light grey on navy |
| Footer deck-tag | `FS.footerTag` | 11pt | Regular tracked | Light grey on navy |

## Shadow Convention

All cards use a consistent subtle shadow:

```javascript
{ type: "outer", blur: 6, offset: 2, angle: 135, color: "000000", opacity: 0.12 }
```

**Critical:** Never reuse shadow objects between calls — pptxgenjs mutates them. Always use a factory function.

## SVG Diagram Embedding

When the source deck references SVG diagrams:

```javascript
const sharp = require("sharp");
const fs = require("fs");

const svgBuf = fs.readFileSync("diagrams/MyDiagram.svg");
const pngBuf = await sharp(svgBuf).resize({ width: 2400 }).png().toBuffer();
const b64 = "image/png;base64," + pngBuf.toString("base64");
slide.addImage({ data: b64, x: 0.5, y: 1.0, w: 9, h: 3.6,
  sizing: { type: "contain", w: 9, h: 3.6 } });
```

Rasterize at **2400px width** for crisp rendering on HD displays.

## QA Checklist

After generating the `.pptx`:

1. **Content completeness** — run `python -m markitdown output.pptx` and verify all slides and text are present
2. **Visual inspection** — if LibreOffice is available, convert to images via the pptx skill pipeline; otherwise open in PowerPoint
3. **Check for**:
   - Missing slides or content
   - Tables with clipped text
   - Cards that overlap or have insufficient spacing
   - Diagrams that didn't embed (fallback text showing)
   - Footer bar present on all content slides
   - Section dividers have navy background

## Dependencies

```bash
npm install -g pptxgenjs          # PPTX generation
npm install -g react-icons react react-dom sharp  # Icons + SVG rasterization
```

Set `NODE_PATH` to global modules if running scripts outside the global install directory:

```bash
NODE_PATH="$(npm root -g)" node generate_deck.js
```
