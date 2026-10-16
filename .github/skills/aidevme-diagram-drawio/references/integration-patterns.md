# Diagram Integration Patterns

How to embed rendered diagrams in markdown deliverables and reveal.js slides.

## Markdown (`.md`) deliverables

### Basic embed
```markdown
![System Context — PreSales Manufacturing](diagrams/system-context.svg)
```

### With caption and width constraint (HTML inside markdown)
```markdown
<figure>
  <img src="diagrams/data-model-erd.svg" alt="Data Model ERD" style="max-width:900px;width:100%;" />
  <figcaption><em>Figure 2 — Core data model. Entities in HSO blue are custom; grey are out-of-the-box Dataverse tables.</em></figcaption>
</figure>
```

### GitHub-rendered markdown
SVG renders natively in GitHub markdown. PNG works too but loses crispness on HiDPI displays. Always prefer SVG.

## Reveal.js slides

### Pattern 1 — Image reference (simplest, recommended)
```html
<section>
  <h2>System Context</h2>
  <img src="diagrams/system-context.svg"
       alt="System Context"
       style="max-height:70vh;max-width:90%;" />
</section>
```

Pros: SVG file stays separate, edit once re-renders everywhere.
Cons: Reveal.js fragments/animations can't target individual shapes.

### Pattern 2 — Inline SVG (enables per-shape animation)
```html
<section>
  <h2>Plugin Execution Pipeline</h2>
  <!-- Paste full <svg>...</svg> content from the rendered .svg file here -->
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500">
    <!-- ...cells... -->
  </svg>
</section>
```

To animate individual elements, add `class="fragment"` to `<g>` groups within the SVG. Reveal.js will reveal them sequentially on slide advance.

Pros: Shape-level animation, no external file dependency.
Cons: Diagram edit requires re-pasting. Use only when animation matters.

### Pattern 3 — Background diagram (diagram IS the slide)
```html
<section data-background-image="diagrams/architecture-hero.svg"
         data-background-size="contain"
         data-background-color="#FFFFFF">
  <!-- Overlaid text, or leave empty for a pure diagram slide -->
</section>
```

Pros: Zero chrome, diagram fills the slide.
Cons: Works best for wide/hero diagrams; text must be baked into the SVG.

### Pattern 4 — Two-column with diagram + notes
```html
<section>
  <h2>Data Model Overview</h2>
  <div style="display:grid;grid-template-columns:2fr 1fr;gap:32px;align-items:center;">
    <img src="diagrams/data-model-erd.svg" style="max-width:100%;" />
    <div>
      <ul>
        <li>8 custom tables, all <code>hso_</code> prefix</li>
        <li>User-owned, franchise-scoped</li>
        <li>Alternate keys on external IDs</li>
      </ul>
    </div>
  </div>
  <aside class="notes">
    Walk the audience through the primary relationships first, then call out the alternate keys.
  </aside>
</section>
```

## Sizing rules

- **Markdown docs:** SVG scales to container. Cap at `max-width:900px` for readability.
- **Reveal.js 1920×1080 decks:** `max-height:70vh` leaves room for slide title + padding.
- **Reveal.js 1280×720 decks:** `max-height:65vh`.
- **PDF export of reveal.js:** SVG embeds cleanly. Avoid PNG at viewer zoom above 150%.

## Accessibility

- Always provide `alt` text — summarize the diagram purpose, not every shape.
- Reveal.js: add `<aside class="notes">` with a verbal description of the diagram for screen readers and presenter reference.
- Never rely on color alone — use position, labels, or shape variations to convey state (success/warning/risk).

## Versioning

Commit BOTH the `.drawio` source and the rendered `.svg`. This makes the markdown/deck self-sufficient while keeping diagrams editable.

```
diagrams/
├── system-context.drawio   <-- source, edit this
└── system-context.svg      <-- rendered artifact, embedded in docs/decks
```

Add a pre-commit reminder or CI check to re-render when `.drawio` changes.
