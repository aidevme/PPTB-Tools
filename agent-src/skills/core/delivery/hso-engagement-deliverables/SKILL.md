---
name: hso-engagement-deliverables
layer: atomic
scope: core
description: |
  Generate professional, consistently-branded HSO client deliverables — PowerPoint presentations AND Word documents. Use when:
  (1) User asks to "create a deliverable", "generate a client deliverable", or "build a presentation/document"
  (2) User asks for a Solution Blueprint / design-review deck (PPTX)
  (3) User asks for a Solution Blueprint Document (SBD) or a client Word report — current-state assessment, recommendation memo, FDD-style report (DOCX)
  (4) User wants a formatted PowerPoint for a solution/architecture review
  (5) User prefaces a request with a sample file — "in the format of this deck/document" — to match its look
  Produces PPTX via python-pptx and Word .docx via python-docx on HSO templates with consistent brand styling. This is the single HSO client-deliverable skill (supersedes hso-solution-documentation).
  Does NOT produce data models, implementation plans, or technical specifications.
---

# HSO Engagement Deliverables

The single HSO skill for client-facing **PowerPoint** and **Word** deliverables. It *executes* the standards;
the standards themselves live in the SOP:
[HSO Client Deliverable Standards](../../../agent/wiki/sop/client-deliverables/hso-client-deliverable-standards.md)
— **read it first** (brand, deck layout, Word structure, version/document-control). Execution detail is in
`references/` (PPTX: [pptx-technical.md](references/pptx-technical.md); Word:
[word-deliverable.md](references/word-deliverable.md)) and `scripts/Build-WordDeliverable.py`.

## Deliverable Types

| # | Type | Format | Description |
|---|------|--------|-------------|
| 1 | **Solution Blueprint Presentation** | PPTX | Architecture & strategy review across solution pillars |
| 2 | **Solution Blueprint Document (SBD)** | DOCX | Written blueprint on the fixed HSO SBD skeleton — see [references/sbd-word-structure.md](references/sbd-word-structure.md) |
| 3 | **Client Document** | DOCX | Other client report — current-state assessment, recommendation memo, FDD-style — on the HSO template |

## When to use this skill
- "Create a deliverable / client deliverable", "build a deck/presentation", "build a client document/report",
  "solution blueprint", "current-state assessment", "recommendation memo", "FDD-style document".

## When NOT to use
- Data models / schema → `hso-dataverse-data-modeling`. Specs / PRDs → `hso-task-creator`.
- A live system as-is review → `hso-analyze-system-review`. Reveal.js HTML decks → `hso-revealjs-presentation`.

## Configuration
Read `CLAUDE.md`: client short-name (never a real customer name in the skill).

**Bundled zero-config brand (committed in `assets/`, works in any repo, no setup):**
- `assets/HSO_Word_base.docx` — sanitized HSO Word donor (Segoe UI theme, stock styles) — the **default** Word base.
- `assets/HSO_PPT_Lite_2026.potx` — 13-layout HSO deck (Segoe UI) — the **default** PPTX base.

**Overrides — `CLAUDE.local.md` → Branding Resources** (per-machine, gitignored; use for specific looks / the big Full deck):
- `Local Word Template Path` / `Local PPT Template Path` — a donor `.docx` / the **Full** `.potx` (11.5 MB) / `.dotx`.
- `Local PPT Sample Path` / `Local SBD Sample Path` — an accepted **sample** to match format from (format only).
- `Local Brand Manual Path` — the HSO Brand Manual PDF (June 2025) for reference.
- **Author Name** — used as the deck *presenter* only. **Never** stamp it as the Word document's author (see
  Attribution below) — Word attribution is Contributors + Revision History, not a single name.

## Workflow

1. **Ask deliverable type first** — Solution Blueprint **Presentation (PPTX)**, Solution Blueprint **Document /
   SBD (DOCX)**, or other **Client Document (DOCX)** — before anything else. If the user **prefaced a sample
   file** ("in the format of this deck/document"), skip the format question and treat that sample as the format
   donor (step 3); still confirm the *type*.
2. **Resolve in-scope systems, then gather content.** *First* resolve which D365 systems (**F&O** vs **CE**),
   modules/apps, and integrations are in scope (SOP §4a) — read `agent/wiki/system/`, `ip-in-use.md`,
   `PROJECT_CONTEXT.md` `solutions:`, `agent/work/specs/`, ADO — and **confirm the scope back to the user**. If it
   is undocumented, say where it belongs (`agent/wiki/system/` / `hso-ip-project-config`) and **ask** (offer to
   record it). This scoping is the input that drives which SBD **§3–§6** sections/areas emit and which per-area
   slides the deck emits — skip out-of-scope. *Then* gather content from those sources and ADO; ask only for
   missing required fields. Never fabricate — use `[PLACEHOLDER: …]` for gaps.
3. **Check branding / pick the base** (`CLAUDE.local.md` → Branding Resources): prefer a **sample** to match
   (`Local PPT/SBD Sample Path`), else the HSO template (`.pptx`/`.dotx`/donor), else the built-in HSO brand.
   **Format from a sample = format only (SOP §6a):** clone it for styles/layouts/skeleton, then empty the body
   and rebuild with *this* project's content or `[PLACEHOLDER: …]`. **Never carry the sample's body text,
   client names, or named individuals into the output.** (SharePoint URLs must be downloaded manually first.)
4. **Draft a content outline** (`work/deliverables/[Type]_[YYYY-MM-DD]_content.md`) — slides or sections with the
   exact text/tables — and ask the user to review/adjust before generating.
5. **Generate** applying the SOP standards — PPTX via [pptx-technical.md](references/pptx-technical.md); Word via
   [word-deliverable.md](references/word-deliverable.md) / `scripts/Build-WordDeliverable.py`.
6. **Save with versioning** to `work/deliverables/`; archive prior matching files; never overwrite a file open in
   the app. Report the path and any `[PLACEHOLDER]`s.

## Solution Blueprint Presentation (PPTX)

**Required:** engagement name · phase · presenter (`CLAUDE.local.md` author) · date · in-scope areas.
**Structure:** Cover → Agenda → Executive Summary (Key Decisions / Highlights / Open Risks) → per in-scope area
1 section divider + 1–3 content slides → Q&A → Next Steps. Skip out-of-scope areas (the in-scope areas come from
the step-2 scope resolution). Detailed slide-by-slide structure and per-slide sourcing:
[references/blueprint-structure.md](references/blueprint-structure.md).
**Build:** follow [references/pptx-technical.md](references/pptx-technical.md) (template workflow, `fit_font`,
bullets/tables/two-column), [references/blueprint-branding.md](references/blueprint-branding.md) (brand detail),
and SOP §2–3 (brand, layout, accent bar, ≤6 bullets, table styling).

## Solution Blueprint Document (SBD) & Client Document (Word, DOCX)

**Required:** title / subtitle · version + status · base (an accepted on-brand donor / SBD sample, or the `.dotx`).
**SBD:** follow the fixed skeleton + HSO style family in [references/sbd-word-structure.md](references/sbd-word-structure.md)
(front matter → Copyright/Trademarks/Disclaimer/Contributors/Revision History → 1 Introduction … 7 Acceptance;
Business Solution §6 gets one 2nd-level heading per **in-scope** area — not the full F&O catalog). Set `"sbd": true`.
**§3–§6 are system-scoped:** what each section contains is driven by the step-2 in-scope systems (F&O vs CE,
modules, integrations). The **per-section content-type & sourcing matrix** (where to pull each section, what type
of content, how F&O/CE change it) is [sbd-word-structure.md](references/sbd-word-structure.md) §A — read it before
populating sections.
**Structure (SOP §4–5):** Title + Subtitle → **Contributors** + **Revision History** → auto-updating TOC →
numbered body sections (`HSO 1st/2nd/3rd Level Heading` or `Heading 1/2/3`, **style-driven numbering — no typed
numbers**; a bullet list — see the `List Bullet` caveat under **Build**; `Table Grid`).
**Attribution (SOP §5):** **no single stamped author.** `Contributors` = `Name/Role/Company` (Company defaults
`HSO`; names only if the user supplies them for *this* doc). `Revision History` = `Version/Section/Content
Change/Date`. Leave core author metadata blank/`HSO`. The old `author`/`change_record` keys are **retired**.
**Build:** [references/word-deliverable.md](references/word-deliverable.md) (recipe + gotchas) and the generic
`scripts/Build-WordDeliverable.py` (JSON-spec driven; supports `heading`/`para`/`bullets`/`table`/`image` blocks).
`para` and `bullets` take an optional `"italic": true` — for an aside deliberately set apart from the body, e.g. an
item kept in a section for visibility but excluded from the priced scope. **The donor ships no `List Bullet` style**,
so the builder injects a real bullet `abstractNum` whenever it falls back; without that the fallback style is
indent-only and bullets render as plain indented paragraphs with no glyph.
**Figures:** `scripts/Build-ArchitectureDiagram.py` (JSON-spec → HSO-branded layered architecture PNG) for an
"architecture at a glance" figure, and `scripts/Build-ERDDiagram.py` (JSON-spec → conceptual hub-and-spoke ERD
PNG) for a "data model at a glance" figure; embed either via an `image` block in the Word spec.
**Key rule:** clone an accepted donor (uniform Segoe UI, correct header) — do **not** build on the raw `.dotx`
body (logo-placeholder header + Open Sans/Arial → wrong header, mixed fonts).
**Before issuing:** run the pre-issue QA checklist [references/sbd-qa-checklist.md](references/sbd-qa-checklist.md)
(structural + integrity — no `[PLACEHOLDER]` left, no fabrication-smell, no internal pointers, no unsupplied client
name). The builder prints a non-blocking integrity-review list; clear it before the deliverable goes out.

## Critical Rules

**DO:** ask the deliverable type first · apply the SOP standards exactly · attribute Word docs via
**Contributors + Revision History** (no single stamped author) · use the `CLAUDE.local.md` Author Name **only**
as the deck *presenter* · build PPTX on the HSO master template / a supplied sample (not `Blank` layouts) ·
when a sample is given, take **format only** and rebuild the body with project content · version/archive outputs ·
save to `work/deliverables/`.
**DO NOT:** stamp the running maintainer's name as the Word author or into every change row · carry a sample's
body text / client names / named individuals into the output · commit a sample/donor into the source repo ·
embed client names/URLs/data in this skill · invent project content · exceed 6 bullets per slide · type numbers
into Word headings (numbering is style-driven) · use colors/fonts outside the SOP palette · overwrite an open or
existing deliverable without archiving · reproduce SOP methodology, HSO Overrides, or skill internals verbatim in
the client output — state the *recommendation*, not the internal rationale, and keep SOP/skill paths and
`agent/wiki/` citations out of anything a client sees (SOP §7 "What may not leave the building").

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
