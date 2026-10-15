---
name: hso-diagram-excalidraw
layer: atomic
scope: core
description: |
  Author and render Excalidraw hand-drawn-style diagrams as HSO-branded SVG/PNG. Two modes: **workshop** (hachure fills, intentional informality — sketches, brainstorms, "thinking out loud" slides) and **conceptual-ERD** (solid fills, orthogonal arrows — single-screen 6–8 entity explainer for client-facing presales/demo decks). Use for "sketch diagram", "whiteboard diagram", "napkin sketch", "conceptual ERD", or "data model overview". Does NOT produce formal sign-off deliverables (full ERDs, sequence diagrams, BPMN) — use `hso-diagram-drawio` for those.
---

# HSO Excalidraw Diagram Authoring

Author `.excalidraw` JSON diagrams with HSO branding and render them to SVG using a self-contained Node script based on the official `@excalidraw/utils` package.

## When to Use This Skill vs. Drawio

| Scenario | Use |
|---|---|
| Workshop / brainstorm / design-session sketch | **excalidraw** (workshop mode — hachure) |
| "Napkin" architecture for internal discussion | **excalidraw** (workshop mode — hachure) |
| Reveal.js "thinking out loud" or discovery slide | **excalidraw** (workshop mode — hachure) |
| Conceptual ERD / data-model overview slide for a client-facing demo deck | **excalidraw** (conceptual-ERD mode — solid fills, orthogonal arrows) |
| Full sign-off ERD with cardinality, attributes, FK arrows | drawio |
| Sequence, BPMN, formal architecture intended for sign-off | drawio |

Rule of thumb: **explanatory → excalidraw, exhaustive → drawio**. Excalidraw can absolutely produce client-quality diagrams when the goal is to explain a concept on one slide; drawio is the choice when the diagram is the deliverable itself. Both skills share the HSO palette so diagrams feel like one family.

## Workflow

1. **Sketch the layout in ASCII first** when authoring a conceptual ERD or any multi-box diagram with relationships. Iterating on ASCII takes seconds; iterating on JSON + re-render takes minutes. Get the user to approve the layout (boxes, rows/columns, arrow verbs, solid vs dashed) BEFORE writing JSON. [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md#process--asciifirst-jsonsecond) is the authority for conceptual-ERD authoring — read it before designing.
2. **Pick a template** from `templates/` — copy into the working directory; don't edit templates in place. Or copy from `examples/` for a conceptual-ERD starting point.
3. **Edit the `.excalidraw` JSON** — Excalidraw JSON is ordinary JSON, diff-friendly, hand-authorable.
4. **Render to SVG** using the render script.
5. **(Optional) Convert SVG → PNG at 2400 px** when embedding in a reveal.js deck where the SVG renderer struggles with hand-drawn fonts. See [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md#render-workflow-svg--png-for-slides) for the one-liner.
6. **Embed** in `.md` or reveal.js using the same patterns as drawio SVGs (see `references/integration-patterns.md`).
7. **Commit** the `.excalidraw` source plus whichever rendered formats are referenced from the deck.

### Round-trip with excalidraw.com
Any `.excalidraw` file you author here can be opened at [excalidraw.com](https://excalidraw.com) (File → Open) for visual editing. Save back to the project folder, then re-render.

## Templates

Located in `templates/`.

| Template | Use For |
|---|---|
| `sketch-architecture.excalidraw` | Informal component architecture with HSO color accents |
| `workshop-brainstorm.excalidraw` | Cluster/brainstorm-style diagram with grouped stickies |

Prototype renderings live in `examples/`.

## Rendering

```powershell
pwsh -File .claude/skills/hso-diagram-excalidraw/scripts/Render-ExcalidrawDiagram.ps1 `
  -InputPath "path/to/diagram.excalidraw"
```

Or directly with Node:
```bash
node .claude/skills/hso-diagram-excalidraw/scripts/render-excalidraw.mjs path/to/diagram.excalidraw
```

Output defaults to the input path with `.svg` extension. Pass an explicit output path as the second argument to override.

### First-time setup
The Node renderer has npm dependencies (`@excalidraw/utils`, `jsdom`) installed once in `scripts/node_modules/`. If the folder is missing, run:
```bash
cd .claude/skills/hso-diagram-excalidraw/scripts && npm install
```

## HSO Branding — Mandatory

Excalidraw elements use `strokeColor` and `backgroundColor` hex values. All diagrams MUST use the HSO canonical palette. Authority for HSO colors and element styling — read [`references/hso-excalidraw-styles.md`](references/hso-excalidraw-styles.md) before assigning any color; the table below is a digest only, not a substitute for the cheatsheet:

| Role | Hex |
|---|---|
| Primary / stroke | `#00395F` |
| Accent (default) | `#079FC3` |
| Success | `#00B294` |
| Warning | `#F1554B` |
| Caution | `#F2B949` |
| Muted | `#7F9CAF` |
| Neutral body | `#FFFFFF` / `#505050` text |
| Backdrop | `#ECEFF3` |

Prefer `strokeColor=#00395F` for ALL outlines and text, and vary fill color for emphasis.

**`fillStyle` selection depends on mode:**
- **Workshop / brainstorm mode** — use `hachure` (the signature Excalidraw look). Reserve `solid` for elements that need to stand out as "finished."
- **Conceptual-ERD mode (client-facing)** — use `solid` for ALL entity boxes. Hachure reads as "sketchy/unfinished" in a deck. Authority for conceptual-ERD authoring — read [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md) before designing any client-facing data-model diagram.

## Authoring Rules

1. **Pretty-printed JSON** — two-space indentation, trailing newlines omitted. Diff-friendly.
2. **Stable `id` values** — keep them human-readable (`mobile`, `dataverse`, `arrow_a_to_b`) so diffs stay small.
3. **Coordinates on 20px grid** — match the `appState.gridSize: 20`.
4. **Roughness = 1** on every element — this is the signature "hand-drawn but tidy" look. Roughness 0 defeats the purpose; roughness 2 is too chaotic for HSO.
5. **Font family 3** (Segoe UI Emoji fallback in Excalidraw) or **1** (Virgil, the excalidraw default) — both render as hand-drawn text. Pick one per diagram and stay consistent.
6. **Bind arrows to elements** via `startBinding` / `endBinding` so they re-route automatically if you reposition boxes — EXCEPT for L-shape arrows (3-segment `points` arrays). For L-shapes, drop the bindings; otherwise Excalidraw auto-reroutes and erases the carefully chosen path.
7. **Use orthogonal arrows for conceptual ERDs** — straight horizontal, straight vertical, or L-shape. Never diagonal. Diagonals read as "messy"; orthogonal reads as "intentional."
8. **Keep it explanatory, not exhaustive** — if a diagram needs cardinality, FK arrows, attribute lists, or 10+ entities, switch to drawio. Excalidraw shines at one-slide concept explainers.

## Conceptual ERD Mode — Quick Reference

When the request is "conceptual ERD", "data-model overview", or "concept diagram" for a client-facing slide, switch to the conceptual-ERD style. Authority for conceptual-ERD authoring — read [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md) before designing a conceptual ERD.

Digest only — the guide is authoritative; these five rules change the most but are NOT a substitute for it (the guide also carries load-bearing rules absent here: grid column-center math, arrow-label positioning, solid-vs-dashed arrow semantics, relationship-verb vocabulary):

| Rule | Why |
|---|---|
| `fillStyle: "solid"` on every box (NOT hachure) | Hachure reads as "unfinished" in a deck |
| All boxes 300 × 110 — uniform sizing | Emphasis comes from color, not size |
| One **anchor** box (navy fill, white text); optionally one **accent** box (bluegreen fill, white text); rest white-fill, navy-text | Visual hierarchy without varying size |
| Orthogonal arrows only — never diagonal; L-shape arrows use explicit `points` and DROP `startBinding`/`endBinding` | Diagonals look messy; bindings re-route L-shapes |
| Cap at 7–8 entities; split into multiple diagrams beyond that | Conceptual ≠ exhaustive |

Reference renders: [`examples/franchisee_conceptual.svg`](examples/franchisee_conceptual.svg) and [`examples/billing_royalty_conceptual.svg`](examples/billing_royalty_conceptual.svg). Their `.excalidraw` source files in `examples/` are the most useful starting points for new conceptual ERDs — copy and adapt.

## Integration Patterns

Identical to drawio — see `references/integration-patterns.md` (shared across both diagram skills). Quick reference:

```markdown
![Workshop sketch](diagrams/workshop-brainstorm.svg)
```

```html
<section>
  <h2>Working hypothesis</h2>
  <img src="diagrams/sketch-architecture.svg" alt="Architecture sketch" style="max-height:70vh;" />
</section>
```

## File Organization

```
clients/<Client>/PROJ-<name>/
├── 02_discovery/
│   └── diagrams/
│       ├── workshop-2026-04-15.excalidraw
│       └── workshop-2026-04-15.svg
```

Commit both the `.excalidraw` source and the rendered `.svg`.

## References

### Task → primary authority

A standalone task should land on the doc that governs it:

| Task | Primary authority |
|---|---|
| Author a conceptual ERD / data-model overview | [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md) |
| Choose HSO colors / element styling (any mode) | [`references/hso-excalidraw-styles.md`](references/hso-excalidraw-styles.md) |
| Embed an SVG/PNG in `.md` or reveal.js | [`references/integration-patterns.md`](references/integration-patterns.md) |
| Workshop / brainstorm sketch | SKILL.md Authoring Rules + [`references/hso-excalidraw-styles.md`](references/hso-excalidraw-styles.md) for colors |

### Reference docs

- [`references/hso-excalidraw-styles.md`](references/hso-excalidraw-styles.md) — Authority for HSO colors and element styling (full palette + element-type cheatsheet); read before assigning any color.
- [`references/conceptual-erd-style.md`](references/conceptual-erd-style.md) — Authority for conceptual-ERD authoring (ASCII-first process, layout grid, arrow rules, render-to-PNG workflow, relationship verb vocabulary); read before designing any client-facing data-model diagram.
- [`references/integration-patterns.md`](references/integration-patterns.md) — embed patterns (content mirrors drawio skill)
- `templates/` — starter `.excalidraw` files for workshop-mode sketches
- `examples/` — rendered reference SVGs plus `.excalidraw` sources for conceptual-ERD diagrams (`franchisee_conceptual`, `billing_royalty_conceptual`) — copy these as starting points
- `scripts/render-excalidraw.mjs` — Node renderer (uses `@excalidraw/utils` + jsdom)
- `scripts/Render-ExcalidrawDiagram.ps1` — PowerShell wrapper matching the drawio skill's interface

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
