# HSO Plotly Style Reference

Canonical HSO palette and copy-paste recipes for Plotly figures. Mirrors the [drawio](../../hso-diagram-drawio/references/hso-drawio-styles.md), [excalidraw](../../hso-diagram-excalidraw/references/hso-excalidraw-styles.md), and [reference-architecture](../../hso-diagram-reference-architecture/references/visual-grammar.md) palettes so diagrams across all four skills look like one family.

## Palette (source: HSO Brand Manual v3.0)

Names below match the brand manual exactly. The `--hso-navy` / `--hso-blue` / `--hso-coral` / `--hso-amber` aliases used in some legacy CSS are back-compat only — prefer the canonical names in new code.

| Brand-manual name | Hex | Plotly Python constant | Role in plotly diagrams |
|---|---|---|---|
| `hso-dark-blue` | `#00395F` | `HSO_DARK_BLUE` | Title text, axis text, node borders, anchor / total nodes |
| `hso-bluegreen` | `#079FC3` | `HSO_BLUEGREEN` | Categorical color 1 (default brand) |
| `hso-green` | `#00B294` | `HSO_GREEN` | Categorical color 2 — positive bars in waterfall |
| `hso-salmon` | `#F1554B` | `HSO_SALMON` | Categorical color 3 — negative bars in waterfall, emphasis bands |
| `hso-mimosa` | `#F2B949` | `HSO_MIMOSA` | Categorical color 4 — caution / external context |
| `hso-steel` | `#7F9CAF` | `HSO_STEEL` | Subtitle text, secondary nodes, dashed connectors |
| `hso-light-grey` | `#E3E3E3` | `HSO_LIGHT_GREY` | Treemap parent rectangles, subtle fills |
| `hso-web-grey` | `#ECEFF3` | `HSO_WEB_GREY` | Backdrop panels, grouping areas |
| `hso-canvas` | `#FDFCF7` | `HSO_CANVAS` | `paper_bgcolor` / `plot_bgcolor` (warm off-white, matches HSO slide masters) |
| `hso-text` | `#505050` | `HSO_TEXT` | Body text annotations |

**Default text color is ALWAYS `hso-dark-blue`.** Vary node / bar fill for emphasis, not text color.

**Color-ratio rule (brand manual §02).** White and `hso-dark-blue` always have a higher proportion than `hso-bluegreen`. Accent colors (`hso-green` / `hso-salmon` / `hso-mimosa`) are used sparingly — they appear on emphasis elements, never on body text or large background fills.

## Layout helper — required on every figure

Every diagram MUST end with:

```python
apply_hso_layout(
    fig,
    title="<bold one-line claim>",
    subtitle="<archetype + data scope>",
    width=1400,
    height=780,
)
```

This sets paper background, plot background, font family (`Segoe UI, sans-serif`), title / subtitle styling, and standard margins. Don't override `paper_bgcolor`, `plot_bgcolor`, or `font.family` per-figure — that's how diagrams drift out of family.

The helper lives in [`scripts/lib/hso_plotly.py`](../scripts/lib/hso_plotly.py) and is also inlined into each template so templates are copy-paste portable without an import path.

## Per-archetype recipes

All Python snippets below assume the helper has been imported / inlined and that `go = plotly.graph_objects`.

### Sankey (flow with proportional widths)

```python
fig = go.Figure(data=[go.Sankey(
    arrangement="fixed",                  # ALWAYS fixed; never let plotly auto-arrange
    node=dict(
        pad=30,
        thickness=26,
        line=dict(color=HSO_DARK_BLUE, width=1.5),
        label=labels,
        color=node_colors,
        x=node_x,                          # explicit x positions in [0.01, 0.99]
        y=node_y,                          # explicit y positions in [0.01, 0.99]
    ),
    link=dict(
        source=source,
        target=target,
        value=values,
        color=link_colors,                 # rgba strings; see below
    ),
)])
```

**Link colors — alpha pairs.** When one destination is "primary" and another is "secondary" (a deliberate visual hierarchy decision in the diagram's narrative), use `0.75` alpha for the primary flow and `0.35` for the secondary. Never both at the same alpha — the visual hierarchy disappears. Generate the rgba strings via `link_color(hex, alpha)` from the helper rather than hand-crafting them.

### Treemap (hierarchical area-by-value)

```python
fig = go.Figure(go.Treemap(
    labels=labels,
    parents=parents,
    values=values,
    marker=dict(
        colors=[HSO_BLUEGREEN, HSO_GREEN, HSO_SALMON, HSO_MIMOSA, HSO_STEEL],
        line=dict(color=HSO_DARK_BLUE, width=1.5),
    ),
    textfont=dict(family="Segoe UI, sans-serif", size=14, color="#FFFFFF"),
    branchvalues="total",
    pathbar=dict(visible=False),           # hide breadcrumb — adds noise
))
```

**One color per top-level branch.** Children inherit the parent color at lighter opacity (Plotly handles this automatically when colors are supplied at parent level). Don't give every leaf its own color — that defeats the visual hierarchy.

### Waterfall (variance bridge / start → adjustments → end)

```python
fig = go.Figure(go.Waterfall(
    name="",
    orientation="v",
    measure=measures,                       # ["absolute", "relative", "relative", ..., "total"]
    x=labels,
    y=values,
    textposition="outside",
    text=[f"${v:,.0f}" for v in values],
    connector=dict(line=dict(color=HSO_STEEL, dash="dot", width=1)),
    increasing=dict(marker=dict(color=HSO_GREEN, line=dict(color=HSO_DARK_BLUE, width=1))),
    decreasing=dict(marker=dict(color=HSO_SALMON, line=dict(color=HSO_DARK_BLUE, width=1))),
    totals=dict(marker=dict(color=HSO_DARK_BLUE, line=dict(color=HSO_DARK_BLUE, width=1))),
))

fig.update_yaxes(
    showgrid=True, gridcolor=HSO_LIGHT_GREY, zeroline=False,
    tickformat="$,.0f",
)
fig.update_xaxes(showgrid=False)
```

### Sunburst (hierarchical radial)

Same color rules as treemap. Use only when the hierarchy is ≤ 3 levels deep — beyond that the inner rings become unreadable.

### Funnel (stage-by-stage conversion)

```python
fig = go.Figure(go.Funnel(
    y=stages,
    x=values,
    textposition="inside",
    textinfo="value+percent initial",
    marker=dict(
        color=[HSO_DARK_BLUE, HSO_BLUEGREEN, HSO_GREEN, HSO_MIMOSA, HSO_SALMON],
        line=dict(color=HSO_DARK_BLUE, width=1),
    ),
    connector=dict(line=dict(color=HSO_STEEL, dash="dot", width=1)),
))
```

## Title and subtitle conventions

The `apply_hso_layout()` helper composes title + subtitle into a single `title.text` HTML string:

```
<b>{title}</b>
<span style='font-size:14px; color:#7F9CAF;'>{subtitle}</span>
```

Title rules:
- Bold, `hso-dark-blue`, 20 px, centered.
- One declarative claim — name what the diagram teaches, not what it is. ("Cost flow — collected → allocated → returned" beats "Sankey diagram of costs.")
- No "Figure 1 —" prefix; the embedding markdown / slide handles that.

Subtitle rules:
- `hso-steel`, 14 px, centered.
- Names the archetype + data scope in one phrase (e.g., "Illustrative quarterly data · three categories").
- ALWAYS marks illustrative data as such. ALWAYS cites the data source if real (e.g., "Q3 actuals · per <data source>").

## Sizes

| Use | Width × height |
|---|---|
| Reveal.js slide hero | 1400 × 780 (default) |
| Markdown deliverable inline | 1100 × 600 |
| PPTX slide background-fit | 1920 × 1080 (override only when the figure will be a full slide background) |
| Tall waterfall / many-step funnel | 1400 × 980 |

PNG renders at the same width × height by default; bump `scale=2` for print-quality output.

## Things to NEVER do

1. **Default Plotly template.** Plotly's default template (`plotly_white`, `simple_white`) has its own grid color, title font, and axis style — they all conflict with HSO. The helper sets `template="none"` so nothing competes with overrides.
2. **Continuous colorscales** (`viridis`, `plasma`, `RdYlBu`). Anti-brand. Use the categorical palette.
3. **Plot title via `fig.update_layout(title="...")` without the helper.** Loses the subtitle, the `hso-dark-blue` color, and the centered alignment.
4. **Auto-arrangement on Sankey.** `arrangement="snap"` (the default) crosses bands unpredictably. Always pin with `arrangement="fixed"` + explicit `x` / `y`.
5. **Ticks, gridlines, and axis lines on archetypes that don't need them.** Sankey, treemap, sunburst, funnel — none need axes. Waterfall needs only horizontal gridlines.
