---
name: hso-diagram-plotly
layer: atomic
scope: core
description: |
  Author and render data-driven HSO-branded diagrams with Plotly (Python) — Sankey, treemap, sunburst, waterfall, funnel — where the geometry is computed from numeric inputs rather than hand-laid out. Outputs SVG + PNG with HSO palette and typography baked in. Use for "Sankey", "treemap", "sunburst", "waterfall" / "P&L bridge", "conversion funnel", or any quantitative breakdown / variance / drop-off visual where the data drives the picture. Does NOT produce reference architectures (`hso-diagram-reference-architecture`), ERDs / sequence / process flows (`hso-diagram-drawio`), or workshop sketches (`hso-diagram-excalidraw`).
---

# HSO Plotly Diagram Authoring

Author Python scripts that emit Plotly figures and render them to HSO-branded SVG + PNG. Plotly is the right tool when **the geometry should be computed from data** — band widths, rectangle areas, slice angles, bar heights — instead of hand-laid out.

## Purpose

Provide a reproducible Python authoring path for the data-driven archetypes that the other three HSO diagram skills cannot produce well: Sankey, treemap, sunburst, waterfall, and funnel. Output integrates with the same markdown / reveal.js / PPTX deliverables consumed by the rest of the diagram family.

## When to Use This Skill vs. Siblings

| Scenario | Use |
|---|---|
| Sankey (flows with proportional widths) | **plotly** |
| Treemap / sunburst (hierarchical breakdown by size) | **plotly** |
| Waterfall (variance bridge, P&L walk) | **plotly** |
| Funnel (stage-by-stage conversion) | **plotly** |
| Reference architecture (audiences + platform + externals) | hso-diagram-reference-architecture |
| ERD, sequence diagram, formal process flow, BPMN | hso-diagram-drawio |
| Workshop sketch / brainstorm / informal | hso-diagram-excalidraw |

Rule of thumb: **data-driven → plotly, hand-laid → drawio / excalidraw / reference-architecture**. If you find yourself manually positioning band widths so they "look right," you're authoring in the wrong tool.

## Prerequisites

- Python 3.10+
- `plotly` and `kaleido` Python packages (see [`scripts/requirements.txt`](scripts/requirements.txt))
- One-time install: `python -m pip install -r .claude/skills/hso-diagram-plotly/scripts/requirements.txt` (or the equivalent `shared/dv/claude-code/skills/...` path when run from the shared submodule)

If `kaleido` errors on first run, see [`references/troubleshooting.md`](references/troubleshooting.md).

## Configuration

Read from `CLAUDE.md`: optional engagement short name (used in the rev-stamp annotation if enabled).
Read from `CLAUDE.local.md`: optional **Author Name** (used in the rev-stamp annotation).

If neither is present, the helper omits the rev stamp. No diagram requires either field — they are purely cosmetic.

## Workflow

1. **Pick a template** from [`templates/`](templates/) and copy it into the engagement's diagram-source folder (e.g., `agent/work/deliverables/diagrams/_generators/`). Don't edit templates in place.
2. **Edit the numeric inputs** at the top of the script (the `# Data` block). All HSO palette and typography apply automatically — the only thing to tune is the data, the labels, and the title / subtitle.
3. **Run the script.** It writes an `.svg` and `.png` next to itself (or to a configured `OUT_DIR`).
4. **Embed** the SVG in `.md` deliverables or reveal.js slides, and the PNG in `.pptx`. See [`references/integration-patterns.md`](references/integration-patterns.md) for embed snippets.
5. **Commit** the `.py` source alongside the rendered `.svg` + `.png`.

### Round-trip
Plotly figures regenerate from source. If demo data changes, edit the inputs at the top of the `.py`, re-run, re-commit. The `.py` IS the source of truth — never hand-edit the rendered SVG.

## Templates

Located in [`templates/`](templates/). Each is a self-contained, runnable Python script with HSO palette inlined.

| Template | Use For |
|---|---|
| `sankey.py` | Flow diagrams with widths proportional to value |
| `treemap.py` | Hierarchical area-by-value breakdowns |
| `waterfall.py` | Variance bridge / start → adjustments → end |

Add new archetypes (sunburst, funnel, parallel-categories) by copying the closest existing template and adapting it. Keep the palette + layout helpers intact.

## Rendering

```powershell
pwsh -File .claude/skills/hso-diagram-plotly/scripts/Render-PlotlyDiagram.ps1 `
  -InputPath "<path-to-diagram.py>"
```

Or directly with Python:
```bash
python <path-to-diagram.py>
```

Each template writes its outputs by running itself — there's no separate render command. The PowerShell wrapper exists for parity with the sibling diagram skills.

## HSO Branding — Mandatory

Every diagram MUST use the HSO palette and the `apply_hso_layout(...)` helper for title, font, paper background, and margins.

The canonical palette source is the **HSO Brand Manual v3.0** — colors and naming are mirrored from the project-wide reference at [`hso-revealjs-presentation/references/hso-branding.md`](../hso-revealjs-presentation/references/hso-branding.md). See [`references/hso-plotly-styles.md`](references/hso-plotly-styles.md) for the per-archetype Plotly recipes that apply that palette.

Quick reference:

| Brand-manual name | Hex | Plotly use |
|---|---|---|
| `hso-dark-blue` | `#00395F` | Title text, axis text, node borders, anchor / total nodes |
| `hso-bluegreen` | `#079FC3` | Default categorical color 1 |
| `hso-green` | `#00B294` | Categorical color 2 — positive bars in waterfall |
| `hso-salmon` | `#F1554B` | Categorical color 3 — negative bars in waterfall, emphasis bands |
| `hso-mimosa` | `#F2B949` | Categorical color 4 — caution / external context |
| `hso-steel` | `#7F9CAF` | Subtitle text, secondary nodes, dashed connectors |
| `hso-light-grey` | `#E3E3E3` | Subtle fills, parent rectangles in treemap |
| (paper bg) | `#FDFCF7` | `paper_bgcolor` and `plot_bgcolor` (warm off-white, matches HSO slide masters) |

**Do NOT** use Plotly's default rainbow colorscales (`viridis`, `plasma`, etc.). They contradict the HSO visual grammar that the rest of the deck establishes. The brand manual's color-ratio rule applies: white and `hso-dark-blue` always have a higher proportion than `hso-bluegreen`; accent colors are used sparingly.

## Authoring Rules

1. **Inputs at the top, helpers below.** Every template has a `# Data` block in the first ~30 lines. That's the only place a downstream user should edit. If they need to touch the layout helpers below, the template needs a new parameter.
2. **One archetype per script.** Don't combine multiple archetypes into one mega-figure. If a story needs three archetypes, write three scripts.
3. **Real or illustrative — pick one and label it.** Either pull values from the engagement's actual data (transcripts, ADO, source systems) and cite the source in a comment, OR use illustrative balanced magnitudes and put `Illustrative — actual values narrated live` in the subtitle. Never silently mix.
4. **Width 1400 × height 780 default.** Matches the reveal.js slide aspect at presentation resolution. Override only when the archetype demands it (e.g., tall waterfall with many steps).
5. **Title + subtitle, not chart-junk.** One bold dark-blue title; one steel-grey subtitle that names the archetype + data scope. No legends if the labels are self-explanatory; explicit legend if the colors carry semantics.
6. **Commit `.py` + `.svg` + `.png`.** All three. SVG for markdown / reveal.js, PNG for PPTX, `.py` because it's the source of truth.

## Critical Rules

### DO

- **Use the palette helpers.** Import the colors and `apply_hso_layout()` from the inlined helper at the top of each template (or from [`scripts/lib/hso_plotly.py`](scripts/lib/hso_plotly.py) when not template-derived).
- **Anchor data to a source.** When using real engagement numbers, leave a comment pointing at the source artifact (digest / spec / wiki entry). When using illustrative numbers, say so in the subtitle.
- **Test at slide scale.** Open the rendered SVG at 1280×720 (typical reveal.js slide). Bands that look fine at 1400 px can clip at 1280 px. Adjust `pad`, `thickness`, or font sizes if needed.
- **Pin node positions for Sankey.** Use `arrangement="fixed"` with explicit `x` / `y` arrays. Plotly's auto-arrangement frequently produces band crossings that read as bugs.
- **Use 0.75 / 0.35 alpha pairs for Sankey link colors** when one band is "primary" and another is "secondary." The visual hierarchy reads instantly.

### DO NOT

- **Reference any client name, customer organization, or engagement-specific concept** in templates, references, or example data. This skill is shared across projects — generic placeholder values only (`Source A`, `Stage 1`, `Category Alpha`).
- **Ship without a PNG.** Slides embed PNG, not SVG. The render step writes both — don't skip.
- **Use Plotly's default colorscales.** They look like Tableau, not HSO.
- **Add chart-junk.** No gridlines on a Sankey. No tick marks on a treemap. No data labels stacked outside a tight waterfall.
- **Use sankey / treemap / waterfall for things they're bad at.** Sankey is not an org chart. Treemap is not a flow. Waterfall is not a trend over time.

## File Organization (engagement repo)

```
<engagement-repo>/
  agent/work/deliverables/diagrams/
    _generators/
      <slug>.py        # source — copied from templates/<archetype>.py, generic name
    <slug>.svg          # rendered, committed
    <slug>.png          # rendered, committed
```

Convention: source `.py` lives under `_generators/`; rendered SVG + PNG live one level up so deliverables can reference them with a clean relative path. Use a generic engagement-agnostic slug (e.g., `revenue_flow_sankey.py`, not encoding-specific naming).

## References

- [`references/hso-plotly-styles.md`](references/hso-plotly-styles.md) — palette + per-archetype Plotly layout recipes
- [`references/archetypes.md`](references/archetypes.md) — when each archetype (Sankey / treemap / waterfall / sunburst / funnel) is the right choice; anti-patterns
- [`references/integration-patterns.md`](references/integration-patterns.md) — embed patterns (mirrors the drawio / excalidraw skills)
- [`references/troubleshooting.md`](references/troubleshooting.md) — kaleido install issues, font substitution, Windows-specific gotchas
- [`templates/`](templates/) — runnable starter scripts (sankey, treemap, waterfall)
- [`scripts/lib/hso_plotly.py`](scripts/lib/hso_plotly.py) — palette constants + `apply_hso_layout()` helper (also inlined into each template for portability)
- [`scripts/Render-PlotlyDiagram.ps1`](scripts/Render-PlotlyDiagram.ps1) — PowerShell wrapper matching the sibling skills' interface
- [`scripts/requirements.txt`](scripts/requirements.txt) — pinned Python dependencies

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
