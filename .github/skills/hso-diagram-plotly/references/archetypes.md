# Plotly Archetypes — When to Use Which

Five data-driven archetypes that warrant a Plotly diagram. If the idea doesn't fit one of these, either reshape the question or use a sibling diagram skill (drawio, excalidraw, reference-architecture).

## Sankey — flow with proportional widths

**Use when:** the story is "where do the values go from here." Width carries the meaning — wider band = more value.

**Good fits:**
- Volumetric distribution: collected total → allocated portions → end destinations.
- Cost flow: total spend → categories → subcategories.
- Conversion volume: stage 1 counts → stage 2 → stage 3.
- Energy / material flow in operations contexts.

**Bad fits (use a different archetype):**
- Org chart or hierarchy (use treemap or just a tree).
- Process steps without volumes (use process flow in drawio).
- Sequence of events over time (use timeline / waterfall).

**Pin nodes.** Always set `arrangement="fixed"` with explicit `x` / `y` — auto-arrangement crosses bands.

**Width hierarchy.** If the story has primary and secondary destinations, use 0.75 / 0.35 alpha pairs on link colors so the eye lands on the primary first.

## Treemap — hierarchical area-by-value

**Use when:** the data has a 2- or 3-level hierarchy and the story is relative magnitudes inside each branch.

**Good fits:**
- Category → subcategory → leaf, with values at the leaf level.
- Cost centers → cost types → vendors.
- Backlog volume by epic → feature.
- Defect counts by component → severity.

**Bad fits:**
- Time series (use waterfall or a line).
- Single-level breakdown (use a horizontal bar chart instead — treemap is overkill for one level).
- Hierarchies > 3 levels deep (text becomes unreadable; use sunburst or a tree diagram).

**One color per top-level branch.** Children inherit the parent color at lighter opacity. Don't give every leaf its own color — that defeats the visual hierarchy.

## Sunburst — hierarchical radial

**Use when:** treemap doesn't read well because branches are very uneven in size, OR when the radial / "pie + drilldown" aesthetic is specifically wanted.

**Good fits:**
- Same data shapes as treemap, but with one dominant top-level branch that would visually dwarf the others in treemap form.
- Composition / share-of-total breakdowns where the radial layout signals "100% total."

**Bad fits:**
- Hierarchies > 3 levels (inner rings become unreadable).
- Quantitative comparison between branches (humans compare rectangles more accurately than ring segments — prefer treemap).

## Waterfall — variance bridge / start → adjustments → end

**Use when:** the story is "started here, these things added/subtracted, ended there." Stepwise reasoning over a contiguous total.

**Good fits:**
- Period-close walk: starting balance → contributions → ending balance.
- P&L bridge: prior-period total → contributions per driver → current total.
- Forecast variance: budget → drivers of over/under → actual.
- Inventory walk: starting → in → out → ending.

**Bad fits:**
- Categorical breakdowns without a "starting" and "ending" anchor (use treemap or bar chart).
- More than ~12 steps (the bridge becomes unreadable; group steps or split into two).
- Trends over time (waterfall is event-driven, not time-series — use a line).

**Color rule.** Increases = `hso-green`, decreases = `hso-salmon`, totals = `hso-dark-blue`. Don't override per-bar; the waterfall trace types these natively.

## Funnel — stage-by-stage conversion

**Use when:** linear pipeline with monotonically decreasing volumes. The story is "drop-off at each stage."

**Good fits:**
- Pipeline / qualification: stage 1 → stage 2 → … → stage N.
- Customer journey volume: visited → activated → retained.
- Hiring funnel: applied → screened → interviewed → offered → accepted.
- Support: opened → triaged → resolved.

**Bad fits:**
- Non-monotonic counts (recovery, restored, returned — funnel can't show recovery).
- Branching journeys (use Sankey instead — funnel is single-track).
- Time on the x-axis (use a line; funnel is stage-on-y, not time-on-x).

**Show conversion %.** Use `textinfo="value+percent initial"` so each stage carries both the count and the conversion-from-top percent.

## Decision quick reference

```
Got values flowing somewhere?                  → Sankey
Got a 2-3 level hierarchy you want sized?      → Treemap
Got a hierarchy with one dominant branch?      → Sunburst
Got a "started → adjustments → ended" story?   → Waterfall
Got a pipeline that only loses volume?         → Funnel
Got something else?                             → Probably not plotly. Try drawio or excalidraw.
```

## Anti-pattern: forcing a story into the wrong archetype

Sankey + treemap + waterfall are visually distinctive — tempting to use for "any quantitative story." Resist. A Sankey of stages where nothing actually flows is a line chart with bad ergonomics. A treemap of two values is a bar chart with a worse aspect ratio. The archetype carries meaning; using the wrong one teaches the wrong story.
