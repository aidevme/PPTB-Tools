---
title: "Reference architecture diagram - review checklist"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, presales, review]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - Review Checklist

## Why this checklist exists

A layout error in a hand-coded SVG reference architecture costs FAR more to fix later than to catch in a single review pass. Layout problems compound: a wrong placement causes arrow detours, detours cause crossings, crossings cause confusion, and the user ends up sending a screenshot annotated with red circles. Running this checklist top-to-bottom before handing the diagram back is the cheapest path to a clean result.

The categories below were extracted from a real engagement after iterating through six rounds of "looks good - oh wait" feedback. Every row is a class of mistake that was actually shipped, caught, and fixed.

## Run order

Review categories in priority order. Each category, fully resolved, eliminates a whole class of downstream issues:

1. **Layout placement** - is each card in the right zone, in the right order? Fix this first; everything else routes around it.
2. **Arrow geometry** - shaft visible, tip orthogonal, no diagonals, no bunching, no crossings on the same side.
3. **Text fit** - all text inside its card, no overflow, no truncation.
4. **Labels** - flow labels in clear channels, not overlapping arrows or boxes.
5. **Polish** - color consistency, stamp present, legend complete.

Do NOT re-route an arrow around a layout mistake. Fix the layout.

## The checklist

| # | Issue | Symptom | Root cause | Fix |
|---|---|---|---|---|
| 1 | **Layout-induced crossings** | Long detour arrows cross each other | Wrong placement, not wrong routing | Fix layout placement FIRST; never re-route around a layout mistake |
| 2 | **Tip-only arrows** | Marker bleeds back into prior segment; no visible shaft | Final segment shorter than marker length (~25 px at stroke 2.5 with default `markerUnits="strokeWidth"`) | Lengthen final segment to >= 30 px, OR shrink adjacent boxes so the gap between them grows (row 10). **Route so the LONG leg is last** — an elbow whose final leg is the short one is the usual cause. **The 30 px is derived, not universal:** marker length = `markerWidth` x `stroke-width` under the default `markerUnits="strokeWidth"`, so recompute whenever you leave the house stroke of 2.5 (at `markerWidth="6"` / stroke 1.75 the marker is only ~10 px and >= 16 px suffices). Rule of thumb: final leg >= 1.5x marker length |
| 3 | **Side-attached tip** | Arrowhead orientation looks rotated / line enters tip at an angle | Final segment isn't orthogonal to arrowhead | Make the final segment straight V or H (no diagonal endings) |
| 4 | **Bunched arrows** | Two arrow entries within ~15 px on a target's edge | All arrow paths use raw card centers | Distribute entries evenly across the target's edge (compute spacings; mid-cluster ~70-80 px apart) |
| 5 | **Inconsistent tip size** | One arrow's tip larger than others | Different stroke widths under default `markerUnits="strokeWidth"` (marker scales with stroke) | Use same stroke width across all arrows (typically 2.5); express emphasis in COLOR not thickness |
| 6 | **Crossing right-angle arrows on same side** | Two L-shapes interlock between the same source band and target | Same-side outliers without staggered y on the horizontal segments | Stagger y so the outer arrow's horizontal is BELOW the inner arrow's vertical end (geometrically: outer horizontal y > inner final-vertical-start y) |
| 7 | **Diagonal arrow** | Path angles across a section | Lazy single-segment routing | Use right-angle V/H/V - diagonals are only acceptable when the user explicitly authorizes them |
| 8 | **Text overflows card** | Last word touches or passes the right edge | Line length > text-budget at given font size | Shorten / wrap, OR reduce persona-r font from 14 -> 12 px (gives ~28 chars per 180 px budget) |
| 9 | **Label overlaps arrow** | Label baseline within ~5 px of an arrow line | Tight placement | >= 8 px clearance from any arrow; for narrow channels use multi-line labels (one word per line) |
| 10 | **Boxes-too-tall, arrows-too-short** | Inter-card gap < marker length -> just markers, no shaft | Default card heights with default gaps | Shrink card heights by 30-40 px; redistribute freed space into gaps >= 50 px |
| 11 | **Label overlaps box edge** | Text in a channel runs onto the adjacent zone | Label x not constrained to channel width | Compute channel width (target_left - source_right); place label x within it; multi-line if too narrow |
| 12 | **Redundant text** | "Called from Azure Fn" text inside a box that already has a green arrow from Azure Fn | Duplication of arrow semantic in body text | Drop the text; the arrow's color and direction already encode the relationship |
| 13 | **Multi-arrow shared source ordering mismatch** | Three arrows from one card (e.g., Azure Functions has arrows to NetSuite, Payment, QBO) cross each other in the channel | Source rows are listed in arbitrary order, not in destination y-order | **Order source rows top-to-bottom to match destination y-order top-to-bottom.** The row whose target is highest gets the topmost source y. The arrow with the LONGEST run (furthest target) uses the INNERMOST vertical (closest to source); shortest run uses the OUTERMOST vertical. This makes the arrows fan out without crossing. |
| 14 | **Multi-arrow shared source uneven spacing** | Three arrows from one card emerge bunched or with random spacing | Designer used arbitrary y values for source rows and arbitrary x values for verticals | Use EQUAL vertical spacing between source y's (e.g., 14 px between adjacent rows) AND EQUAL horizontal spacing between vertical x's (e.g., 10 px between adjacent verticals). The arrows form a clean parallel "fan" before diverging at their final approach. Combined with rule #13, this produces a textbook clean multi-arrow exit. |
| 15 | **Inconsistent card-internal layout (x alignment)** | Some cards in the same zone have body text aligned with the header (right of icon); others have body text at the icon's left edge (under the icon). The mixed indentation creates visual noise. | Designer copied templates from different sources, or laid out body text using the icon's x as the anchor instead of the header's x | Pick ONE convention per zone and stick to it. The HSO standard: icon at card_left + 12 px; header text at icon_right + 8 px (so header sits beside the icon); body text at the SAME x as the header (under the header, NOT under the icon). When in doubt, body-text-x equals header-text-x. Walk every card in a zone and confirm body-text-x is consistent. See `references/visual-grammar.md` § "Card-internal layout". **⚠ When you APPLY this rule (move body from icon-x to header-x), the available text-width budget shrinks by ~50-60 px** (header-x − icon-x). You MUST re-run rule #8 (text overflow) on every card you adjusted; lines that fit the wider icon-x budget may now overflow the narrower header-x budget. A prior client engagement shipped a "Stripe · Authorize.Net · CyberSource" line that fit at icon-x and overflowed at header-x because this re-audit was skipped. |
| 16 | **Inconsistent header→body vertical gap** | One card has the body crammed 15 px under the header, another has the body floating 35-50 px below — title looks orphaned in some, suffocating in others | Each card was laid out independently; no canonical spacing | Apply the AWS-column template uniformly: **header → body1 = 24 px, body line spacing = 20 px** (tight 14 px only when 4+ body lines force it). The 24-px gap separates "what this is" from "what it does"; do not compress it for any card. Walk every card in every zone and confirm gaps. See `references/visual-grammar.md` § "Vertical spacing — the 24/20 rule". |
| 17 | **Gratuitous jog between aligned boxes** | Two boxes that visibly line up are joined by a stepped arrow. The dogleg reads as meaningful — "it had to route around something" — when nothing is being avoided, so the reader looks for an obstacle that isn't there | A blanket "always turn" habit, or an offset added to dodge a neighbour that later moved | **If source and target share a centreline, the arrow is STRAIGHT on that centreline.** Same lane / row -> horizontal on the lane's vertical centre. Same column -> vertical on the column's horizontal centre. Reserve turns for genuinely diagonal handoffs (different lane AND different column). A turn carries information; spend it only when the geometry earns it. Corollary: when several arrows enter the same box on the same centreline from opposite sides, that shared line reads as one clean spine — a virtue, not a collision |
| 18 | **Head buried in the target border** | Arrowhead sits on, or just inside, the target's stroke. Reads as a collision rather than an arrival, and at deck scale the tip merges into the border and disappears | Path terminated exactly at the target's edge coordinate | End every path a **fixed clearance** short of the target edge — 4-6 px is enough at any stroke weight. Apply the same clearance at the source where a line would otherwise emerge from a border. Keep the value constant for the whole diagram: an uneven gap reads as sloppy alignment, which is worse than no gap at all |

## Self-review protocol

This checklist is YOUR responsibility, not the user's. The user's time is better spent on architectural correctness, not catching arrow tips that disappear under their own marker. Steps:

1. Render the SVG to PNG with `scripts/render-svg.mjs`.
2. Open the PNG visually (use the Read tool on the PNG path; Claude Code displays images inline).
3. Walk through the checklist top to bottom. Annotate each row pass/fail in your scratchpad.
4. FIX every failing row in the SVG source. Do not skip rows because "the user probably won't notice."
5. **Re-walk the checklist after EVERY fix.** This is the rule new contributors break most often. Fixing rule #N can re-introduce rule #M. Examples observed in real engagements:
   - Applying rule #15 (move body to header-x) shrinks the text-width budget and can re-introduce rule #8 (text overflow). Always re-run rule #8 on every card touched by rule #15.
   - Applying rule #10 (shrink card height) can re-introduce rule #2 (tip-only arrows) on adjacent arrows whose final segment was sized for the old card geometry. Re-run rule #2 on every arrow that touches a resized card.
   - Reordering a list inside a card (rules #13/#14) changes arrow source y's; verify every arrow still has correct source y AND lengthen any final segment that became too short.
   - **Rule of thumb**: any structural fix (size, position, reorder, alignment) invalidates downstream geometry checks. Re-run the WHOLE checklist after each, not just the row you fixed.
6. Re-render and re-walk the checklist.
7. Hand the diagram back ONLY when every row passes — and the FINAL render-and-walk pass is clean (i.e., the last fix didn't introduce a new violation).

If you discover a recurring class of issue not yet on the checklist, add it. The checklist is the IP of this skill.

## Geometry helpers

Cheat sheet for arrow and text math:

- **Marker length at stroke S** = ~10 * S (default `markerUnits="strokeWidth"`). At stroke 2.5, marker length ~ 25 px. To pin the marker size regardless of stroke, use `markerUnits="userSpaceOnUse"` on the marker.
- **L-shape minimum final segment for clean tip** = marker length + 5 px clearance. At stroke 2.5: final segment >= 30 px.
- **Text width estimate at font F px** = ~0.55 * F * char_count (proportional fonts). For monospaced safety: 0.6.
  - At persona-r 14 px: 180 px budget = ~21 chars.
  - At persona-r 12 px: 180 px budget = ~28 chars.
  - At card-p 15 px: 280 px budget = ~33 chars.
- **Even spacing of N arrows across W px**: spacing = W / (N + 1); first entry at left + spacing. Example: 5 arrows across 800 px -> spacing 133, entries at +133, +266, +400, +533, +667.
- **Stagger heuristic for two same-side L-shapes**: outer L horizontal y - inner L final-vertical-start y >= 20 px to avoid visual interlock.
- **Multi-arrow exit fan-out from a shared source** (rules #13 + #14):
  - Order source rows top-to-bottom to match destination y-order top-to-bottom.
  - Arrow with LONGEST run (furthest destination) -> INNERMOST vertical (closest to source).
  - Arrow with SHORTEST run (nearest destination) -> OUTERMOST vertical (farthest from source).
  - Source y spacing: equal (e.g., 14 px between adjacent rows in the same card).
  - Vertical x spacing: equal (e.g., 10 px between adjacent verticals).
  - Worked example with three arrows from one card to three external targets (top to bottom: A, B, C with target y_A < y_B < y_C):
    ```
    source_card.right_edge_x = 1390;       channel between source card and target column
    target_left_x = 1540;
    source_y:    A -> 1014, B -> 1028, C -> 1042   (14 px apart, A on top)
    vertical_x:  A -> 1490, B -> 1500, C -> 1510   (10 px apart, A innermost)
    target_y:    A -> 695,  B -> 855,  C -> 995    (matches source order)
    paths:
      A: M 1390 1014  L 1490 1014  L 1490 695  L 1540 695
      B: M 1390 1028  L 1500 1028  L 1500 855  L 1540 855
      C: M 1390 1042  L 1510 1042  L 1510 995  L 1540 995
    ```
    Result: three parallel verticals through the channel, fanning out only at their final horizontal approach. Zero crossings.
