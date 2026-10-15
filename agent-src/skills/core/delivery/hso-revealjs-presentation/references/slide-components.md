# Slide Components Reference

This document contains all available CSS classes and HTML patterns for HSO Reveal.js presentations.

## Table of Contents

**Foundational (editorial baseline)**

1. [Body Region + Footer (the flex layout)](#body-region--footer)
2. [Kicker (eyebrow)](#kicker-eyebrow)
3. [Title Slide (split)](#title-slide-split)
4. [Section Dividers](#section-dividers)
5. [Stat Slide](#stat-slide)
6. [Closing Slide](#closing-slide)

**Content components**

7. [Capability Map (numbered grid)](#capability-map-numbered-grid)
8. [Personas Grid](#personas-grid)
9. [Stories Grid (As-a / I-want)](#stories-grid)
10. [Roadmap (timeline with dots)](#roadmap-timeline-with-dots)
11. [Architecture Layers](#architecture-layers)
12. [Mono Callout (spec excerpt)](#mono-callout-spec-excerpt)

**Other components**

13. [Cards](#cards)
14. [Layout Grids](#layout-grids)
15. [Tables](#tables)
16. [Stat Boxes](#stat-boxes)
17. [Badges](#badges)
18. [Quote Boxes](#quote-boxes)
19. [Callouts (legacy)](#callouts)
20. [Workflow Diagrams](#workflow-diagrams) *(deprecated for sequential timelines — prefer Roadmap)*
21. [Diagram Boxes](#diagram-boxes)
22. [Step Numbers](#step-numbers)
23. [Screenshots](#screenshots)
24. [Workflow Pipe](#workflow-pipe-compact-pipeline)
25. [Four-Column Layout](#four-column-layout)
26. [Compact Table](#compact-table)
27. [Skill Tags](#skill-tags)
28. [Pre/Code Blocks](#precode-blocks)
29. [Image-Flanked Layout](#image-flanked-layout)
30. [Layer Stack](#layer-stack)

---

## Body Region + Footer

Every **content slide** is `.body-region` (the content) + `.footer` (the navy bar) inside `<section class="slide content">`. The `content` class triggers the flex layout that pins the footer to the bottom and lets the body region distribute vertical space.

> **Why `.body-region` (flex) instead of `.frame` (absolute)?** The original skill design used `.frame { position: absolute; inset: 0 }`. That fights Reveal's slide positioning system — Reveal positions sections via `position: absolute` + transforms to bring the active slide into view, and absolute frames inside translate-positioned sections render unreliably. Flex layout works WITH Reveal instead of against it. See SKILL.md "Reveal compatibility gotchas".

### CSS

```css
/* The section uses display:flex !important — Reveal sets inline display:block
   on the active slide, which would otherwise win. */
.reveal .slides section.slide.content {
    display: flex !important;
    flex-direction: column;
    height: 100%;
    padding: 90px 100px 0 !important;
}
/* Footer reaches edge-to-edge by negating the section's horizontal padding. */
.reveal .slides section.slide.content > .footer {
    margin: auto -100px 0;
}

.body-region {
    flex: 1 1 auto;
    min-height: 0;
    display: flex;
    flex-direction: column;
    padding-bottom: 36px;
}

/* Trailing-element pin — see "Pinning trailing elements" below. */
.body-region > .stat-row:last-child,
.body-region > .quote-box:last-child,
.body-region > .callout:last-child,
.body-region > .callout.info:last-child,
.body-region > .callout.success:last-child,
.body-region > .workflow-pipe:last-child,
.body-region > .pin-bottom {
    margin-top: auto !important;
}

.footer {
    height: 56px;
    background: var(--ink); color: #fff;
    display: flex; align-items: center; justify-content: space-between;
    padding: 0 36px;
    font-size: var(--t-foot); letter-spacing: 0.02em;
}
.footer .f-left  { color: rgba(255,255,255,0.78); }
.footer .f-right { display: inline-flex; align-items: center; gap: 14px; color: rgba(255,255,255,0.88); }
.footer .tag      { color: rgba(255,255,255,0.7); font-size: 16px; letter-spacing: 0.14em; text-transform: uppercase; }
.footer .wordmark { display: inline-flex; align-items: center; padding: 5px 12px; background: #fff; color: var(--ink); font-weight: 700; letter-spacing: 0.04em; border-radius: 2px; font-size: 18px; }
.footer .wordmark em { font-style: normal; color: var(--accent); }
```

### HTML Pattern

```html
<section class="slide content">
    <div class="body-region">
        <div class="kicker">Section 02 &middot; Architecture</div>
        <h1 class="title">[Title here].</h1>
        <p class="body muted">[One-sentence frame.]</p>

        <!-- middle content here: .cols, .cap-grid, .roadmap, .arch, table, etc. -->

        <!-- Optional trailing element — auto-pins to bottom of body-region -->
        <div class="quote-box">"[Slide takeaway in plain language.]"</div>
    </div>
    <div class="footer">
        <span class="f-left">04 &middot; Architecture</span>
        <span class="f-right">
            <span class="tag">Field Services Platform</span>
            <span class="wordmark">HSO</span>
        </span>
    </div>
    <aside class="notes">Speaker notes.</aside>
</section>
```

### Pinning trailing elements

When a slide ends with a single summary element — a quote-box, callout, stat-row, or workflow-pipe — the CSS pins it to the bottom of `.body-region` automatically (via `margin-top: auto`). This puts content at the top and the takeaway at the bottom, with the gap between them carrying the visual weight rather than empty space below the takeaway.

Triggers automatically when the trailing element is the **last child** of `.body-region` and matches one of: `.stat-row`, `.quote-box`, `.callout`, `.callout.info`, `.callout.success`, `.workflow-pipe`. For arbitrary elements, add the `.pin-bottom` utility class.

### What NOT to do

- **Don't auto-stretch cards** to fill remaining space (`.card { flex: 1 1 auto }`). It produces giant empty tiles with tiny content inside. Cards stay content-height; tune visual weight via padding + font sizes (see [Cards](#cards)).
- **Don't override `position` on the section.** Reveal needs `position: absolute` for slide navigation. Setting `position: relative` knocks the active slide off-screen.
- **Don't drop the `content` class.** Without it the flex layout doesn't activate.

### Wordmark options

The wordmark is the small white pill at the right edge of the footer. Two patterns:

```html
<!-- Plain HSO -->
<span class="wordmark">HSO</span>

<!-- Brand-tag style with accent dot (e.g., i·Next, ad·Hoc, p·Lan) -->
<span class="wordmark">i<em>·</em>Next</span>
```

The `<em>` is styled to render the dot in `--accent` color and stays straight (not italic).

### Footer slot conventions

- **Left** — `NN · [Section name]`. NN is the slide number, padded to two digits. Section name matches the most recent divider.
- **Right tag** — the deck title in small-caps. Same on every slide of the deck.
- **Right wordmark** — the brand pill. Same on every slide.

---

## Kicker (eyebrow)

The small-caps accent label that sits above titles. One per slide max. Replaces the legacy `.eyebrow` class — `.eyebrow` still works but new decks should use `.kicker`.

### CSS

```css
.kicker {
    font-size: var(--t-kicker);
    font-weight: 700;
    color: var(--accent);
    letter-spacing: 0.12em;
    text-transform: uppercase;
    margin-bottom: 16px;
}
.kicker.coral  { color: var(--hso-salmon); }
.kicker.mimosa { color: var(--hso-mimosa); }
```

### HTML Pattern

```html
<div class="kicker">Section 02 · Architecture</div>
<h1 class="title">Property is the durable entity.</h1>
```

---

## Title Slide (split)

Editorial cover treatment: 50/50 split. Left half carries the title, subtitle, and author/date line. Right half is a hero photo with a dark gradient overlay so white text stays legible.

> **HSO logo placement gotcha:** `HSO Logo.png` is white-on-transparent. Place it on the **dark right column** (overlaid on the photo with a drop-shadow), NEVER on the white `.title-left` — it would render invisibly. The HTML pattern below shows the correct placement.

### CSS

```css
/* GOTCHA: !important on display:grid is required because Reveal sets inline
   style="display: block" on the active slide, which would otherwise win. */
.reveal .slides section.slide.title-slide {
    display: grid !important;
    grid-template-columns: 1fr 1fr;
    height: 100%;
}
.title-left  { position: relative; padding: 72px 80px; display: flex; flex-direction: column; }
.title-left::before { content: ""; position: absolute; left: 0; top: 120px; bottom: 120px; width: 7px; background: var(--accent); }
.title-left .block { margin: auto 0; }
.title-left h1   { font-size: var(--t-hero); font-weight: 400; letter-spacing: -0.02em; color: var(--ink); line-height: 1.02; margin: 0 0 24px; }
.title-left .sub { font-size: var(--t-subtitle); color: var(--accent); font-weight: 400; line-height: 1.25; max-width: 700px; }
.title-left .foot { color: var(--muted); font-size: 22px; margin-top: 24px; }
.title-left .foot .who { color: var(--ink); font-weight: 500; }
.title-right { position: relative; background: var(--ink); overflow: hidden; }
.title-right .hero-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.title-right::after {
    content: ""; position: absolute; inset: 0;
    background: linear-gradient(180deg, rgba(0,57,95,0) 55%, rgba(0,57,95,0.55) 100%),
                linear-gradient(90deg, rgba(0,57,95,0.45) 0%, rgba(0,57,95,0) 35%);
    pointer-events: none;
}
/* HSO logo overlay — goes on the DARK right side, never on the white left. */
.title-right .logo-overlay { position: absolute; top: 50px; left: 50px; z-index: 2; }
.title-right .logo-overlay img { height: 48px; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.4)); }
```

### HTML Pattern

```html
<section class="slide title-slide">
    <div class="title-left">
        <div class="block">
            <h1>Field services, rebuilt for property.</h1>
            <div class="sub">A platform that anchors history to the home &mdash; not the homeowner.</div>
        </div>
        <div class="foot">
            <span class="who">Ivan Kurtev</span> &middot; ikurtev@hso.com &middot; Architecture brief &middot; 2026
        </div>
    </div>
    <div class="title-right">
        <img class="hero-img" src="cover.jpg" alt="Service technician at a home">
        <!-- HSO logo overlay sits on the dark photo, NOT on the white left side -->
        <div class="logo-overlay">
            <img src="../Graphics/HSO Logo.png" alt="HSO">
        </div>
    </div>
    <aside class="notes">Cover.</aside>
</section>
```

---

## Section Dividers

Solid-color background with a kicker label and a large title. Use between major sections. Variants: default ink (navy), `.coral`, `.sand`, `.teal`. No footer.

### CSS

```css
.reveal .slides section.slide.divider { background: var(--ink); color: #fff; height: 100%; }
.reveal .slides section.slide.divider .div-inner {
    display: flex; flex-direction: column; justify-content: center;
    height: 100%; padding: 0 100px;
}
.reveal .slides section.slide.divider .kicker.section {
    color: var(--accent-2); letter-spacing: 0.12em; text-transform: uppercase;
    font-size: var(--t-kicker); font-weight: 700; margin-bottom: 18px;
}
.reveal .slides section.slide.divider h1 {
    font-size: var(--t-hero); color: #fff; margin: 0 0 16px;
    font-weight: 400; letter-spacing: -0.02em;
}
.reveal .slides section.slide.divider .sub {
    font-size: var(--t-subtitle); color: rgba(255,255,255,0.85);
    font-weight: 400; line-height: 1.25; max-width: 1500px;
}

/* Color variants */
.reveal .slides section.slide.divider.teal  { background: var(--accent); }
.reveal .slides section.slide.divider.teal  .kicker.section,
.reveal .slides section.slide.divider.teal  .sub { color: var(--ink); opacity: 0.85; }
.reveal .slides section.slide.divider.coral { background: var(--hso-salmon); }
.reveal .slides section.slide.divider.sand  { background: var(--hso-mimosa-edge); }
.reveal .slides section.slide.divider.sand  h1 { color: var(--ink); }
.reveal .slides section.slide.divider.sand  .kicker.section,
.reveal .slides section.slide.divider.sand  .sub { color: var(--ink); opacity: 0.7; }
```

### HTML Pattern

```html
<section class="slide divider">
    <div class="div-inner">
        <div class="kicker section">Section 02</div>
        <h1>Capabilities.</h1>
        <div class="sub">What the platform does &mdash; surface by surface.</div>
    </div>
</section>
```

### When to use which color

| Variant | When |
|---|---|
| (default ink) | Most sections — neutral, professional |
| `.teal` | New-capability section, "what's new" |
| `.coral` | Risk, problem, "what's broken" framing |
| `.sand` | Caution, decision points, "could have" priorities |

---

## Stat Slide

A single huge number on a teal background. For emphasis moments — "one platform", "99.9%", "4 weeks". Use **1–2 per deck** maximum; more and the device loses force.

### CSS

```css
.reveal .slides section.slide.stat { background: var(--accent); color: #fff; height: 100%; }
.reveal .slides section.slide.stat .div-inner {
    display: flex; flex-direction: column; justify-content: center;
    height: 100%; padding: 0 100px;
}
.reveal .slides section.slide.stat .big  { font-size: 260px; line-height: 1; font-weight: 300; letter-spacing: -0.04em; color: #fff; margin-bottom: 24px; }
.reveal .slides section.slide.stat .cap  { font-size: var(--t-subtitle); color: var(--ink); opacity: 0.9; max-width: 1100px; font-weight: 400; line-height: 1.25; }
.reveal .slides section.slide.stat .note { font-size: var(--t-body); color: var(--ink); opacity: 0.6; font-style: italic; margin-top: 12px; }
```

### HTML Pattern

```html
<section class="slide stat">
    <div class="div-inner">
        <div class="big">1</div>
        <div class="cap">one platform for every customer, every practice &mdash; with AI doing the repetitive work humans shouldn't.</div>
        <div class="note">measured by login count, not seat license</div>
    </div>
</section>
```

---

## Closing Slide

Light background, large title, sub-line, optional 3-column "asks" grid, contact line. No footer.

### CSS

```css
.reveal .slides section.slide.closing { background: var(--paper); height: 100%; }
.reveal .slides section.slide.closing .div-inner {
    display: flex; flex-direction: column; justify-content: center;
    height: 100%; padding: 0 100px;
}
.reveal .slides section.slide.closing h1   { font-size: var(--t-hero); font-weight: 400; color: var(--ink); letter-spacing: -0.02em; margin: 0 0 24px; max-width: 1500px; line-height: 1.05; }
.reveal .slides section.slide.closing .sub { font-size: var(--t-subtitle); color: var(--accent); margin-bottom: 50px; max-width: 1200px; line-height: 1.25; }
.reveal .slides section.slide.closing .asks { display: grid; grid-template-columns: repeat(3,1fr); gap: 50px; max-width: 1500px; }
.reveal .slides section.slide.closing .asks .ask-n { font-family: 'Consolas','SF Mono',monospace; font-size: 18px; color: var(--accent); letter-spacing: 0.1em; margin-bottom: 10px; }
.reveal .slides section.slide.closing .asks .ask-t { font-size: 26px; font-weight: 500; color: var(--ink); line-height: 1.3; }
.reveal .slides section.slide.closing .contact { margin-top: 40px; font-size: 22px; color: var(--muted); }
.reveal .slides section.slide.closing .contact strong { color: var(--ink); font-weight: 500; }
```

### HTML Pattern

```html
<section class="slide closing">
    <div class="div-inner">
        <h1>Where we go from here.</h1>
        <div class="sub">Three things we'd like back from this room before next Friday.</div>
        <div class="asks">
            <div><div class="ask-n">01</div><div class="ask-t">Confirm the property-anchored model.</div></div>
            <div><div class="ask-n">02</div><div class="ask-t">Name the three pilot brands.</div></div>
            <div><div class="ask-n">03</div><div class="ask-t">Approve the 6-week discovery slot.</div></div>
        </div>
        <div class="contact"><strong>Ivan Kurtev</strong> &middot; ikurtev@hso.com</div>
    </div>
</section>
```

---

## Capability Map (numbered grid)

A 4-column grid of capability cards. Each card has a monospace numbered tag (`01 · CORE`), a name, and a one-line description. Use to land "here are all the capabilities at a glance" without forcing the reader to count bullets.

### CSS

```css
.cap-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin-top: 8px; }
.cap-grid .cell { border: 1px solid var(--line); background: var(--paper); padding: 22px 24px 24px; display: flex; flex-direction: column; min-height: 180px; }
.cap-grid .cell .num { font-family: 'Consolas','SF Mono',monospace; color: var(--accent); font-size: 18px; letter-spacing: 0.1em; margin-bottom: 12px; }
.cap-grid .cell .cap-name { font-size: 28px; font-weight: 500; color: var(--ink); letter-spacing: -0.01em; line-height: 1.15; margin-bottom: 10px; }
.cap-grid .cell .cap-desc { font-size: 19px; color: var(--muted); line-height: 1.35; margin-top: auto; }
```

### HTML Pattern

```html
<div class="cap-grid">
    <div class="cell"><div class="num">01 · CORE</div><div class="cap-name">Incident Management</div><div class="cap-desc">Log, classify, prioritize, assign, resolve — with AI triage and SLA tracking.</div></div>
    <div class="cell"><div class="num">02 · CORE</div><div class="cap-name">Service Request Management</div><div class="cap-desc">Catalog-driven requests with approvals and SLA-aware fulfillment.</div></div>
    <!-- ...up to 16 cells (4×4) — beyond that, split across two slides -->
</div>
```

### When to use

- "Here is the entire capability set" overview slide
- After a section divider that introduced a domain
- Pairs naturally with a follow-up content slide that drills into one capability per kicker

---

## Personas Grid

4-column grid of persona cards with role / "who" / quote / pain. Use exactly once per deck — when introducing the audience the platform serves.

### CSS

```css
.personas { display: grid; grid-template-columns: repeat(4,1fr); gap: 40px; margin-top: 8px; }
.persona .p-role { font-size: 26px; font-weight: 500; color: var(--ink); margin-bottom: 8px; letter-spacing: -0.005em; }
.persona .p-who  { font-family: 'Consolas','SF Mono',monospace; font-size: 17px; color: var(--accent); letter-spacing: 0.06em; text-transform: uppercase; margin-bottom: 18px; }
.persona .p-job  { font-size: 21px; color: var(--ink); line-height: 1.4; margin-bottom: 16px; }
.persona .p-pain { font-size: 19px; color: var(--muted); line-height: 1.4; border-top: 1px solid var(--line); padding-top: 16px; }
.persona .p-pain strong { color: var(--ink); font-weight: 500; }
```

### HTML Pattern

```html
<div class="personas">
    <div class="persona">
        <div class="p-role">Service Desk Agent</div>
        <div class="p-who">Front line</div>
        <div class="p-job">"Give me a pre-triaged queue and a copilot in every ticket."</div>
        <div class="p-pain"><strong>Today:</strong> swivel-chairs between tools and loses context on every switch.</div>
    </div>
    <!-- ...up to 4 personas. More than 4 means the deck is trying to land too many audiences. -->
</div>
```

---

## Stories Grid

A grid of "As a [persona], I want to [verb]" entries. Use to back a capability with concrete user stories — typically right after the capability is introduced.

### CSS

```css
.stories { display: grid; grid-template-columns: 1fr 1fr; gap: 28px 80px; margin-top: 4px; }
.story { border-left: 4px solid var(--line); padding: 2px 0 2px 20px; }
.story .who  { font-family: 'Consolas','SF Mono',monospace; font-size: 16px; color: var(--accent); letter-spacing: 0.08em; text-transform: uppercase; margin-bottom: 6px; }
.story .want { font-size: 22px; color: var(--ink); line-height: 1.35; }
.story .want em { font-style: normal; color: var(--muted); }
```

### HTML Pattern

```html
<div class="stories">
    <div class="story"><div class="who">Service Desk Agent</div><div class="want">See my queue sorted by priority and SLA remaining.</div></div>
    <div class="story"><div class="who">Incident Manager</div><div class="want">Declare a major incident and assemble a response team <em>in under a minute</em>.</div></div>
    <div class="story"><div class="who">Requester</div><div class="want">Get suggested known solutions before submitting.</div></div>
    <!-- 6–12 stories work well; more wraps the page badly -->
</div>
```

---

## Roadmap (timeline with dots)

A horizontal timeline of phases with state dots — `done` (filled ink), `current` (filled accent), `future` (outlined). **Replaces `.workflow` for sequential timelines** because dots never break and never wrap. Use `.workflow` only for true process flows where each step has parallel inputs/outputs.

### CSS

```css
.roadmap { margin-top: 20px; display: grid; grid-template-columns: repeat(4, 1fr); gap: 0; position: relative; }
.roadmap::before { content: ""; position: absolute; left: 0; right: 0; top: 24px; height: 2px; background: var(--line); }
.roadmap .phase { position: relative; padding: 0 20px 0 0; }
.roadmap .phase .dot { width: 18px; height: 18px; border-radius: 999px; background: var(--accent); margin-top: 14px; box-shadow: 0 0 0 6px #fff; }
.roadmap .phase.done   .dot { background: var(--ink); }
.roadmap .phase.future .dot { background: var(--paper); border: 2px solid var(--line); }
.roadmap .phase .q       { margin-top: 26px; font-family: 'Consolas','SF Mono',monospace; font-size: 18px; color: var(--accent); letter-spacing: 0.08em; text-transform: uppercase; }
.roadmap .phase .p-title { font-size: 26px; color: var(--ink); font-weight: 500; margin-top: 6px; letter-spacing: -0.005em; }
.roadmap .phase ul       { list-style: none; padding: 0; margin: 14px 0 0; font-size: 18px; color: var(--muted); line-height: 1.5; }
.roadmap .phase ul li    { margin-bottom: 8px; }
```

### HTML Pattern

```html
<div class="roadmap">
    <div class="phase done">
        <div class="dot"></div>
        <div class="q">Q4 2025</div>
        <div class="p-title">Discovery</div>
        <ul><li>Stakeholder interviews</li><li>Data inventory</li></ul>
    </div>
    <div class="phase">
        <div class="dot"></div>
        <div class="q">Q1 2026</div>
        <div class="p-title">Foundations</div>
        <ul><li>Property entity model</li><li>Auth + tenancy</li></ul>
    </div>
    <div class="phase future">
        <div class="dot"></div>
        <div class="q">Q2 2026</div>
        <div class="p-title">Pilot</div>
        <ul><li>Three brands</li><li>End-to-end ticket flow</li></ul>
    </div>
    <div class="phase future">
        <div class="dot"></div>
        <div class="q">Q3 2026</div>
        <div class="p-title">Rollout</div>
        <ul><li>Remaining brands</li><li>Reporting</li></ul>
    </div>
</div>
```

### Guidelines

- 3–5 phases work best. Beyond that the dots crowd.
- Adjust `grid-template-columns: repeat(N, 1fr)` to match phase count.
- For a 6+ phase plan, split across two roadmap slides instead of cramming.

---

## Architecture Layers

Stacked rows showing system layers (UI / API / data / etc.) with a name on the left and a monospace item list on the right. Modifiers `.accent` (light teal tint) and `.dark` (ink background) call out specific layers.

### CSS

```css
.arch { display: grid; grid-template-columns: 1fr; gap: 12px; margin-top: 4px; }
.arch .layer { border: 1px solid var(--line); padding: 16px 24px; display: grid; grid-template-columns: 260px 1fr; align-items: center; gap: 24px; background: var(--paper); }
.arch .layer.accent { background: rgba(7,159,195,0.06); border-color: rgba(7,159,195,0.35); }
.arch .layer.dark   { background: var(--ink); color: #fff; border-color: var(--ink); }
.arch .layer.dark .l-name  { color: #fff; }
.arch .layer.dark .l-items { color: rgba(255,255,255,0.72); }
.arch .l-name  { font-size: 22px; font-weight: 500; color: var(--ink); letter-spacing: -0.005em; }
.arch .l-name .tag { display: inline-block; margin-left: 10px; font-family: 'Consolas','SF Mono',monospace; font-size: 13px; color: var(--muted); letter-spacing: 0.08em; text-transform: uppercase; }
.arch .l-items { font-family: 'Consolas','SF Mono',monospace; font-size: 17px; color: var(--ink-2); letter-spacing: 0.01em; line-height: 1.5; }
```

### HTML Pattern

```html
<div class="arch">
    <div class="layer">
        <div class="l-name">Experience <span class="tag">UI</span></div>
        <div class="l-items">Reveal.js · React · Power Apps · MAUI</div>
    </div>
    <div class="layer accent">
        <div class="l-name">Application <span class="tag">API</span></div>
        <div class="l-items">Custom APIs · Custom connectors · Plugins · Power Automate</div>
    </div>
    <div class="layer">
        <div class="l-name">Domain <span class="tag">MODEL</span></div>
        <div class="l-items">Tables · Relationships · Business rules · Calculated fields</div>
    </div>
    <div class="layer dark">
        <div class="l-name">Platform <span class="tag">PLATFORM</span></div>
        <div class="l-items">Dataverse · Azure AD · Microsoft Graph</div>
    </div>
</div>
```

### When to use vs `.layer-stack`

| Scenario | Use |
|---|---|
| Editorial / branded archi slide with descriptive items | `.arch` (this) — name left, items right |
| Quick architecture summary with colored bands | `.layer-stack` — single line per band |

---

## Mono Callout (spec excerpt)

A monospace block with an accent left-bar, used to embed a short "spec excerpt" in body text — auth flows, intent matches, JSON shapes. Different from `.callout.info` (the colored advisory boxes lower in this doc) which is for prose tips.

### CSS

```css
.callout-mono {
    background: var(--code-bg); border-left: 6px solid var(--accent);
    padding: 28px 32px; border-radius: 2px;
    font-family: 'Consolas','SF Mono',monospace; font-size: 21px; color: var(--ink);
    line-height: 1.5; white-space: pre; overflow: hidden;
}
.callout-mono .c { color: var(--accent); }              /* comment */
.callout-mono .k { color: var(--ink); font-weight: 700; } /* key */
.callout-mono .v { color: var(--ink-2); }                /* value */
.callout-mono .m { color: var(--muted); }                /* muted/aside */
```

### HTML Pattern

```html
<div class="callout-mono"><span class="c"># semantic deflection</span>
<span class="k">intent:</span>    <span class="v">"my laptop won't join VPN after reboot"</span>
<span class="k">matches:</span>   <span class="v">3 known errors · 2 closed incidents</span>
<span class="k">action:</span>    <span class="v">serve KB-0412 · offer self-fix</span>
<span class="k">fallback:</span>  <span class="v">draft incident, pre-filled, one click</span></div>
```

### Notes

- `white-space: pre` preserves indentation — write the HTML literally as it should render.
- Use sparingly; one mono callout per slide max. If the slide needs two, the slide is overloaded.

---

## Title Slide

### CSS

```css
.title-slide { text-align: center; }
.title-slide h1 { font-size: 2.2em; color: var(--hso-navy); margin-bottom: 0.2em; }
.title-slide .subtitle { font-size: 1.1em; color: var(--hso-blue); margin-bottom: 1em; }
.title-slide .meta { font-size: 0.8em; color: var(--text-muted); }
```

### HTML Pattern

```html
<section class="title-slide">
    <div style="margin-bottom:1em;">
        <span style="font-size:0.7em;color:var(--hso-steel);letter-spacing:2px;text-transform:uppercase;">[Context Line]</span>
    </div>
    <h1>[Main Title]</h1>
    <h1 style="font-size:1.4em;color:var(--hso-blue);margin-top:0;">[Subtitle]</h1>
    <div class="meta" style="margin-top:1.5em;">
        <p style="font-size:0.85em;color:var(--text-muted);">HSO | [Date]</p>
    </div>
    <aside class="notes">Speaker notes here.</aside>
</section>
```

---

## Section Dividers

> **The current editorial baseline uses `<section class="slide divider">` ([see above](#section-dividers)).** The legacy `.section-divider` pattern below still works for older decks but new decks should use `.slide.divider` so they pick up the editorial sizing and color variants (`.coral`, `.sand`, `.teal`).

Use between major sections. Navy background with white text.

### CSS (legacy)

```css
.section-divider { 
    background: var(--hso-navy) !important; 
    color: #fff !important; 
    text-align: center; 
}
.section-divider h2 { 
    color: #fff !important; 
    font-size: 2em; 
    margin-bottom: 0.2em; 
}
.section-divider .session-label { 
    font-size: 0.7em; 
    text-transform: uppercase; 
    letter-spacing: 3px; 
    color: var(--hso-blue); 
    margin-bottom: 0.5em; 
}
.section-divider .session-desc { 
    font-size: 0.85em; 
    color: var(--hso-steel); 
    margin-top: 0.5em; 
}
```

### HTML Pattern (legacy)

```html
<section class="section-divider">
    <div class="session-label">Part 1</div>
    <h2>[Section Title]</h2>
    <div class="session-desc">[Brief description]</div>
    <aside class="notes">Speaker notes here.</aside>
</section>
```

---

## Cards

Content containers with subtle background and accent border. Cards stay content-height — DO NOT auto-stretch with `flex: 1 1 auto` (creates giant empty tiles with tiny content inside). To make cards more substantial, increase padding and font sizes (see below) so the card grows naturally with its content.

### CSS

```css
/* Sizes calibrated for 1920×1080 presentation legibility against bumped
   tables (26px) and headings. Don't shrink without re-verifying. */
.card {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 38px 42px;
}
.card h4 {
    color: var(--ink);
    font-size: 34px;
    font-weight: 600;
    margin: 0 0 16px;
    line-height: 1.2;
}
.card p, .card li {
    font-size: 27px;
    line-height: 1.5;
    color: var(--ink);
    margin: 0;
}
.card ul { list-style: none; padding: 0; margin: 14px 0 0; }
.card ul li {
    position: relative;
    padding-left: 28px;
    margin: 12px 0;
    font-size: 25px;
    line-height: 1.45;
}
.card ul li::before {
    content: "";
    position: absolute;
    left: 0; top: 0.6em;
    width: 9px; height: 9px;
    background: var(--accent);
    border-radius: 999px;
}
```

### HTML Pattern

```html
<div class="card">
    <h4>[Card Title]</h4>
    <p>[Card content or description]</p>
    <ul>
        <li>List item</li>
    </ul>
</div>
```

### Card with Accent Border

```html
<div class="card" style="border-left:4px solid var(--hso-teal);">
    <h4 style="color:var(--hso-teal);">[Success Card]</h4>
    <ul>
        <li>Content here</li>
    </ul>
</div>
```

### Card with Top Border Accent

```html
<div class="card" style="border-top:3px solid var(--hso-blue);">
    <h4 style="color:var(--hso-blue);">[Blue Accent Card]</h4>
    <p>Content here</p>
</div>
```

---

## Layout Grids

### Card Grid (2 or 3 columns)

```css
.card-grid { display: grid; gap: 0.8em; }
.card-grid.cols-2 { grid-template-columns: 1fr 1fr; }
.card-grid.cols-3 { grid-template-columns: 1fr 1fr 1fr; }
```

```html
<div class="card-grid cols-3">
    <div class="card"><h4>Card 1</h4><p>Content</p></div>
    <div class="card"><h4>Card 2</h4><p>Content</p></div>
    <div class="card"><h4>Card 3</h4><p>Content</p></div>
</div>
```

### Two Column Layout

```css
.two-col { 
    display: grid; 
    grid-template-columns: 1fr 1fr; 
    gap: 1.5em; 
    text-align: left; 
}
```

```html
<div class="two-col">
    <div>
        <h3>Left Column</h3>
        <ul><li>Content</li></ul>
    </div>
    <div>
        <h3>Right Column</h3>
        <ul><li>Content</li></ul>
    </div>
</div>
```

### Three Column Layout

```css
.three-col { 
    display: grid; 
    grid-template-columns: 1fr 1fr 1fr; 
    gap: 1em; 
    text-align: left; 
}
```

---

## Tables

### CSS

```css
/* Tables match card body (27px) so they don't read as "less important" than
   neighboring cards. Use absolute pixels — calibrated for 1920×1080. */
.reveal table {
    width: 100%;
    border-collapse: collapse;
    font-size: 26px;
    margin: 10px 0;
}
.reveal table th {
    background: var(--ink);
    color: #fff;
    padding: 14px 20px;
    text-align: left;
    font-weight: 600;
    font-size: 20px;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}
.reveal table td {
    padding: 14px 20px;
    border-bottom: 1px solid var(--line);
    color: var(--ink);
}
.reveal table tr:nth-child(even) td {
    background: var(--card-bg);
}

/* compact-table — when a slide has 6+ rows or sits next to dense content */
.reveal table.compact-table { font-size: 23px; }
.reveal table.compact-table th, .reveal table.compact-table td { padding: 10px 14px; }
```

### HTML Pattern

```html
<table>
    <thead>
        <tr><th>Column 1</th><th>Column 2</th><th>Column 3</th></tr>
    </thead>
    <tbody>
        <tr><td>Data</td><td>Data</td><td>Data</td></tr>
        <tr><td>Data</td><td>Data</td><td>Data</td></tr>
    </tbody>
</table>
```

### Comparison Table Styling

```css
.comparison-table td:first-child { font-weight: 600; background: var(--card-bg); }
.comparison-table td.pro { color: var(--hso-teal); }
.comparison-table td.con { color: var(--hso-coral); }
```

---

## Stat Boxes

Display key metrics prominently.

### CSS

```css
.stat-row { 
    display: flex; 
    justify-content: center; 
    gap: 1.5em; 
    margin: 0.8em 0; 
}
.stat-box { text-align: center; }
.stat-box .stat-num { 
    font-size: 1.8em; 
    font-weight: 700; 
    color: var(--hso-blue); 
    line-height: 1; 
}
.stat-box .stat-label { 
    font-size: 0.6em; 
    color: var(--text-muted); 
    text-transform: uppercase; 
    letter-spacing: 1px; 
}
```

### HTML Pattern

```html
<div class="stat-row">
    <div class="stat-box">
        <div class="stat-num">42</div>
        <div class="stat-label">Metric Name</div>
    </div>
    <div class="stat-box">
        <div class="stat-num">$1.2M</div>
        <div class="stat-label">Revenue</div>
    </div>
</div>
```

---

## Badges

Small labels for categorization.

### CSS

```css
.badge { 
    display: inline-block; 
    padding: 0.15em 0.6em; 
    border-radius: 20px; 
    font-size: 0.6em; 
    font-weight: 600; 
    margin: 0.1em; 
}
.badge-blue { background: #E1F5FE; color: #0277BD; }
.badge-green { background: #E8F5E9; color: #2E7D32; }
.badge-amber { background: #FFF8E1; color: #F57F17; }
.badge-red { background: #FFEBEE; color: #C62828; }
```

### HTML Pattern

```html
<span class="badge badge-green">Must Have</span>
<span class="badge badge-blue">Should Have</span>
<span class="badge badge-amber">Could Have</span>
<span class="badge badge-red">Won't Have</span>
```

---

## Quote Boxes

Styled blockquotes for testimonials or key statements.

### CSS

```css
.quote-box { 
    border-left: 4px solid var(--hso-blue); 
    background: linear-gradient(135deg, #F7FAFC, #EDF2F7); 
    padding: 0.7em 1em; 
    border-radius: 0 8px 8px 0; 
    margin: 0.6em 0; 
    font-style: italic; 
    font-size: 0.7em; 
    color: var(--text); 
    text-align: left; 
}
```

### HTML Pattern

```html
<div class="quote-box">
    "Quote text here with emphasis on key message."
</div>
```

---

## Callouts

> **Two kinds of callout exist.** This section covers the colored advisory boxes (info / warn / tip) for prose. For monospace spec excerpts (intent matches, JSON shapes, auth flow stubs) use [Mono Callout](#mono-callout-spec-excerpt) instead.

Highlighted information boxes.

### CSS

```css
.callout { 
    background: #FFF8E1; 
    border-left: 4px solid var(--hso-amber); 
    border-radius: 0 8px 8px 0; 
    padding: 0.6em 0.8em; 
    font-size: 0.7em; 
    margin: 0.4em 0; 
    text-align: left; 
}
.callout.important { 
    background: #FFEBEE; 
    border-left-color: var(--hso-coral); 
}
.callout.info { 
    background: #E1F5FE; 
    border-left-color: var(--hso-blue); 
}
```

### HTML Patterns

```html
<!-- Default (amber) - general notes -->
<div class="callout">
    <strong>Note:</strong> Important information here.
</div>

<!-- Important (coral) - warnings -->
<div class="callout important">
    <strong>Important:</strong> Critical warning message.
</div>

<!-- Info (blue) - tips -->
<div class="callout info">
    <strong>Tip:</strong> Helpful information.
</div>
```

---

## Workflow Diagrams

> **For sequential timelines (phases, releases, quarters), prefer [Roadmap](#roadmap-timeline-with-dots).** The roadmap's dots-on-a-line layout reads more cleanly at editorial sizes and never wraps. Reach for `.workflow` only when each step has parallel inputs/outputs that need to be drawn as boxes — i.e. an actual process diagram.

Process flow visualizations. **MUST fit on a single row** — wrapped workflows
look broken and fail the layout audit.

### CSS (one-row, equal-width nodes, text wraps inside nodes)

```css
.workflow {
    display: flex;
    align-items: stretch;
    justify-content: center;
    gap: 0;
    flex-wrap: nowrap;        /* CRITICAL — do not change to wrap */
    margin: 1em 0;
    width: 100%;
}
.workflow .node {
    background: var(--card-bg);
    border: 2px solid var(--hso-blue);
    border-radius: 10px;
    padding: 0.55em 0.7em;
    font-size: 0.68em;
    font-weight: 600;
    color: var(--hso-navy);
    white-space: normal;      /* let long labels wrap inside the node */
    text-align: center;
    min-width: 0;             /* allow flex shrink */
    flex: 1 1 0;              /* equal widths, distribute slide width */
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1.25;
}
.workflow .node.active { background: var(--hso-blue); color: #fff; }
.workflow .node.end-won { background: var(--hso-teal); border-color: var(--hso-teal); color: #fff; }
.workflow .node.end-lost { background: var(--hso-coral); border-color: var(--hso-coral); color: #fff; }
.workflow .arrow {
    font-size: 1em;
    color: var(--hso-steel);
    padding: 0 0.25em;
    flex: 0 0 auto;           /* arrows don't shrink */
    display: flex;
    align-items: center;
}
```

### Guidelines

- **Max 6 nodes per workflow.** Beyond that the per-node width gets too narrow.
  If you have more than 6 steps, split the flow or collapse sub-steps.
- **Short labels first.** Each node is a verb phrase or noun phrase, not a
  sentence. If you need a qualifier, put it on a second line with `<br>` or
  let the node wrap naturally.
- **No inline `white-space: nowrap`** on `.workflow .node` — it defeats the
  wrapping-inside-node design that keeps the flow on one row.

### HTML Pattern

```html
<div class="workflow">
    <div class="node">Step 1</div>
    <div class="arrow">&#x27A1;</div>
    <div class="node active">Step 2 (Current)</div>
    <div class="arrow">&#x27A1;</div>
    <div class="node">Step 3</div>
    <div class="arrow">&#x27A1;</div>
    <div class="node end-won">Success</div>
</div>
```

### Workflow with Subtext

```html
<div class="workflow">
    <div class="node">Initiate<br><small>Create opportunity</small></div>
    <div class="arrow">&#x27A1;</div>
    <div class="node">Develop<br><small>Research & engage</small></div>
</div>
```

---

## Diagram Boxes

Simple containers for diagrams.

### CSS

```css
.diagram-box { 
    background: var(--card-bg); 
    border: 2px solid var(--border); 
    border-radius: 10px; 
    padding: 0.6em 1em; 
    text-align: center; 
    font-size: 0.78em; 
}
.diagram-box.highlight { 
    border-color: var(--hso-blue); 
    background: #E1F5FE; 
}
.diagram-box.accent { 
    border-color: var(--hso-mimosa); 
    background: #FFF8E1; 
}
```

### HTML Pattern

```html
<div class="diagram-box highlight">
    <strong>Highlighted Box</strong><br>
    <small>Description text</small>
</div>
```

---

## Step Numbers

Numbered steps for procedures.

### CSS

```css
.step-num { 
    display: inline-flex; 
    align-items: center; 
    justify-content: center; 
    width: 1.6em; 
    height: 1.6em; 
    border-radius: 50%; 
    background: var(--hso-blue); 
    color: #fff; 
    font-weight: 700; 
    font-size: 0.85em; 
    margin-right: 0.4em; 
    flex-shrink: 0; 
}
```

### HTML Pattern

```html
<ul>
    <li><span class="step-num">1</span> First step description</li>
    <li><span class="step-num">2</span> Second step description</li>
    <li><span class="step-num">3</span> Third step description</li>
</ul>
```

---

## Screenshots

Placeholder and styling for images.

### CSS

```css
.screenshot-placeholder { 
    background: #f0f4f8; 
    border: 2px dashed var(--hso-steel); 
    border-radius: 8px; 
    padding: 2em; 
    text-align: center; 
    color: var(--text-muted); 
    font-size: 0.78em; 
}
.tango-screenshot { 
    border-radius: 8px; 
    max-width: 100%; 
    max-height: 420px; 
    object-fit: contain; 
    box-shadow: 0 2px 12px rgba(0,0,0,0.12); 
}
.tango-screenshot-tall { 
    border-radius: 8px; 
    max-width: 100%; 
    max-height: 520px; 
    object-fit: contain; 
    box-shadow: 0 2px 12px rgba(0,0,0,0.12); 
}
```

### HTML Patterns

```html
<!-- Placeholder for missing screenshot -->
<div class="screenshot-placeholder">
    [Screenshot: Description of what should appear here]
</div>

<!-- Actual screenshot -->
<img class="tango-screenshot" src="[URL]" alt="[Description]" />
```

---

## Workflow Pipe (Compact Pipeline)

A more compact flow component than the standard workflow. Best for pipeline/process flows with simple labels.

### CSS

```css
.workflow-pipe {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 0.15em;
    flex-wrap: wrap;
    margin: 0.4em 0;
}
.workflow-pipe .pipe-node {
    background: #ebf8ff;
    border: 1px solid var(--hso-blue);
    border-radius: 4px;
    padding: 0.3em 0.6em;
    font-size: 0.68em;
    font-weight: 600;
    color: var(--hso-navy);
    white-space: nowrap;
}
.workflow-pipe .pipe-arrow {
    color: var(--hso-blue);
    font-size: 0.9em;
    font-weight: bold;
}
```

### HTML Pattern

```html
<div class="workflow-pipe">
    <div class="pipe-node">Step 1</div>
    <div class="pipe-arrow">&#x27A1;</div>
    <div class="pipe-node">Step 2</div>
    <div class="pipe-arrow">&#x27A1;</div>
    <div class="pipe-node" style="background:var(--hso-teal);color:#fff;border-color:var(--hso-teal);">Done</div>
</div>
```

### When to Use

- Compact pipeline/deployment flows (Export → Build → Deploy → Production)
- Iterative loops (Create → Import → Trigger → Evaluate)
- Use colored overrides on pipe-node for start/end states

---

## Four-Column Layout

### CSS

```css
.four-col {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr 1fr;
    gap: 0.6em;
    text-align: left;
}
```

### HTML Pattern

```html
<div class="four-col">
    <div class="card"><h4>Card 1</h4><p>Content</p></div>
    <div class="card"><h4>Card 2</h4><p>Content</p></div>
    <div class="card"><h4>Card 3</h4><p>Content</p></div>
    <div class="card"><h4>Card 4</h4><p>Content</p></div>
</div>
```

---

## Density Classes

Three size variants for tables and card grids, chosen based on how much content
the slide needs to hold. The layout audit (see SKILL.md) tells you when to
reach for these.

### Tables

```css
/* default .reveal table — use for medium-density (4–8 rows) */
.reveal table { font-size: 0.7em; }
.reveal table th,.reveal table td { padding: 0.4em 0.6em; }

/* compact-table — 9+ rows, or tight slides with other content */
.reveal table.compact-table { font-size: 0.66em; }
.reveal table.compact-table th,.reveal table.compact-table td { padding: 0.3em 0.5em; }

/* lg-table — sparse 3–5 row tables that look under-filled at default size */
.reveal table.lg-table { font-size: 0.82em; }
.reveal table.lg-table th,.reveal table.lg-table td { padding: 0.55em 0.75em; }
```

Decision rule:

| Row count | Class | Notes |
|---|---|---|
| ≤ 5 | `lg-table` | Give the sparse table some weight |
| 6–8 | (default) | Plain `<table>` is sized for this case |
| 9+ | `compact-table` | Shrink rows to fit 10–12 rows comfortably |

### Card Grids

```css
/* default .card — 2–6 cards with normal descriptions */
/* (.card defined earlier in this document) */

/* dense — 8-card grids, 2 rows × 4 cols */
.card-grid.dense .card { padding: 0.65em 0.85em; }
.card-grid.dense .card h4 { font-size: 0.85em; margin-bottom: 0.22em; }
.card-grid.dense .card p { font-size: 0.7em; line-height: 1.35; }

/* compact — 4-card grids with extra content below (callout, etc.) */
.card-grid.compact .card { padding: 0.55em 0.8em; }
.card-grid.compact .card h4 { font-size: 0.82em; margin-bottom: 0.2em; }
.card-grid.compact .card p,.card-grid.compact .card li { font-size: 0.68em; line-height: 1.3; }

/* cols-4 utility — 4-column grid for dense 8-card layouts */
.card-grid.cols-4 { grid-template-columns: repeat(4,1fr); }
```

Decision rule:

| Layout | Class combination | When |
|---|---|---|
| 8 cards, 2 rows | `card-grid cols-4 dense` | Agenda slides, capability grids |
| 4 cards + callout | `card-grid cols-2 compact` | Comparison cards that must share the slide with supporting content |
| 2–4 cards only | `card-grid cols-2` or `cols-3` (no modifier) | Default — let cards breathe |

### Lead List

For slides that are just a bulleted list and feel empty at the default body
size, use `lead-list` to bump items to a presentation-weight scale:

```css
.lead-list > li {
    font-size: 1.2em !important;
    margin: 0.55em 0 !important;
    line-height: 1.55 !important;
}
```

```html
<h2>Technical Objectives We'll Validate</h2>
<ul class="lead-list">
    <li><strong>One platform, ten distinct brands</strong> — without collapsing differentiation</li>
    <li><strong>Respect franchisee autonomy</strong> — each is a separate legal entity</li>
    <li><strong>Deliver enterprise visibility</strong> corporate cannot get today</li>
</ul>
```

---

## Compact Table (legacy shorthand)

Older decks used this inline-override shorthand. Prefer the `lg-table` /
`compact-table` pair from Density Classes above for new work.

### CSS

```css
.compact-table td, .compact-table th {
    padding: 0.25em 0.5em !important;
    font-size: 0.95em;
}
```

### HTML Pattern

```html
<table class="compact-table">
    <thead><tr><th>Column 1</th><th>Column 2</th></tr></thead>
    <tbody>
        <tr><td>Dense data</td><td>Dense data</td></tr>
    </tbody>
</table>
```

---

## Skill Tags

Inline code-styled labels for referencing skill names.

### CSS

```css
.skill-tag {
    display: inline-block;
    background: #ebf8ff;
    border: 1px solid var(--hso-blue);
    border-radius: 4px;
    padding: 0.1em 0.45em;
    font-family: 'Consolas', monospace;
    font-size: 0.74em;
    color: var(--hso-navy);
    margin: 0.1em;
}
```

### HTML Pattern

```html
<span class="skill-tag">hso-dataverse-architect</span>
<span class="skill-tag">hso-plugin-development</span>
```

---

## Pre/Code Blocks

Styled `<pre>` blocks for folder structures, code samples, and terminal output.

### CSS

```css
.reveal pre {
    font-family: 'Consolas', 'Fira Code', monospace;
    font-size: 0.6em;
    background: #f0f4f8;
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 0.6em 0.8em;
    text-align: left;
    width: 100%;
    box-sizing: border-box;
    line-height: 1.45;
    box-shadow: none;
}
.reveal pre code {
    background: transparent;
    padding: 0;
    font-size: 1em;
}
```

### HTML Patterns

```html
<!-- Folder structure -->
<pre>
YourProject/
├── .shared/          ← git submodule
│   ├── claude-code/
│   │   ├── skills/
│   │   └── shared-scripts/
│   └── sync-shared.ps1
├── .claude/          ← synced working copy
│   ├── skills/
│   └── shared-scripts/
└── src/
</pre>

<!-- Code block -->
<pre><code>git submodule add &lt;repo-url&gt; .shared
.\sync-shared.ps1</code></pre>
```

---

## Image-Flanked Layout

Three-column layout with content cards flanking a centered image. Great for before/after comparisons.

### HTML Pattern

```html
<div style="display:grid;grid-template-columns:1fr auto 1fr;gap:0.8em;align-items:start;">
    <div class="card" style="border-left:4px solid var(--hso-coral);">
        <h4 style="color:var(--hso-coral);">Before</h4>
        <ul><li>Item 1</li><li>Item 2</li></ul>
    </div>
    <div style="text-align:center;">
        <img src="[path]" alt="[Description]" style="max-height:380px;border-radius:8px;box-shadow:0 2px 12px rgba(0,0,0,0.12);">
    </div>
    <div class="card" style="border-left:4px solid var(--hso-teal);">
        <h4 style="color:var(--hso-teal);">After</h4>
        <ul><li>Item 1</li><li>Item 2</li></ul>
    </div>
</div>
```

### When to Use

- Before/after comparisons
- Traditional vs modern approach slides
- Any slide where a visual should be flanked by supporting details

---

## Layer Stack

Stacked horizontal bars showing layered architectures (e.g., plugin layers, system tiers).

### CSS

```css
.layer-stack {
    text-align: left;
    margin: 0.4em auto;
    max-width: 90%;
}
.layer-stack .layer {
    padding: 0.4em 0.9em;
    border-radius: 6px;
    margin: 0.25em 0;
    font-size: 0.76em;
    font-weight: 600;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.layer-stack .layer .layer-desc {
    font-weight: 400;
    font-size: 0.9em;
    color: inherit;
    opacity: 0.85;
}
```

### HTML Pattern

```html
<div class="layer-stack">
    <div class="layer" style="background:#e1f0ff;color:var(--hso-navy);border:1px solid var(--hso-blue);">
        Top Layer <span class="layer-desc">Description</span>
    </div>
    <div class="layer" style="background:#e6fff9;color:#006654;border:1px solid var(--hso-teal);">
        Middle Layer <span class="layer-desc">Description</span>
    </div>
    <div class="layer" style="background:#f0f4f8;color:var(--hso-navy);border:1px solid var(--hso-steel);">
        Bottom Layer <span class="layer-desc">Description</span>
    </div>
</div>
```

### When to Use

- Plugin architecture (4-layer pattern)
- System tiers (presentation → business → data)
- Any layered/stacked concept
