---
title: "Reference architecture diagram - ASCII-first process"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, process]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - ASCII-first, Coordinates-second

## The rule

**Sketch the layout as ASCII text BEFORE writing any SVG coordinates.** Iterating on ASCII takes seconds; iterating on SVG coordinates takes minutes - render, screenshot, eyeball, edit, render, screenshot. Burn three rounds of that and the user is correctly annoyed.

Get the user to approve, in ASCII, the following BEFORE you start placing rects:

- Which audience cards appear, grouped how
- Which platform components are in scope (and which row each goes on)
- Which external systems are in scope (and which category each falls under)
- Which arrows exist, color-coded by role
- Which arrows are emphasized (coral) vs standard (blue) vs analytical (amber) vs payment (purple) vs ERP (green) vs optional (steel dashed)
- Layout choice: TTB or LTR

The ASCII pass is also where you find architectural mistakes ("we don't have Service Bus in this engagement", "the Field Tech persona doesn't talk to the portal directly") cheaply, before they're sunk into 200 lines of SVG.

## How this rule emerged

It emerged from `agent/work/deliverables/diagrams/LESSONS_LEARNED_conceptual_diagrams.md` in a real engagement, after three failed JSON revisions in a row on a different diagram type. The same principle applies to hand-coded SVG: the visual is locked in by hundreds of explicit coordinates, and a layout change that takes 5 seconds to redraw in ASCII takes 5 minutes to re-coordinate in SVG.

## Example - TTB ASCII sketch

Here is the kind of ASCII you'd write before starting on a new TTB reference architecture for an engagement:

```
AUDIENCES (y=140-370)
  Field Users               Customers                Corporate
  [Field Tech*]  [Dispatch] [Homeowner] [Subscriber] [Brand Pres] [Exec]
  *coral emphasis = primary persona

  arrows down (coral for Field Tech, blue for the rest)

MICROSOFT CLOUD - THE PLATFORM (center, navy ribbon)
  Row 1:  [Power Apps]                   [Customer Portal]
  Row 2:           [Dataverse - hub]
  Row 3:  [D365 FS]   [Power Automate]   [Copilot]
  Row 4 (Azure subscription, blue ribbon):
          [Functions]   [Service Bus]    [Fabric Link]

AWS DATA ESTATE (left, amber ribbon)
  [S3]
  [Databricks]
  [Redshift]
  [Power BI / consumption]

  amber arrows: Fabric Link <-> S3 (bulk feed)
  amber arrows: Redshift -> Power BI (read-only view)

INTEGRATIONS (right)
  PAYMENTS:   [Stripe]               <- purple arrows from Functions
  ERP:        [NetSuite] [QBO]       <- green arrows from Service Bus
  TELEPHONY:  [Five9]                <- blue arrow to Customer Portal
  CTI:        [Genesys]              <- steel dashed (optional)

LEGEND
  blue = user UX        coral = emphasized UX
  amber = bulk data     purple = payments      green = ERP
  steel dashed = optional / event-driven
```

That's enough for the user to say "no, swap Customer Portal and Power Apps - portal is on the left because it serves Homeowner who is on the left of the audience band" - and you adjust ASCII, not SVG.

## Workflow

1. Write the ASCII sketch in a code block in your reply.
2. Ask the user "does this match your engagement architecture?" - explicit yes / no.
3. If no, iterate on ASCII. Loop until yes.
4. Pick the skeleton (TTB or LTR) and reference the coordinate template.
5. Now place rects in the SVG, following the ASCII as the source of truth for which goes where.

## Anti-patterns

- "I'll just sketch it directly in SVG, it's faster" - it never is. The first render shows three layout problems and you've spent 20 minutes on coordinates that were architecturally wrong.
- "The user said they want LTR so I'll skip the ASCII" - the layout choice is one decision; positions WITHIN the layout are dozens. ASCII captures all of them in one place.
- "ASCII can't show colors / dashed / sizes accurately enough" - the ASCII is for layout (which boxes, where, which arrows). Color and emphasis are noted as annotations next to boxes. Don't try to render the ASCII as a faithful preview - that's the SVG's job.
