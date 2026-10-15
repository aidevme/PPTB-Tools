---
title: "Reference architecture diagram - TTB layout coordinates"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, layout]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - TTB Layout

**TTB = top-to-bottom.** Audiences across the top, then a 3-column band below: AWS data estate on the left, Microsoft cloud platform in the center, integrations and external systems on the right.

## When to use TTB

- The slide above the diagram already has a heading; audiences need to register first.
- The platform is the "engine" with clear inputs (audiences) flowing in and outputs (data) flowing out to AWS / external.
- More than 5 personas - vertical stacking on the left (LTR) starts to dominate the canvas.
- The engagement story emphasizes a vertical user journey (top: who; middle: where; bottom: not used here, but legend / stamp).

## ASCII overview

```
+--------------------------------------------------------------------+ y=140
|  AUDIENCES                                                          |
|  [P1] [P2] [P3] | [P4] [P5] | [P6] [P7]                            |
|  group A         group B    group C                                 |
+--------------------------------------------------------------------+ y=370
                            |  arrows down to platform
+----------+-------------------------------+----------------+         y=400
| AWS      | MICROSOFT CLOUD - PLATFORM    | INTEGRATIONS   |
| (amber)  | (navy ribbon)                 | (label)        |
| --       | row 1: card  card             | --             |
| card     | row 2:    card                | card           |
| card     | row 3: card  card  card       | card           |
| card     | --- Azure subscription ---    | card           |
| card     | Fn   Bus   Fabric             | card           |
+----------+-------------------------------+----------------+         y=1080
+--------------------------------------------------------------------+
| Legend swatches                                  Rev stamp          |
+--------------------------------------------------------------------+ y=1190
```

## Canvas

| Property | Value |
|---|---|
| viewBox | `0 130 1920 1060` |
| width | 1920 |
| height | 1060 |
| background | `#FDFCF7` |

## Audiences band (y = 140 - 370)

7 cards in a horizontal row. Card width 240, height 145.

| Group | Cards | x-coords | Gap to next |
|---|---|---|---|
| Group A (e.g., Field Users) | P1, P2 | 60, 315 | 30 px to Group B |
| Group B (e.g., Customers) | P3, P4, P5 | 600, 855, 1110 | 30 px to Group C |
| Group C (e.g., Corporate) | P6, P7 | 1395, 1650 | (right edge) |

Intra-group gap: 15 px. Inter-group gap: 30 px. Adjust the count per group as needed; recompute by walking left-to-right with these gap rules.

Each card:

```
<rect x=PX y=160 w=240 h=145 rx=8 fill="#FFFFFF" stroke="#E3E3E3" filter="url(#cardShadow)"/>
<rect x=PX y=160 w=240 h=8  fill="<group color>"/>   <!-- top stripe -->
<use href="#icXxx" x=PX+16 y=180 width=40 height=40/>
<text x=PX+70 y=205 class="persona-n">Name</text>
<text x=PX+70 y=228 class="persona-r">Role / description</text>
<text x=PX+70 y=246 class="persona-r">Continued description</text>
```

Group sub-headings (above the cards, at y=155): `class="zone-lbl" fill="#00395F"`.

## Middle 3-column band (y = 400 - 1080)

### AWS column (left)

| Property | Value |
|---|---|
| Outer zone x, y | 40, 410 |
| Outer zone w, h | 340, 670 |
| Outer fill | `#FFF8E1` |
| Outer stroke | `#E09900` 2 px |
| Filter | `url(#zoneShadow)` |
| Top ribbon | x=40 y=410 w=340 h=46, fill `#FFC400` |
| Ribbon text | "AWS DATA ESTATE", class `ribbon-amber` |
| Inner cards | 4 stacked, each 300 wide, 110 tall |
| Inner card x | 60 |
| Inner card y | 480, 645, 810, 975 (gap 55 px) |

Inner card height of 110 + gap of 55 = 165 px row pitch. Four rows = 660 px, fits within outer 670 - ribbon 46 - bottom padding ~14.

### Platform column (center)

| Property | Value |
|---|---|
| Outer zone x, y | 500, 410 |
| Outer zone w, h | 920, 670 |
| Outer fill | `#F7FAFC` |
| Outer stroke | `#079FC3` 2 px |
| Filter | `url(#zoneShadow)` |
| Top ribbon | x=500 y=410 w=920 h=50, fill `#00395F` |
| Ribbon text | "MICROSOFT CLOUD - THE PLATFORM", class `ribbon-t` |

Internal 4-row layout:

| Row | y | Contents | Card sizing |
|---|---|---|---|
| 1 | 480 | 2 cards: Power Apps, Customer Portal | w=420 h=120, x=520 and x=960 |
| 2 | 615 | 1 card: Dataverse (full-width) | w=860 h=120, x=520 |
| 3 | 750 | 3 cards: D365 FS, Power Automate, Copilot/Agents | w=270 h=120, x=520 / x=820 / x=1120 |
| 4 | Azure sub-zone | sub-zone x=520 y=890 w=860 h=180 | Inner: 3 cards 270 wide each |

Azure sub-zone:

```
<rect x=520 y=890 w=860 h=180 rx=12 fill="#E8F1FA" stroke="#0062AD" stroke-width=1.5/>
<rect x=520 y=890 w=860 h=42  fill="#0062AD"/>
<text class="ribbon-t" x=950 y=918 text-anchor="middle">AZURE SUBSCRIPTION</text>
<!-- 3 inner cards: Functions / Service Bus / Fabric Link -->
```

Inner cards inside sub-zone: x = 540, 820, 1100; y=950; w=260; h=110.

### External column (right)

| Property | Value |
|---|---|
| Outer zone | (no outer zone - cards directly on canvas) |
| Cards | 4 stacked, each 300 wide, 140 tall |
| Card x | 1540 |
| Card y | 410, 575, 740, 905 (gap 25 px) |

Each card represents a category with stacked sub-items: Data warehouse / Payments / ERP / Telephony (CTI). Use `card-h-s` for sub-item headers when stacking.

## Channels (between zones)

| Channel | x range | Width |
|---|---|---|
| AWS <-> Platform | 380 - 500 | 120 px |
| Platform <-> External | 1420 - 1540 | 120 px |

Flow labels (`class="flow-lbl"`) live in these channels. For 120 px width at font 14 (~8.4 chars), use multi-line labels (one word per line) when needed.

## Persona arrow targets on platform top

7 audiences entering the platform top edge (y=410). Distribute entries evenly. Pre-computed defaults for 7 audiences:

```
x = 540, 615, 690, 945, 1215, 1290, 1370
```

These are NOT evenly spaced - they cluster slightly under each audience's center but offset to avoid bunching at the platform edge. Recompute per engagement using:

```
x_target = clamp(persona_x_center, platform_left + 40, platform_right - 40)
```

If two targets land within 60 px of each other, shift one by +/- 40 px.

## Legend band (y = 1100 - 1190)

```
<line x1=60 y1=1100 x2=1860 y2=1100 stroke="#E3E3E3"/>
<!-- color swatches at y=1130 -->
<!-- stamp at x=1860 y=1170 text-anchor="end" class="stamp" -->
```

Legend entries are short colored line segments (12 px) followed by `class="legend-t"` text describing the role of the color. Include EVERY arrow color used in the body.
