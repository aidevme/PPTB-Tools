---
title: "Reference architecture diagram - icon catalog"
type: reference
status: active
scope: product
client: internal
project: hso-dataverse-best-practices
topics: [diagrams, icons]
sources: []
created: 2026-04-27
updated: 2026-04-27
---

# Reference Architecture Diagram - Icon Catalog

All icons in this diagram family are now declared as `<symbol>` definitions in
`templates/defs-block.svg` and consumed uniformly via `<use href="#icXxx" .../>`.
There are two categories:

1. **Inline SVG `<symbol>` glyphs** - lightweight, hand-coded shapes for personas
   and infrastructure components (Phone, Browser, Person, Corp, Functions, Service
   Bus, Fabric, Stripe, NetSuite, Databricks, S3, Redshift). These are
   single-color, restyleable, and small (a few hundred bytes each).
2. **Microsoft & partner vendor icons (base64-embedded)** - the "real" Microsoft
   Fluent and partner brand marks (Dataverse, D365, Power Platform, Copilot,
   Azure, AWS, Power BI, QuickBooks). These are wrapped in `<symbol>` definitions
   whose body is a single `<image href="data:...;base64,...">` tag, so consumers
   place them with `<use>` exactly the same way as the inline glyphs.

Use vendor icons for the central platform cards and external category headers
(where brand recognition matters). Use inline glyphs for personas, supporting
infrastructure inside the Azure subscription, and external systems where a
generic mark suffices.

## Microsoft & partner vendor icons (base64 symbols)

All declared in `templates/defs-block.svg`. Consume with
`<use href="#icXxx" x="..." y="..." width="..." height="..."/>`. The symbol's
viewBox handles scaling; the inner `<image>` always fills the symbol box.

| Symbol id | Source file | viewBox | Recommended size | Notes |
|---|---|---|---|---|
| `icD365` | `dynamics365.svg` | `0 0 96 96` | 60-96 px | Dynamics 365 master mark; fits 60x60 to 96x96 in card layouts |
| `icD365FS` | `fieldservice.svg` | `0 0 96 96` | 60-96 px | Dynamics 365 Field Service; use on the FS card header |
| `icDataverse` | `dataverse.svg` | `0 0 375 375` | 60-96 px | Microsoft Dataverse Fluent mark; high-resolution source, scales cleanly to small sizes |
| `icPowerAutomate` | `powerautomate.svg` | `0 0 375 375` | 60-96 px | Power Automate (purple/blue gradient) |
| `icPowerApps` | `powerapps.svg` | `0 0 375 375` | 60-96 px | Power Apps |
| `icPowerPages` | `powerpages.svg` | `0 0 375 375` | 60-96 px | Power Pages / Customer Portal |
| `icCopilot` | `copilot_m365.svg` | `0 0 48 48` | 48-72 px | Microsoft 365 Copilot / Copilot Studio (includes M365 ribbon) |
| `icAzure` | `azure_128.png` | `0 0 128 128` | 24-48 px | Azure cube; use small (28-32 px) on the Azure sub-zone ribbon |
| `icAWS` | `aws_128.png` | `0 0 128 128` | 28-48 px | AWS smile; PNG-based per Intuit/AWS branding restrictions |
| `icQuickBooks` | `quickbooks_128.png` | `0 0 128 128` | 40-56 px | QuickBooks Online; Intuit prohibits vector mark redistribution |
| `icPowerBI` | `powerbi_128.png` | `0 0 128 128` | 40-56 px | Power BI yellow/black mark |

Sizing rule: vendor icons read clearest at 40-60 px next to a card header, or
24-32 px in a ribbon. Going below 20 px with the high-resolution SVG sources
(Dataverse, Power Automate, Power Apps, Power Pages at 375 px viewBox) is fine -
the rasterizer downsamples cleanly. The PNG-based icons (Azure, AWS, QuickBooks,
Power BI at 128 px viewBox) start to look soft below ~24 px.

Source files for these symbols live in
`agent/work/deliverables/diagrams/icons/` in the originating engagement and are
reproduced in the skill's defs-block.svg as base64 payloads. Reuse the canonical
defs block - do NOT re-extract base64 from the source files for each diagram.

## Inline SVG symbol glyphs

All declared in `templates/defs-block.svg`. Consume with
`<use href="#icXxx" x="..." y="..." width="..." height="..."/>`.

| Symbol id | viewBox | Default size | Light bg | Dark bg | Use for |
|---|---|---|---|---|---|
| `icPhoneGlyph` | 0 0 64 64 | 40 px | navy + white | invert manually | Mobile-app personas (e.g., Field Tech) |
| `icBrowserGlyph` | 0 0 64 64 | 40 px | navy stroke / white fill | n/a | Portal / web personas (e.g., Homeowner) |
| `icPerson` | 0 0 64 64 | 40-48 px | blue `#079FC3` | OK on light bg only | Generic person (CSR, Franchise Owner, Brand Admin) |
| `icCorp` | 0 0 64 64 | 40-48 px | steel `#7F9CAF` building + white windows | OK on light bg only | Corporate / executive personas |
| `icFn` | 0 0 64 64 | 48-64 px | Azure blue `#0062AD` | self-contained dark | Azure Functions |
| `icBus` | 0 0 64 64 | 48-64 px | Azure blue `#0062AD` | self-contained dark | Service Bus |
| `icFabric` | 0 0 64 64 | 48-64 px | Fabric blue `#0B8EB6` | self-contained dark | Microsoft Fabric / Fabric Link |
| `icStripe` | 0 0 64 64 | 48-64 px | Stripe purple `#635BFF` | self-contained dark | Stripe / payment processor |
| `icNetSuite` | 0 0 64 64 | 48-64 px | NetSuite green `#125740` lettermark "N" | self-contained dark | NetSuite |
| `icDatabricks` | 0 0 64 64 | 48-64 px | Databricks red `#FF3621` | self-contained dark | Databricks |
| `icS3` | 0 0 64 64 | 48-64 px | S3 green `#569A31` cylinder | OK on light bg only | Amazon S3 |
| `icRedshift` | 0 0 64 64 | 48-64 px | Redshift purple `#8B1BB1` cylinder | OK on light bg only | Amazon Redshift |

Sizing rule: at default size 64 the glyph dominates a small card. Use 40-48 for
a glyph that sits beside a card header; 56-64 when the glyph IS the card content
(e.g., a tiny "Service Bus" tile inside the Azure sub-zone).

To recolor a glyph (e.g., to use `icPerson` in steel rather than blue), inline a
copy in the consuming SVG with adjusted fills, or extend `defs-block.svg` with a
sibling symbol (`icPersonSteel`) - do NOT use `<use href="..." fill="..."/>`
because nested element fills are not overridden by `<use>` per the SVG spec. The
same caveat applies to vendor symbols: the base64 image content is fixed; you
cannot recolor it through `<use>`.

## When to add a new symbol

Add a new symbol to `defs-block.svg` (and document it here) when the engagement
requires a vendor or system that recurs across diagrams in the same engagement,
or when the same shape is likely to appear in another engagement (e.g., adding
`icSnowflake` because two engagements in a row used Snowflake). For new vendor
icons, drop the source file (clean SVG or 128-px PNG) into the engagement's
`agent/work/deliverables/diagrams/icons/` folder, then run the symbol-builder
script to base64-embed it into `defs-block.svg`. One-off glyphs that won't be
reused stay inline in the consuming SVG.
