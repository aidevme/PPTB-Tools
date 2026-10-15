# Diagram Integration Patterns (Excalidraw SVG)

Embedding guidance mirrors the drawio skill — see `.claude/skills/hso-diagram-drawio/references/integration-patterns.md` for the comprehensive version. Quick reference below.

## Markdown embed

```markdown
![Workshop brainstorm](diagrams/workshop-brainstorm.svg)
```

With caption:
```markdown
<figure>
  <img src="diagrams/sketch-architecture.svg" alt="Field service architecture sketch" style="max-width:900px;width:100%;" />
  <figcaption><em>Figure 1 — Field service concept, drafted during 2026-04-12 discovery session.</em></figcaption>
</figure>
```

## Reveal.js slide

```html
<section>
  <h2>Working hypothesis</h2>
  <img src="diagrams/sketch-architecture.svg"
       alt="Architecture sketch"
       style="max-height:70vh;max-width:90%;" />
  <aside class="notes">
    This is a working sketch from the discovery workshop, not final architecture.
  </aside>
</section>
```

## Use-case framing

Because excalidraw SVGs look hand-drawn, always frame them appropriately in client-facing contexts:

- **OK:** "working sketch", "discovery notes", "draft concept", "workshop output"
- **NOT OK:** "recommended architecture", "solution design", "blueprint"

If you catch yourself using the hand-drawn look in a formal context, switch to drawio for that diagram.
