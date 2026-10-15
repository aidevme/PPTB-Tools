---
title: "Reference architecture diagram - LTR layout coordinates"
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

# Reference Architecture Diagram - LTR Layout

**LTR = left-to-right.** Personas on the left, Microsoft cloud platform in the middle, integrations and external systems on the right. The traditional system-context arrangement: data flows left to right.

## When to use LTR

- Traditional system context diagram convention - readers expect L -> R data flow.
- Fewer personas (3-6) where vertical stacking on the left fits the canvas.
- Engagement story is "users -> the platform -> downstream systems".
- Slides are landscape-oriented and the diagram is the only content (no heading band needed).

## ASCII overview

```
+----------+-------------------------------+--------------------+   y=130
| PERSONAS | MICROSOFT CLOUD - PLATFORM    | INTEGRATIONS       |
| group A  | row 1: card  card             | DATA ESTATE        |
| [P1]     | row 2:   card                 | card               |
| [P2]     | row 3: card  card  card       | card               |
| ---      | --- Azure subscription ---    | PAYMENTS           |
| group B  | Fn   Bus   Fabric             | card               |
| [P3]     |                               | ERP                |
| [P4]     |                               | card  card         |
| group C  |                               | TELEPHONY          |
| [P5]     |                               | card               |
+----------+-------------------------------+--------------------+   y=970
+----------------------------------------------------------------+
| Legend swatches                              Rev stamp          |
+----------------------------------------------------------------+   y=1080
```

## Canvas

| Property | Value |
|---|---|
| viewBox | `0 130 1920 950` |
| width | 1920 |
| height | 950 |
| background | `#FDFCF7` |

## Personas column (left)

| Property | Value |
|---|---|
| x | 40 |
| Width | 340 |
| y range | 160 - 950 |

Cards stacked vertically, grouped by audience type (e.g., Field Users, Customers, Corporate). Each group preceded by a `class="zone-lbl" fill="#00395F"` sub-heading. Card spec:

```
<rect x=40 y=GY w=340 h=110 rx=8 fill="#FFFFFF" stroke="#E3E3E3" filter="url(#cardShadow)"/>
<rect x=40 y=GY w=340 h=8  fill="<group color>"/>   <!-- 8 px top stripe -->
<use href="#icXxx" x=56 y=GY+22 width=48 height=48/>
<text x=120 y=GY+40 class="persona-n">Name</text>
<text x=120 y=GY+60 class="persona-r">Role / description</text>
<text x=120 y=GY+78 class="persona-r">Continued description</text>
```

Inter-group gap: 30 px (with sub-heading at gap top). Intra-group gap: 15 px.

Emphasized card: 3 px coral border (`stroke="#F1554B" stroke-width="3"`), no top stripe.

## Microsoft platform column (center)

| Property | Value |
|---|---|
| Outer zone x, y | 440, 160 |
| Outer zone w, h | 780, 790 |
| Outer fill | `#F7FAFC` |
| Outer stroke | `#079FC3` 2 px |
| Filter | `url(#zoneShadow)` |
| Top ribbon | x=440 y=160 w=780 h=50, fill `#00395F` |
| Ribbon text | "MICROSOFT CLOUD - THE PLATFORM", class `ribbon-t` |

Internal layout (taller than TTB - room for 4 rows):

| Row | y | Contents | Card sizing |
|---|---|---|---|
| 1 | 230 | 2 cards: Power Apps, Customer Portal | w=360 h=120, x=460 / x=840 |
| 2 | 365 | 1 card: Dataverse (full width) | w=740 h=120, x=460 |
| 3 | 500 | 3 cards: D365 FS, Power Automate, Copilot/Agents | w=240 h=120, x=460 / x=720 / x=980 |
| 4 | Azure sub-zone | x=460 y=635 w=740 h=290 | 3 inner cards |

Azure sub-zone:

```
<rect x=460 y=635 w=740 h=290 rx=12 fill="#E8F1FA" stroke="#0062AD" stroke-width=1.5/>
<rect x=460 y=635 w=740 h=42  fill="#0062AD"/>
<text class="ribbon-t" x=830 y=663 text-anchor="middle">AZURE SUBSCRIPTION</text>
<!-- 3 inner cards: Functions / Service Bus / Fabric Link -->
```

Inner cards: x=480, 720, 960; y=695; w=220; h=210.

## External column (right)

| Property | Value |
|---|---|
| x | 1300 |
| Width | 580 |
| y range | 160 - 950 |

Cards grouped by category, with `class="zone-lbl"` sub-headings:

| Category | Typical cards |
|---|---|
| DATA ESTATE | AWS, Databricks, S3, Redshift |
| PAYMENTS | Stripe (or other processor) |
| ERP | NetSuite, Sage Intacct, QuickBooks |
| TELEPHONY (CTI) | Five9, Genesys, etc. |

For multi-card categories use a horizontal pair (2 cards across 580 px wide column = 280 wide each). Use `card-h-s` (19 px) for these sub-headers - more cards per column.

## Channels (between zones)

| Channel | x range | Width |
|---|---|---|
| Personas <-> Platform | 380 - 440 | 60 px |
| Platform <-> External | 1220 - 1300 | 80 px |

LTR channels are NARROWER than TTB. Use single-word multi-line labels for flow text. If a label needs more than ~8 chars, break it into two lines stacked vertically.

## Arrow target distribution

- Persona arrows enter the platform LEFT edge at varying y values - distribute evenly across the platform's vertical span.
- Platform <-> External arrows exit the platform RIGHT edge at varying y values matched to external category positions.

For 5-6 personas with platform left edge spanning y=210 to y=920 (710 px), spacing = 710 / 7 = ~100 px between arrow entries. First entry at platform_top + 100.

## Legend band (y = 970 - 1080)

Same pattern as TTB:

```
<line x1=40 y1=970 x2=1880 y2=970 stroke="#E3E3E3"/>
<!-- color swatches at y=1010 -->
<!-- stamp at x=1880 y=1060 text-anchor="end" class="stamp" -->
```

Stamp variant tag: `LTR`.
