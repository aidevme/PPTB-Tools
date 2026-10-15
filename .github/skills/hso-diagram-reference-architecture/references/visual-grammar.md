---
title: "Reference architecture diagram - visual grammar"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, palette, styling]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - Visual Grammar

The canonical visual language for hand-coded reference architecture SVGs produced by this skill. Every diagram in this family - across engagements - reuses these classes, colors, and conventions verbatim. Consistency across decks is the point.

## HSO palette

| Hex | Role | Example usage |
|---|---|---|
| `#00395F` | Primary stroke / navy ribbons / card headers | Dataverse card header text, top ribbon fill, default card border |
| `#079FC3` | Standard interactive arrow / accent fill | Persona icon body, "user -> app" arrows, accent card fill |
| `#00B294` | Success / green secondary | Reserve for status indicators; rarely used in reference architecture |
| `#F1554B` | Coral - emphasis | Emphasized persona's arrow color, 3 px coral border on emphasized card |
| `#E09900` | Amber - bulk analytical feed | Dataverse/Fabric -> AWS or other warehouse arrows |
| `#635BFF` | Stripe purple - payment processor | Payment-processor transaction arrows |
| `#2CA01C` | QuickBooks green - ERP / accounting | ERP / accounting integration arrows |
| `#7F9CAF` | Steel - muted text / dashed optional arrows | Card sub-text, zone labels, dashed reference arrows |
| `#FDFCF7` | Canvas | Background rectangle |
| `#F7FAFC` | Microsoft zone fill | Outer zone of the platform column |
| `#FFF8E1` | AWS zone fill | Outer zone of the AWS column |
| `#E3E3E3` | Default card border | 1 px stroke on standard audience and external cards |
| `#3D2A00` | Amber-ribbon text | Dark brown text on amber AWS ribbon for contrast |

## CSS classes

All declared in `templates/defs-block.svg`. Copy verbatim; do not re-author.

| Class | Style | Role |
|---|---|---|
| `.title` | 36 px bold navy `#00395F` | Diagram title (rarely embedded; usually external slide title) |
| `.subtitle` | 18 px gray `#737373` | Diagram subtitle (rarely embedded) |
| `.zone-lbl` | 15 px bold steel `#7F9CAF` uppercase letter-spacing 3 | Zone labels above sections (e.g., "AUDIENCES", "MICROSOFT CLOUD - THE PLATFORM"). Override `fill` to navy `#00395F` for emphasized zone labels. |
| `.ribbon-t` | 16 px bold white uppercase letter-spacing 3 | Text on dark ribbons (navy platform top ribbon, blue Azure sub-zone ribbon) |
| `.ribbon-amber` | 16 px bold dark-brown `#3D2A00` uppercase letter-spacing 3 | Text on amber AWS ribbon (white text doesn't pass contrast on amber) |
| `.card-h` | 22 px bold navy | Primary card headers (Dataverse, D365 FS, Power Apps, Power Automate) |
| `.card-h-s` | 19 px bold navy | Secondary card headers (smaller cards stacked in a category) |
| `.card-p` | 15 px gray `#505050` | Card description / body lines |
| `.card-s` | 14 px steel `#737373` | Card sub-text / footnotes |
| `.persona-n` | 18 px bold navy | Persona name |
| `.persona-r` | 12 px gray | Persona description (originally 14 px; reduced to 12 for narrower cards) |
| `.flow-lbl` | 14 px bold dark-gray `#4A4A4A` | Labels on connection arrows |
| `.emph` | 13 px bold coral `#F1554B` uppercase letter-spacing 2 | Emphasis badge. Deprecated in TTB layout - the 3 px coral border now conveys emphasis without the redundant text. |
| `.legend-t` | 14 px gray | Legend entries |
| `.badge-t` | 14 px bold white | Pill badges (e.g., "x 10 brands") |
| `.stamp` | 13 px italic steel | Bottom-right rev stamp |

## Arrow color semantics

Each color has ONE role. Never reuse a color for an unrelated concept; the legend depends on this contract.

| Color | Hex | Role | Marker id |
|---|---|---|---|
| Coral | `#F1554B` | Emphasized UX (the most-emphasized persona's arrow into the platform) | `arrCoral` |
| Blue | `#079FC3` | Standard interactive user -> app | `arrBlue` |
| Amber | `#E09900` | Bulk analytical feed (typically Dataverse/Fabric -> AWS or other warehouse) | `arrAmber` |
| Stripe purple | `#635BFF` | Payment-processor transactions | `arrPurple` |
| QB green | `#2CA01C` | ERP / accounting integrations | `arrGreen` |
| Steel (dashed) | `#7F9CAF` | Optional / event-driven / reference relationships (`stroke-dasharray="6,4"`) | `arrSteel` |
| Navy | `#00395F` | Ribbons, primary strokes. NOT used for arrows in this diagram family. | (none) |

All arrows use `stroke-width="2.5"`. Emphasis is conveyed by COLOR, never by thickness, because arrow markers scale with stroke under the default `markerUnits="strokeWidth"` and unequal markers look broken (see review-checklist row 5).

## Connector geometry

Color says what an arrow *means*; geometry says whether the reader believes it. Four rules, in the order they bite. Rows referenced are in [review-checklist.md](review-checklist.md).

**1. A turn is information — spend it only when earned.** If source and target share a centreline, the arrow is STRAIGHT on that centreline:

| Relationship | Arrow |
|---|---|
| Same lane / row (side by side) | Horizontal, on the lane's vertical centre |
| Same column (stacked) | Vertical, on the column's horizontal centre |
| Different lane AND different column | Right-angle elbow — the only case that turns |

A dogleg between two boxes that visibly line up makes the reader hunt for the obstacle being avoided. When several arrows enter one box on the same centreline from opposite sides, the shared line reads as a single clean spine — that is the intended effect, not a collision (row 17).

**2. The long leg goes last.** An elbow's final segment carries the arrowhead, so it must be the long one. The reverse — short final leg — is the single most common cause of a marker that bleeds back over its own corner (row 2).

**3. Marker length is computed, never assumed.** Under the default `markerUnits="strokeWidth"`, marker length = `markerWidth` x `stroke-width`. At the house stroke of 2.5 with `markerWidth="10"` that is ~25 px, which is where the ">= 30 px final leg" figure in row 2 comes from. Deviate from stroke 2.5 and the number moves with it — recompute rather than copying it across.

**4. Heads stop short of the target.** End every path a fixed clearance (4-6 px) before the target's edge so the head reads as an arrival, not a collision — and keep that clearance identical across the whole diagram (row 18).

## Audience card archetypes

| Archetype | Border | Top stripe | Use |
|---|---|---|---|
| **Standard** | 1 px `#E3E3E3` | 8 px coloured top stripe (color matches persona group: navy / blue / amber / steel) | Default audience card |
| **Emphasized** | 3 px coral `#F1554B` | None - color alone signals emphasis | The single most-important persona for the engagement story |

In the LTR layout the original implementation also used a separate `.emph` badge ("EMPHASIZED" text). In TTB this is dropped - the border is sufficient signal. Do not add the badge back.

## Card-internal layout (icon + header + body)

This is the ONE convention used by every component card across all zones (Microsoft platform, AWS column, External integrations, Azure subzone, Power Platform row). Every card follows the same shape so the eye doesn't have to retrain on each zone.

```
+---------------------------------------------+
|                                             |
|  [icon]   Header                            |
|  40-64    sub-header (optional, smaller)    |
|  pixels                                     |
|                                             |
|           Body line 1                       |
|           Body line 2                       |
|           Body line 3                       |
|                                             |
+---------------------------------------------+
```

- **Icon**: at `card_left + 12 px`, vertically near the top (e.g., `card_top + 12 px`). Size 40-64 px depending on card height.
- **Header**: at `icon_right + 8 px` (so header sits beside the icon, not below it). Class: `card-h` (22 px) for primary cards, `card-h-s` (19 px) for compact / secondary cards.
- **Sub-header** (optional, e.g. "/ Synapse Link" under "Fabric Link"): at the SAME x as the header, ~18 px below the header baseline. Class: `card-s`.
- **Body lines**: at the **SAME x as the header** (NOT at the icon's x). Stacked vertically below the header / sub-header / icon area. Class: `card-p` (15 px) for description, `card-s` (14 px) for footnotes / annotations.

The critical rule: **body text x = header text x**, NOT icon x. Putting body text at the icon's left edge produces a "wraparound" look that breaks visual rhythm. See review-checklist row 15 for the failure mode.

### Vertical spacing — the 24/20 rule (canonical)

This spacing is the AWS-column template. Apply it across every component card in every zone:

| Element pair | Gap |
|---|---|
| Header baseline → body line 1 baseline | **24 px** |
| Body line N baseline → body line N+1 baseline | **20 px** |
| Header baseline → sub-header baseline (when sub exists) | 18-20 px |
| Sub-header baseline → body line 1 baseline | 22 px |
| Card top edge → header baseline (top padding) | 30-35 px |
| Last body line baseline → card bottom edge | ≥ 15 px |

**Why these numbers:** the AWS column cards (Power BI / Redshift / Databricks / S3) were tuned to fit a 19-px header + two body lines (15 + 14 px) inside a 110-px card with breathing room. They are the visual reference for every other card in the diagram. Reusing the same gaps everywhere is what makes the diagram scan as a single document instead of three loose collages.

**Tight cards with 4+ body lines** (e.g., Azure Functions with four list items): keep the 24 px header→body1 gap, then tighten subsequent line spacing to 14 px (instead of 20). Do not compress the header→body1 gap — that's the gap the eye uses to separate "what this is" from "what it does".

Worked example — three Azure Functions list items in a 110-px card with header at y=978:

```
y=978   Azure Functions     <- card-h-s (header)
y=1002  · NetSuite Sync     <- 24 px below header
y=1016  · Payment Gateway   <- 14 px below previous (tight, 4-line layout)
y=1030  · QuickBooks Sync   <- 14 px below previous
y=1044  · Royalty calc      <- 14 px below previous
```

The opposite — header→body1 tight (e.g., 15 px) makes the title look like it's running into the body. The far-too-loose case (e.g., 33-50 px) makes the title look orphaned. Both were observed in early drafts of a prior client engagement; the 24/20 standard fixed both.

When the body has more lines than the icon's vertical extent (e.g., a 4-item list under a 40-px-tall icon), the body still starts at header-x — it does not "reclaim" the space under the icon. Whitespace under the icon is the cost of consistency.

## Card heights at a glance

Tuned to leave enough vertical room for arrows to develop a visible shaft (review-checklist row 10).

| Card | Height | Typical width | Notes |
|---|---|---|---|
| Audience compact (TTB) | 145 px | 240 px | 7 cards in a horizontal band |
| Audience standard (LTR) | 110 px | 340 px | Stacked vertically on the left |
| AWS column compact (TTB) | 110 px | 300 px | 4 cards stacked; gaps ~55 px so amber arrows have shaft |
| External integration card | 140 px | 260-300 px | 4 cards stacked on the right |
| Microsoft platform inner card | 110-130 px | varies by row | Tighter heights leave room for inter-row arrows |
| Azure subscription inner card | 100 px | 180 px | 3 cards (Functions / Service Bus / Fabric Link) inside sub-zone |

## Ribbon and zone styling

| Element | Spec |
|---|---|
| Outer zone (any) | `rx="20"`, 2 px stroke, `filter="url(#zoneShadow)"` |
| Microsoft zone fill | `#F7FAFC`, stroke `#079FC3` |
| AWS zone fill | `#FFF8E1`, stroke `#E09900` |
| Top ribbon (Microsoft) | 50 px tall, top corners only rounded, fill `#00395F`, ribbon-t text centered |
| Top ribbon (AWS) | 46 px tall, top corners only rounded, fill `#FFC400`, ribbon-amber text centered |
| Azure sub-zone ribbon | 42 px tall, fill `#0062AD`, ribbon-t text |

To achieve "rounded top corners only" use a `<rect>` with `rx` and overlay a non-rounded rect on the bottom half, OR use a `<path>` with explicit corner radii. The implementations in `examples/` use the path approach.

## Card body styling

| Element | Spec |
|---|---|
| Card rect | `rx="8"`, `fill="#FFFFFF"`, `stroke="#E3E3E3"` 1 px (or 3 px coral for emphasized), `filter="url(#cardShadow)"` |
| Card top stripe | 8 px height, `rx="8"` with bottom corners squared via overlay, color matches persona group |
| Inner icon | 40-64 px square, anchored top-left or top-center of card |
| Inner icon dark backgrounds | Vendor-tinted (e.g., Stripe purple, Databricks red) - see icon-catalog.md |

## Legend conventions

The legend MUST list every arrow color used in the body. If you used amber, amber is in the legend. Standard layout:

- Horizontal divider line (`stroke="#E3E3E3"` 1 px) above the legend.
- Color swatch (12 px line segment with marker) followed by `.legend-t` description.
- Bottom-right stamp: `class="stamp"` with content `Rev YYYY-MM-DD | Author | variant` (variant = LTR or TTB).
