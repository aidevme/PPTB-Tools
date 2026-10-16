---
name: aidevme-diagram-drawio
layer: atomic
scope: core
description: |
  Author and render draw.io (diagrams.net) diagrams as HSO-branded SVG/PNG for embedding in markdown deliverables and reveal.js presentations. Use when:
  (1) User asks to "create a diagram", "draw an ERD", "draw an architecture diagram", "add a diagram to the doc/deck"
  (2) User asks for a system context, sequence, process flow, or component diagram and wants a formal/client-ready rendering
  (3) User provides a `.drawio` file and asks to update, render, or convert it
  (4) A reveal.js slide or `.md` file needs an embedded diagram
  Primary output is SVG (scales for both markdown and reveal.js). PNG/PDF available for print. Does NOT handle hand-drawn / whiteboard-style diagrams — use hso-diagram-excalidraw for those.
---

# HSO Draw.io Diagram Authoring

Author draw.io XML diagrams by hand using HSO-branded templates, then render with the draw.io desktop CLI.

## When to Use This Skill vs. Excalidraw

| Scenario | Use |
|---|---|
| Client deliverable (analysis doc, blueprint, proposal) | **drawio** |
| ERD, sequence diagram, BPMN-style process | **drawio** |
| Azure/D365 architecture with standard icons | **drawio** |
| Reveal.js formal architecture slide | **drawio** |
| Workshop brainstorm, "napkin sketch", exploratory | excalidraw |
| Reveal.js "thinking out loud" slide | excalidraw |

If in doubt: **formal → drawio, sketchy → excalidraw**.

## Workflow

1. **Pick a template** from `templates/` that matches the diagram type (copy into working directory — never edit templates in place).
2. **Edit the `.drawio` XML** to fit the content. All templates use uncompressed XML so they are diff-friendly.
3. **Render to SVG** using the render script (see below).
4. **Verify the render — MANDATORY.** Rasterize the rendered SVG to PNG and look at it before embedding. The [Edge Routing Rule](#edge-routing-rule--critical) below is prose-only — nothing enforces it, so an edge crossing a node label renders silently and passes every downstream check (the reveal.js layout audit does not look inside an SVG). Eyeball for: edges drawn over box labels, arrows that skip past a box, and decision-loop edges cutting through other nodes. If you see overlap, pin anchors / reposition per the rule and re-render. Do not skip this because the XML "looks right" — the router's behaviour is only visible once rendered.
5. **Embed** the SVG in the `.md` or reveal.js slide using the patterns in `references/integration-patterns.md`.
6. **Commit both** the `.drawio` source and the rendered `.svg` so future edits remain possible.

## Templates

Located in `templates/`. Each uses the HSO canonical palette (see `references/hso-drawio-styles.md`).

| Template | Use For |
|---|---|
| `erd.drawio` | Entity-relationship — Dataverse tables, data models |
| `architecture.drawio` | Layered architecture — Azure/D365 components, tech stack |
| `system-context.drawio` | C4-style system context — actors + system + externals |
| `sequence.drawio` | Sequence/interaction — plugin pipeline, API calls, flows |
| `process-flow.drawio` | BPMN-lite swim lanes — business processes |

Prototype examples (rendered SVGs) live in `examples/` — use these to preview the style.

## Rendering

Use the render script rather than invoking `draw.io.exe` directly:

```powershell
pwsh -File .claude/skills/hso-diagram-drawio/scripts/Render-DrawioDiagram.ps1 `
  -InputPath "path/to/diagram.drawio" `
  -Format svg
```

Parameters:
- `-InputPath` (required) — `.drawio` file or folder
- `-Format` — `svg` (default, preferred), `png`, `pdf`
- `-OutputPath` — defaults to same path with new extension
- `-Transparent` — switch, for PNG transparent background
- `-Width` / `-Height` — optional; preserves aspect ratio
- `-Scale` — optional; default 1.0

SVG is the default because it embeds crisply in both `.md` and reveal.js without resolution loss.

### Fallback: when the draw.io desktop CLI can't render

On managed / headless Windows the draw.io desktop binary's export often **fails silently** — `DrawIO.exe --export ...` returns exit code 0 and writes **no file** (no display for its Electron renderer). If the render script produces nothing and reports success, this is why. The reliable fallback is to render the mxGraph XML with the **draw.io GraphViewer in headless Chromium** (Playwright):

1. Build a tiny HTML page that loads `https://viewer.diagrams.net/js/viewer-static.min.js` and holds the `.drawio` XML in a `<div class="mxgraph" data-mxgraph='{"xml":"…"}'>`.
2. After load, call `GraphViewer.processElements()` (auto-processing does not fire reliably under `page.setContent`), wait for `.mxgraph svg`, then read the `<svg>`'s `outerHTML`.
3. Derive a `viewBox` from the svg's `style.minWidth`/`minHeight`, strip the fixed sizing, and save.

Three gotchas that will otherwise corrupt the output:

- **Soft line breaks (`\n` in a label):** GraphViewer renders the literal characters `\n`, but rewriting them to `<br>` / `&#10;` / `&lt;br&gt;` **truncates the graph at the first such cell** (a raw `<` is invalid inside an XML attribute). Replace `\n` with a **space** and let `whiteSpace=wrap` wrap the label.
- **Embedding:** GraphViewer labels are HTML in `<foreignObject>`, which browsers **do not render via `<img src="*.svg">`**. For reveal.js you must **inline** the `<svg>` markup into the slide, not reference it as an image. (The `revealjs-to-pptx` path rasterizes via `sharp`, so PPTX is unaffected.)
- **Reading it back:** view the rendered PNG/SVG before trusting it — see Workflow step 4.

## HSO Branding — Mandatory

All diagrams MUST use the HSO canonical palette. See `references/hso-drawio-styles.md` for copy-paste drawio `style=` strings. Short version:

| Role | Hex | drawio style fragment |
|---|---|---|
| Primary (headers, primary entities) | `#00395F` | `fillColor=#00395F;fontColor=#FFFFFF;strokeColor=#00395F` |
| Accent (default) | `#079FC3` | `fillColor=#079FC3;fontColor=#FFFFFF;strokeColor=#079FC3` |
| Success | `#00B294` | `fillColor=#00B294;fontColor=#FFFFFF;strokeColor=#00B294` |
| Warning / Risk | `#F1554B` | `fillColor=#F1554B;fontColor=#FFFFFF;strokeColor=#F1554B` |
| Caution | `#F2B949` | `fillColor=#F2B949;fontColor=#00395F;strokeColor=#F2B949` |
| Neutral body | `#FFFFFF` / `#505050` text | `fillColor=#FFFFFF;fontColor=#505050;strokeColor=#00395F` |
| Muted backdrop | `#ECEFF3` | `fillColor=#ECEFF3;strokeColor=#7F9CAF;fontColor=#505050` |

**Never** introduce colors outside this palette.

Typography: drawio renders with a web-safe default. For diagrams meant to match reveal.js decks, add `fontFamily=Segoe UI` to styles where legibility matters.

## Authoring Rules

1. **Uncompressed XML only** — pass `-u` to drawio or start from templates. Compressed XML is not diff-friendly.
2. **Stable IDs** — when editing, keep existing `mxCell id="..."` values so diffs stay small.
3. **Snap to grid** — all coordinates on multiples of 20 (standard drawio grid).
4. **Orthogonal edges for architecture/ERD** — use `edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#00395F`.
5. **Straight edges for sequence** — use `endArrow=classic;strokeColor=#00395F`.
6. **Title block** — every diagram gets a title in the top-left using the HSO primary color bar (see templates).
7. **Label density** — max ~7 entities per "row" in architecture diagrams. Split into layers if denser.

## Edge Routing Rule — CRITICAL

**drawio's orthogonal router does NOT avoid intermediate shapes.** It only makes 90° turns between source and target anchor points. Any edge whose shortest orthogonal path crosses another box WILL render on top of that box.

Follow these rules to prevent overlap:

1. **Layered diagrams (architecture, system context):** Only draw edges between VERTICALLY ALIGNED boxes in ADJACENT layers. Use matching x-coordinates across layers to enable clean vertical drops.
2. **Pin the exit and entry anchors** on every edge so routing is deterministic:
   - Top-to-bottom (layer to layer): `exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;`
   - Left-to-right (same row): `exitX=1;exitY=0.5;entryX=0;entryY=0.5;`
3. **No same-layer arrows** in architecture-style diagrams — same-layer relationships pass through their neighbors. Convey them via spatial grouping, color coding, or a legend note instead.
4. **No diagonal / skip-layer arrows.** A diagram that "needs" one either (a) is trying to say too much (split into multiple diagrams) or (b) has the wrong component layout (reposition so the relationship becomes a clean vertical).
5. **Cardinal jumps only** for ERDs — edges connect entity boxes side-by-side or one-above-the-other, never diagonally across multiple other entities.

When in doubt: fewer arrows, more positional grouping. A diagram with 6 clean vertical arrows communicates better than one with 12 overlapping ones.

## Integration Patterns

See `references/integration-patterns.md` for complete snippets. Summary:

**Markdown embed:**
```markdown
![System Context — PreSales Manufacturing](diagrams/system-context.svg)
```

**Reveal.js slide embed:**
```html
<section>
  <h2>System Context</h2>
  <img src="diagrams/system-context.svg" alt="System Context" style="max-height:70vh;" />
</section>
```

**Reveal.js inline SVG** (for animation/reveal support — paste SVG content directly inside the `<section>`).

## File Organization

Within a project, store diagrams co-located with the doc they support:

```
clients/<Client>/PROJ-<name>/
├── 04_solutioning/
│   ├── Architecture_Analysis.md
│   └── diagrams/
│       ├── system-context.drawio
│       ├── system-context.svg
│       ├── data-model-erd.drawio
│       └── data-model-erd.svg
```

Commit **both** `.drawio` and `.svg` — the XML is the source, the SVG is the embeddable artifact.

## References

- `references/hso-drawio-styles.md` — full palette + style string cheatsheet
- `references/integration-patterns.md` — markdown and reveal.js embed patterns
- `references/drawio-xml-cheatsheet.md` — common mxCell/mxGeometry patterns
- `templates/` — starter `.drawio` files
- `examples/` — rendered reference SVGs
