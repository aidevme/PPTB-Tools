---
name: hso-diagram-reference-architecture
layer: atomic
scope: core
description: |
  Author, review and render hand-coded SVG diagrams for D365 / Power Platform engagements — reference architectures, plus any hand-laid-out figure needing precise, durable, restyleable geometry (process swimlane, fixed-canvas one-pager). Owns the HSO SVG visual grammar, connector geometry and pre-handoff review checklist. Not for ERDs or sequence diagrams (`hso-diagram-drawio`) or sketches (`hso-diagram-excalidraw`).
---

# HSO Reference Architecture Diagram Authoring

Author hand-coded SVG reference-architecture diagrams in the HSO visual language and render them to 2400-px-wide PNG using a self-contained Node + sharp pipeline. Output is a single SVG (source) plus a PNG render, both committed alongside the engagement deliverables.

## Purpose

Every Dynamics 365 / Power Platform implementation needs ONE diagram that answers: "who uses this, what is the platform, and what does it integrate with?". This skill produces that diagram. It is the cover-page architecture image for blueprints, presales decks, technical demos, design reviews, and post-implementation documentation. Because the same engagement may show this image in 10+ different decks across 18 months, the diagram is hand-coded SVG (precise, durable, version-controllable, restyleable) rather than a one-off drawing.

## When to use this skill vs. siblings

| Scenario | Use |
|---|---|
| Reference architecture for an engagement (system context, audiences, platform, integrations on ONE page) | **hso-diagram-reference-architecture** |
| Full ERD with cardinality, FK arrows, attribute lists | hso-diagram-drawio |
| Conceptual data-model overview (6-8 entities on one slide) | hso-diagram-excalidraw (conceptual-ERD mode) |
| Sequence diagram, BPMN, formal process flow | hso-diagram-drawio |
| Workshop sketch / brainstorm / "thinking out loud" diagram | hso-diagram-excalidraw (workshop mode) |
| Standard BPMN-lite process flow / swim lanes, rendered through the drawio pipeline | hso-diagram-drawio (`process-flow.drawio`) |
| A swimlane, matrix or one-pager that must be a **fixed-canvas, precisely laid-out branded figure** — e.g. a 1920x1080 deck slide reused and restyled across many decks | **hso-diagram-reference-architecture** |

Rule of thumb: reference architecture is **formal, hand-coded, single-page**. ERDs and sequence diagrams are **drawio**. Sketches are **excalidraw**.

**Swimlanes sit on the boundary.** Ask what the figure has to survive. A process flow that just needs to be *correct and legible* is a drawio job — the template exists, the pipeline is faster, and nobody will re-typeset it. A figure that has to hold an exact canvas, carry the HSO visual grammar, and be re-edited by hand over months (a deck's summary slide, a leave-behind one-pager) is a hand-coded SVG job and belongs here. When it lands here, everything in this skill applies unchanged: [ASCII-first](references/ascii-first-process.md), the [visual grammar](references/visual-grammar.md), and the [review checklist](references/review-checklist.md).

## Workflow

1. **Gather inputs** - ask the user (use `AskUserQuestion` style for the structured ones):
   - **Engagement / client short name** - read from `CLAUDE.md` and `CLAUDE.local.md` if present (publisher prefix, client name, author). Use it for the bottom-right rev stamp.
   - **Layout** - LTR or TTB. Default to TTB for slides where audiences must appear at the top; LTR for traditional system-context where data flows left to right. See `references/layout-ttb.md` and `references/layout-ltr.md` for the trade-offs.
   - **Audience list with grouping** - e.g., 3 groups: Field Users (Field Tech, Dispatcher) / Customers (Homeowner, Subscriber) / Corporate (Brand President, Executive). Note WHICH audience is the primary / emphasized persona (gets the coral border).
   - **Microsoft cloud platform components in scope** - which D365 apps (FS, Customer Service, Sales)? Which Power Platform components (Power Apps, Customer Portal, Power Automate, Copilot/Agents)? Which Azure subscription components (Functions, Service Bus, Fabric Link, others)?
   - **External systems list** - data warehouses (Databricks / S3 / Redshift), ERPs (NetSuite, QBO, Sage Intacct), payment processors (Stripe), CTI (Five9, Genesys), other.
   - **Branding overrides** - default = HSO palette per `references/visual-grammar.md`. Almost never overridden - if the user wants a different palette, push back unless they explicitly justify it.
2. **Read the engagement's architecture documents** — DO NOT draw what you assume the system looks like; draw what the documents say it is. Walk the project's `agent/wiki/` and `agent/work/` and read everything relevant before sketching:
   - `agent/wiki/system/` — current-state and target-architecture snapshots (the authoritative shape)
   - `agent/wiki/decisions/` — ADRs that constrain the architecture (tenancy model, data model, integration patterns)
   - `agent/wiki/topics/` — anchor pages for relevant subjects (integration topics often list which payment processors, ERPs, CTI vendors are in discussion)
   - `agent/work/analysis/` — analysis documents that named specific products, vendors, or integration patterns (e.g., a `netsuite_integration_analysis.md` will tell you whether NetSuite is current-state or planned, which side of the integration boundary it sits on, and which Azure Function calls it)
   - `agent/work/specs/` — feature specs for in-flight components
   - `agent/work/deliverables/` — prior decks, particularly any "Technical Demo" or "Platform Architecture" decks; their slides often contain the canonical wording for platform capabilities (e.g., the "What is Dataverse — Six Capabilities" slide is the source of truth for the Dataverse card text)
   - Source code under `Solutions/` or `SourceCode/` — when a card lists vendor names (payment processors, ERPs), confirm against the actual implementations registered in DI / configured in code, not against memory
   
   **Why this matters:** the diagram's job is to be a faithful, single-page summary of the architecture. If a card says "Stripe · Adyen · Worldpay" but the code only implements Stripe, Authorize.Net, and CyberSource, the diagram is misleading and will get rejected the first time someone technical reads it. If the Dataverse card emphasizes "property-anchored" but one in-scope brand (e.g., a healthcare line) is person-anchored, the diagram contradicts itself. The review checklist will catch some of these, but reading the source documents catches them BEFORE you draw, when the cost of correction is zero.
   
   When sketching ASCII (next step), cite which document each card / arrow comes from in your scratch notes — that audit trail makes the user's review faster and surfaces gaps where no document exists yet (those gaps are themselves valuable findings).
3. **Sketch the layout in ASCII first** - see `references/ascii-first-process.md`. Iterating on ASCII takes seconds; iterating on SVG coordinates takes minutes. Get explicit user approval on the ASCII BEFORE writing any SVG.
4. **Pick a skeleton** - copy `templates/ttb-skeleton.svg` or `templates/ltr-skeleton.svg` into the working directory (typically `agent/work/deliverables/diagrams/<name>.svg`). Inline the full `<defs>...</defs>` block from `templates/defs-block.svg` at the top.
5. **Fill in zones** using:
   - `references/visual-grammar.md` for class roles, color semantics, and card archetypes,
   - `references/icon-catalog.md` for glyph picks and vendor icon sourcing,
   - `references/layout-ttb.md` or `references/layout-ltr.md` for the coordinate template (audience x-positions, channel widths, persona arrow targets, ribbon dimensions).
6. **Render to PNG** with the script:
   ```bash
   node scripts/render-svg.mjs <svg-path>
   ```
   Outputs a PNG next to the SVG at 2400 px wide. First-time setup: `cd scripts && npm install`.
7. **Self-review against `references/review-checklist.md`** - this is YOUR responsibility, not the user's. Run the checklist top to bottom: layout placement -> arrow geometry -> text fit -> labels -> polish. Fix every failing row in the SVG, re-render, re-walk. Do NOT hand the diagram back until every row passes.
8. **Commit** the SVG and PNG together. Both belong in version control - the SVG is the source, the PNG is the rendered artifact embedded in slides / markdown.

### Updating an existing diagram

When asked to update an existing diagram (add a persona, swap an integration, recolor an arrow):

1. Read the existing SVG.
2. Identify the smallest zone that changes (e.g., add a card to the External column - don't reflow the platform).
3. Make the change.
4. Re-render.
5. Walk the review checklist - even a small change can break arrow geometry or text fit elsewhere.

## Configuration

This skill reads from project configuration:

| File | Used for |
|---|---|
| `CLAUDE.md` | Engagement name, publisher prefix (for default file naming), platform component defaults (e.g., which D365 apps are in scope) |
| `CLAUDE.local.md` | Author name (for the bottom-right rev stamp), local Node path if non-standard |

If a CLAUDE.md / CLAUDE.local.md isn't present, ASK the user for the engagement name and author rather than guessing.

## Critical rules

### DO

- **Documents-first, ASCII-second, SVG-third.** Read `agent/wiki/system/`, `agent/wiki/decisions/`, the relevant `agent/wiki/topics/` anchor pages, and any `agent/work/analysis/` documents that touch the components/integrations on the diagram BEFORE you sketch ASCII. The diagram must reflect the documented architecture, not your assumption of it.
- **ASCII-first (over SVG).** Always. No exceptions. See `references/ascii-first-process.md`.
- **Render-then-review.** Render the PNG, view it, walk `references/review-checklist.md`, fix issues, re-render. Never hand back without a render-review pass.
- **Right-angle arrows only.** V/H/V or L-shape. Diagonals are prohibited unless the user explicitly authorizes them for a specific arrow.
- **One-word-per-line labels in narrow channels.** When channel width forces a label under ~8 chars per line, stack words vertically instead of overflowing.
- **Use the coordinate templates.** `references/layout-ttb.md` and `layout-ltr.md` give pre-tuned positions for audience cards, persona arrow targets, and zone widths. Bespoke positions are a last resort.
- **Use the same stroke width on all arrows.** 2.5 px. Emphasis comes from COLOR (coral for emphasized; blue for standard; etc.), not from thickness - because markers scale with stroke under default `markerUnits="strokeWidth"`.
- **Use the canonical defs block.** Copy `templates/defs-block.svg` verbatim. Don't re-author the CSS classes, markers, or symbol glyphs.

### DO NOT

- **Don't skip the review checklist.** You can spot tip-only arrows, bunched entries, and text overflow in 30 seconds with the rendered PNG. The user shouldn't have to.
- **Don't use diagonal arrows** unless the user explicitly authorizes a specific exception. They look messy; orthogonal reads as intentional.
- **Don't embed client logos** in the shared templates. Vendor icons (Microsoft, AWS, etc.) are fine; client-specific logos belong in the engagement's working SVG only.
- **Don't ship without a PNG render.** Slides embed the PNG, not the SVG. An SVG without a PNG is half-done.
- **Don't reuse arrow colors for different roles.** Each color has ONE meaning per the legend (coral = emphasis, blue = user UX, amber = bulk data, purple = payments, green = ERP, steel dashed = optional). The legend is a contract.
- **Don't put client-specific persona names, brand counts, or environment URLs in shared skill files.** Those belong in the engagement's working SVG.

## Templates

In `templates/`:

| Template | Use |
|---|---|
| `defs-block.svg` | Canonical `<defs>` block - 16 CSS classes, 6 arrow markers, 12 inline symbol glyphs, 11 base64-embedded vendor symbols (Dataverse, D365, D365 FS, Power Automate, Power Apps, Power Pages, Copilot, Azure, AWS, Power BI, QuickBooks). Inline verbatim into every diagram. |
| `ttb-skeleton.svg` | TTB layout skeleton - canvas, zone rectangles, comment markers for each fill region. |
| `ltr-skeleton.svg` | LTR layout skeleton - canvas, zone rectangles, comment markers for each fill region. |

## References

Each reference below that governs a first-class authoring operation carries an explicit authority line in the form "Authority for `<X>` - read before `<doing X>`." Read the governing doc before doing the task it owns; do not act on this SKILL.md alone for that task.

- [`references/review-checklist.md`](references/review-checklist.md) - Authority for diagram self-review - read and walk before handing any diagram back. 18-row checklist of the layout / arrow / text mistakes that actually ship if you don't review. Centerpiece of the skill.
- [`references/visual-grammar.md`](references/visual-grammar.md) - Authority for palette, CSS classes, arrow-color semantics, connector geometry, card archetypes, ribbon styling, and legend conventions - read before styling or routing any card or arrow.
- [`references/icon-catalog.md`](references/icon-catalog.md) - Authority for icon selection, sizing, and dark/light background handling - read before placing any icon. Digest only (the catalog, not this bullet, is authoritative for the full roster, recommended sizes, and background guidance): all Microsoft and partner brand icons (Dataverse, D365, D365 Field Service, Power Automate, Power Apps, Power Pages, Copilot, Azure, AWS, Power BI, QuickBooks) plus inline-glyph symbols (Phone, Browser, Person, Corp, Functions, Service Bus, Fabric, Stripe, NetSuite, Databricks, S3, Redshift) are pre-embedded as `<symbol>` definitions in `templates/defs-block.svg` and used via `<use href="#icDataverse" x="..." y="..." width="..." height="..."/>`.
- [`references/layout-ttb.md`](references/layout-ttb.md) - Authority for TTB coordinate placement - read before writing any SVG coordinates when the chosen layout is TTB. Coordinate template: canvas, audience band, AWS / Platform / External columns, channels, persona arrow targets, legend band.
- [`references/layout-ltr.md`](references/layout-ltr.md) - Authority for LTR coordinate placement - read before writing any SVG coordinates when the chosen layout is LTR. Coordinate template: personas column, platform column, external column, channels, legend band.
- [`references/ascii-first-process.md`](references/ascii-first-process.md) - Authority for the layout-sketching step - read before sketching. The ASCII-first-coordinates-second rule, with a worked example.

### Task -> primary authority

A standalone task should land on its governing doc directly via this map:

| Task | Primary authority |
|---|---|
| Sketch the layout before coding SVG | [`references/ascii-first-process.md`](references/ascii-first-process.md) |
| Choose a layout (LTR vs TTB) and its trade-offs | [`references/layout-ttb.md`](references/layout-ttb.md) / [`references/layout-ltr.md`](references/layout-ltr.md) |
| Write SVG coordinates (TTB layout) | [`references/layout-ttb.md`](references/layout-ttb.md) |
| Write SVG coordinates (LTR layout) | [`references/layout-ltr.md`](references/layout-ltr.md) |
| Style a card or arrow (palette, classes, arrow-color semantics, legend) | [`references/visual-grammar.md`](references/visual-grammar.md) |
| Route an arrow (straight vs. elbow, leg order, marker length, head clearance) | [`references/visual-grammar.md`](references/visual-grammar.md) § "Connector geometry" |
| Pick / size / place an icon (incl. dark/light background) | [`references/icon-catalog.md`](references/icon-catalog.md) |
| Self-review before handoff | [`references/review-checklist.md`](references/review-checklist.md) |

## Examples

The `examples/` folder is intentionally light. Canonical reference implementations live in the originating engagement repo (they contain client-specific names that don't belong in a shared skill). See [`examples/README.md`](examples/README.md) for pointers.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/render-svg.mjs` | Node renderer (uses sharp). Input: SVG path. Output: PNG at 2400 px wide, density 200. |
| `scripts/Render-ReferenceArchitecture.ps1` | PowerShell wrapper matching the interface of `Render-ExcalidrawDiagram.ps1` in the sibling skill. |
| `scripts/package.json` | npm dependency declaration (`sharp ^0.33.0`). One-time `npm install` in the scripts folder. |

Usage:

```bash
node scripts/render-svg.mjs path/to/diagram.svg
# -> path/to/diagram.png
```

```powershell
pwsh -File scripts/Render-ReferenceArchitecture.ps1 -InputPath path/to/diagram.svg
```

## File organization

```
<engagement-repo>/
  agent/work/deliverables/diagrams/
    reference_architecture.svg        # source, hand-coded
    reference_architecture.png        # rendered, committed alongside SVG
```

If the engagement produces multiple architecture variants (e.g., one per major release), name them `reference_architecture_<variant>.svg` (e.g., `reference_architecture_v2.svg`).

### Embedding the SVG inline in a Reveal.js deck

A deck slide can carry the SVG inline rather than as an `<img>`, which keeps it crisp and theme-able. Two things bite:

- **`<marker>` ids are document-global, not SVG-scoped.** A second inline SVG in the same HTML file that also defines `arrBlue` silently wins or loses depending on document order, and one diagram's arrowheads change color or vanish. **Prefix every `id` and its `url(#...)` reference per slide** (e.g. `arrBlue` -> `s37-arrBlue`) when copying the SVG into a deck. The same applies to `<symbol>` ids from `templates/defs-block.svg`.
- **The standalone file stays the source of truth.** Edit the `.svg`, then re-derive the inline copy — never hand-edit the copy in the deck. Diff the two (modulo the id prefix and the root `width`/`height` -> `100%` + `preserveAspectRatio`) before shipping, so the deck can't drift from the committed diagram.

Verify the embedded slide by rendering it, not by reading the diff — see [`references/review-checklist.md`](references/review-checklist.md) § "Self-review protocol".

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
