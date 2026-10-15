---
name: hso-wiki-ingest-discovery-artifact
layer: atomic
scope: core
description: |
  Ingest discovery artifacts of any type provided by the client — PDFs, Excel, Word, plain text, images, CSVs, Confluence pages, SharePoint docs, ADO work items, URLs. Accepts local files, SharePoint folders synced to OneDrive, or external sources with no local file (delegates to `hso-wiki-capture`). Copies local files to `agent/raw/discovery/`, writes a structured digest to `agent/wiki/digests/`, and adds a log entry (fragment under `agent/log/`, ADR 0062). See "## When to use" for triggers. Follows the wiki schema in `agent/schema.md` and the capture pattern from ADR 0003.
---

# Discovery Artifact Ingestion

Converts client-provided discovery artifacts of any file type into structured wiki digests that serve as a persistent knowledge base for solution design. Each artifact produces a two-file pair: an immutable raw file (or capture, if the source can't be saved locally) in `agent/raw/discovery/` and a digest in `agent/wiki/digests/` that cites it.

Follows the wiki schema in [`agent/schema.md`](../../../agent/schema.md) and the capture pattern from [ADR 0003](../../../agent/wiki/decisions/0003-external-source-captures.md).

## When to use

Use this skill when:

1. User provides discovery documents, SharePoint URLs, or ADO work item links to ingest
2. User says "ingest an artifact", "process a discovery document", "add a client document", "log this SharePoint doc", or "ingest this ADO item"
3. User wants to catalog and summarise client-provided material for solution design reference
4. User needs to snapshot a live-editable source (Confluence, SharePoint, wiki page) so the current version is preserved for citation

## Capture vs ingest — which do I use?

**Use `hso-wiki-capture` directly** when you only need a pointer + snapshot in `raw/` and don't need a solution-design digest yet. Example: you want to bookmark a SharePoint doc, a Confluence page, or an ADO work item for later citation — capture writes the record, no extraction, no digest.

**Use this skill (`hso-wiki-ingest-discovery-artifact`)** when you want the full pipeline — a raw file in `raw/discovery/` (copied or captured) plus a structured digest with document overview, key data points, relevance to solution design, and current-state pain points. The digest is the read surface consultants query during design; raw is the immutable source it cites.

**The two skills compose, they don't compete.** When this skill is invoked on a non-local source (ADO work item, Confluence page, SharePoint doc that can't be synced, Slack thread), it delegates to `hso-wiki-capture` to write the raw `.md` record, then writes its own digest on top. Capture is a primitive that ingest reuses.

| I have... | I want... | Use |
|---|---|---|
| A local PDF, Excel, or Word doc | Full digest with solution-design relevance | `hso-wiki-ingest-discovery-artifact` |
| A SharePoint URL I can sync locally | Full digest (sync first, then this skill) | `hso-wiki-ingest-discovery-artifact` |
| An ADO work item URL | A citable record, not a full digest | `hso-wiki-capture` |
| An ADO work item URL AND I want the digest | Full digest citing a capture | `hso-wiki-ingest-discovery-artifact` (delegates to capture) |
| A Confluence page | A citable snapshot (live docs drift) | `hso-wiki-capture` — or this skill if you also want the digest |
| A meeting recording or transcript | Different pipeline | `hso-wiki-ingest-transcript` instead |

## Configuration

Read from `CLAUDE.local.md`: **Author Name** (for `people:` and attribution)

## Workflow

### 0. Determine the source location

Ask: **"Where are the discovery artifacts located?"**

Four paths:

| Situation | What to do |
|---|---|
| **Local file(s)** with a known path | Proceed to Step 1 |
| **SharePoint / OneDrive** that can be synced locally | Provide sync instructions below, then proceed to Step 1 with the OneDrive path |
| **External source that can't be synced** — ADO work item, Confluence page, Slack thread, live Loop component, or a SharePoint doc the user can't sync | Delegate to [`hso-wiki-capture`](../hso-wiki-capture/SKILL.md) to produce a capture file in `agent/raw/discovery/`, then pick up at Step 3 to write the digest |
| **A URL with no download option** | Same as above — delegate to `hso-wiki-capture` |

#### SharePoint / OneDrive sync instructions

> **To sync the SharePoint folder to OneDrive:**
>
> 1. Open the SharePoint folder in your browser using the URL you provided
> 2. Click **Sync** in the top toolbar
> 3. OneDrive creates a synced folder at a path like:
>    `C:\Users\{username}\OneDrive - HSO\{Site Name}\{Folder Path}`
> 4. Once synced, provide the local OneDrive path to continue.

After the user provides the OneDrive path, run the bundled listing helper to enumerate supported files:

```powershell
powershell -ExecutionPolicy Bypass `
    -File "claude-code/skills/hso-wiki-ingest-discovery-artifact/scripts/List-ArtifactFiles.ps1" `
    -Path "<OneDrive-folder-path>"
```

The script outputs supported files with their sizes and skips temp files (`~$*`). Show the list to the user and ask which to ingest (or confirm all).

### 1. Stage the raw file(s)

For each artifact to process:

1. Copy the source file to `agent/raw/discovery/{filename}` where `{filename}` preserves the original name but normalises whitespace and special characters.
   - Example: `01 High-level Inventory of Processes.pdf` → `agent/raw/discovery/01-high-level-inventory-of-processes.pdf`
2. If a file with the same name already exists, ask the user before overwriting. Raw files are **immutable** — overwriting is not allowed. Use a `-v2` suffix if the user confirms a new version is needed.

For external sources routed through `hso-wiki-capture` in Step 0, the capture file is already written to `agent/raw/discovery/{date}_{slug}.md` — no additional staging is needed.

### 2. Extract content from each artifact

Use the method matching the file extension:

| Extension | Method | Notes |
|---|---|---|
| `.pdf` | `Extract-PdfText.ps1` (bundled) | Extracts textual PDF content using Python + `pypdf`; write to a temp `.txt` file, then read that file. If the PDF is image-only/scanned, note that OCR is still required. |
| `.xlsx` / `.xlsm` | `Read-ExcelContent.ps1` (bundled) | Extracts all sheets, preserves table structure. Requires Excel installed. Reads cell **values** only — for formulas, validations, named ranges, pivots or VBA, run [`hso-excel-analyzer`](../hso-excel-analyzer/SKILL.md) as well (see below). |
| `.xls` (legacy) | `Read-ExcelContent.ps1` (bundled) | COM opens legacy BIFF files that `hso-excel-analyzer` cannot. Values only. |
| `.docx` | `docx` skill or equivalent | Extract full text |
| `.csv` / `.tsv` / `.txt` / `.md` | Read tool | Direct text read |
| `.png` / `.jpg` / `.jpeg` / `.gif` / `.webp` | Read tool | Claude reads images natively — describe visual content |
| `.svg` | Read tool | Read as text (XML); summarise shapes and labels |
| `.pptx` | `Convert-PowerPointToPdf.ps1` (bundled), then `Extract-PdfText.ps1` | If PowerPoint COM export is available, convert the deck to PDF first and continue the ingest on the generated PDF. If conversion fails because Office/COM is unavailable, fall back to asking the user for a PDF export. |
| `.mp4` / `.mov` / `.vtt` | Treat as transcript source | Delegate to `hso-wiki-ingest-transcript` |
| Capture `.md` (from `hso-wiki-capture`) | Read tool | Read the `## Captured content` section of the capture file |

**Invoke Excel reader:**

```powershell
powershell -ExecutionPolicy Bypass `
    -File "claude-code/skills/hso-wiki-ingest-discovery-artifact/scripts/Read-ExcelContent.ps1" `
    -Path "agent/raw/discovery/{filename}.xlsx"
```

> **When the workbook is a tool, not a table.** `Read-ExcelContent.ps1` gives you the values; it
> cannot see the calculation logic. If the workbook is a *system* being replaced — an estimator, a
> pricing model, a planner — the design-relevant content is the formulas, validations, named ranges,
> pivots and macros, and none of that appears in a value dump. Run
> [`hso-excel-analyzer`](../hso-excel-analyzer/SKILL.md) as well and cite both in the digest. It is
> extraction-only and hands back here for the digest, raw copy, and log entry — this skill still
> owns that pipeline.

**Extract PDF text:**

```powershell
powershell -ExecutionPolicy Bypass `
  -File "claude-code/skills/hso-wiki-ingest-discovery-artifact/scripts/Extract-PdfText.ps1" `
  -Path "agent/raw/discovery/{filename}.pdf" `
  -OutputPath "work/analysis/{slug}.txt"
```

**Convert PowerPoint to PDF (when the source is `.pptx`):**

```powershell
powershell -ExecutionPolicy Bypass `
  -File "claude-code/skills/hso-wiki-ingest-discovery-artifact/scripts/Convert-PowerPointToPdf.ps1" `
  -Path "agent/raw/discovery/{filename}.pptx"
```

Then run `Extract-PdfText.ps1` on the generated PDF and proceed with digest authoring.

**Transcript detection:** If a `.docx` or `.txt` looks like a meeting transcript (filename contains "Transcript", "Recording", or "Meeting"), stop and delegate to `hso-wiki-ingest-transcript` — it has better participant/action-item extraction. Ask the user to confirm before switching.

### 3. Generate the digest

Save to `agent/wiki/digests/{slug}.md` where the slug matches the raw file (minus extension, lowercase, hyphens for spaces).

Use this template exactly. Fill every frontmatter field — use `—` for unknowns but never omit a field.

````markdown
---
title: "Digest — {Document Title}"
type: digest
status: active
scope: <product | project | personal>
client: <client-id or "internal">
project: <project-id>
topics: [<topic-slugs>]
people: [<person-slugs>]
sources:
  - ../../raw/discovery/{filename}
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
---

# Digest — {Document Title}

**Source:** `{original filename}`
**File type:** {PDF / Excel / Word / Image / Capture / etc.}
**Date ingested:** {YYYY-MM-DD}

## Document overview

{2-3 sentence summary of what this document is and its purpose.}

## Content summary

### {Section / Sheet / Topic / Visual Element 1}

{Detailed summary preserving key data points, tables, lists, and relationships. For images: describe layout, labels, colors, and any text visible. For spreadsheets: reproduce small tables inline; summarise large ones. For process maps and flowcharts: describe the flow step-by-step.}

### {Section / Sheet / Topic 2}

{Summary}

## Key data points

- {Important facts, numbers, dates, names extracted from the document — preserve specific values}
- {...}

## Relevance to solution design

### What this tells us

- {How this artifact informs the Dataverse / D365 solution design}
- {Business processes revealed}
- {Data entities or relationships implied}
- {Integration points identified}

### Current-state pain points or gaps

<!-- Omit this section if the artifact contains no current-state limitations. -->

- {Specific limitation of the current system, tool, or process — preserve system name and exact constraint as stated}
- {Another gap — workaround currently used, if mentioned}

### Questions raised

- {Questions this document raises that need answers}
- {Gaps or ambiguities in the information}

## Sources

- [Raw artifact](../../raw/discovery/{filename})
````

### 3a. If the source is a capture

When Step 0 routed you to `hso-wiki-capture`, the digest's `sources:` points at the capture file (`.md`) instead of a native file format:

```yaml
sources:
  - ../../raw/discovery/{date}_{slug}.md
```

In this case:

- Add a **Fidelity note** section near the top if the capture's fidelity is `excerpts` or `summary-only`: "Source is `fidelity: <level>`. Claims below are limited to what the capture preserves."
- Do not include verbatim quotes from a `summary-only` capture — the fidelity ceiling forbids it, and `hso-wiki-lint` flags it (invariant #10).

### 4. Content guidelines

- **Preserve specific data**: dates, dollar amounts, entity names, status values, role names. Don't generalise.
- **Spreadsheets**: reproduce small tables inline; for large tables, summarise structure and key rows.
- **Process maps and flowcharts**: describe the flow step-by-step.
- **Matrices**: preserve row/column structure in markdown tables.
- **Images**: describe every visible label, field, button, or annotation — visual layout matters.
- **Connect findings to solution design implications** — don't just summarise, explain what it means for the build.
- **Flag conflicts** with information from other digests or transcripts. Cross-reference them in the digest body so they surface at query time.

### 5. Resolve topics and people

For each topic or person referenced, link to the corresponding page in `wiki/topics/` or `wiki/people/` if it exists.

- **Topics**: every slug in the digest's `topics:` frontmatter must resolve to a real anchor by the end of the ingest ([ADR 0065](../../../agent/wiki/decisions/0065-ingest-skills-maintain-people-and-topics.md)). Missing anchors are created in Step 7 by delegating stub creation to `hso-wiki-update-topic` — never left dangling.
- **People**: tag the slug in `people:` frontmatter and link to the page if it exists. Do **not** create people pages from this skill — a document naming a person is not meeting participation. Missing pages are created when `hso-wiki-ingest-transcript` next ingests a meeting naming that person, or by the maintainer per the [People-pages contract](../../../agent/schema.md#people-pages--contract); until then `hso-wiki-lint` flags the dangling reference as a safety net.

This step only resolves the **digest's** frontmatter. Updating the topic anchor pages themselves happens in Step 7.5 below — that step closes the loop so newly-written digests actually surface on the topics they cite.

### 6. Add a log entry

Write a **log fragment** — a new file `agent/log/YYYY-MM-DD-HHmm-<slug>.md` containing exactly the entry (ADR 0062: `agent/log.md` is generated from fragments on main — never edit it directly). In a repo with no `agent/log/` folder (scaffolded before ADR 0062), append the entry at the top of `agent/log.md` instead. Entry format:

```
## [{YYYY-MM-DD}] ingest | digest | {Document Title}
{file type}, source: {local | sharepoint-sync | capture}. [{relative path to digest}](<relative path to digest>)
```

### 6a. Contribute to Solution Scope (consulting engagements only)

If the repo is a consulting workspace with an engagement `PROJECT_CONTEXT.md`, add any Microsoft product/module named in this artifact (the Dynamics 365 apps, Finance & Operations, Power Pages, Fabric, etc.) to that file's **Solution Scope** table as a `candidate` row, per the [Solution Scope Contribution Protocol](../../../agent/wiki/sop/presales/solution-scope-contribution.md). Match by product name (one row each), never downgrade a product that already carries a higher status, and skip this entirely in a delivery repo (no `PROJECT_CONTEXT.md`).

### 7. Propagate to topic anchors (MANDATORY)

For every topic in the digest's `topics:` frontmatter, this skill is responsible for making sure the anchor exists and is updated — not the user, not a follow-up skill the user has to remember to invoke. If a slug has no `agent/wiki/topics/{slug}.md` file, first delegate stub creation to `hso-wiki-update-topic` (reactive stub creation is its job, ADR 0065), then update the new anchor like any other. The previous version of this skill deferred this step to `hso-wiki-update-topic` as a "Related" recommendation; that left the loop open. **Do not skip this step.**

Update behaviour is **hybrid**: division anchors get a body update in addition to the link append; cross-cutting topics get link-only.

#### 7a. Classify each referenced topic

Two classes:

| Class | Behaviour | Examples |
|---|---|---|
| **Division anchor** | Body update + link append | Platform-summary anchors that already function as content pages (per-division slugs defined by the project). These are anchors that already carry per-division benchmarks, pain points, workshop questions, and observed systems — content that grows as discovery progresses. |
| **Cross-cutting topic** | Link append only | Process / capability / risk anchors that link to multiple divisions (e.g. `cpq`, `lead-management`, `quote-to-order`, `partner-portal`, `salesforce-migration-risk`, `commercial-technology-strategy`). These follow ADR 0005 strictly — link-only. |

Division anchors are recognised by **two signals together**:
1. The slug matches a known division/platform/business-unit (project-specific list — defined per engagement in the project's `CLAUDE.md`).
2. The page already contains body sections beyond `## SOPs` / `## Reference` / `## Decisions` / `## Digests` (i.e. operational subsections like Systems observed, Pain points, Workshop questions). If a topic has only the standard anchor sections, treat it as cross-cutting regardless of slug.

If the project has not yet defined its division-anchor list, ask the user once and persist the answer in the project's `CLAUDE.md` (or note in the chat for future runs). Do not assume.

#### 7b. Cross-cutting topic — link append

Append exactly one bullet to the `## Digests` section (the section marked `<!-- This section is auto-managed by hso-wiki-update-topic. Do not edit manually. -->`):

```markdown
- [{Digest title}](../digests/{digest-filename}.md) — {one short hook describing what's new}
```

The hook must be specific (numbers, dates, named systems) — not "see digest". Example: `— per-BU SKU counts, quote volumes, conversion rates, approval thresholds (May 2026)`.

If the section does not yet exist, create it after `## Decisions` with the auto-managed comment. Do not duplicate an existing entry — check first.

#### 7c. Division anchor — body update + link append

Two writes:

1. **Body update**: Add a new subsection titled `## Operational benchmarks (<source-month> <source-year> <source-name>)` (or extend an existing one if the source month already has a section). Include a per-BU table of the values from the digest that are specific to this division — preserve exact numbers, named systems, role titles. Add a `### New evidence vs. prior digests` sub-block calling out what is new versus what merely confirms prior content. Add a `### New workshop questions` sub-block if the digest surfaces new ambiguities the existing workshop bank does not cover.

2. **Link append**: Same as 7b, plus the hook should be longer because the body update is also citing the digest — call out the BU column being summarised so future readers can find it: e.g. `— Cerrowire column: 2,990 quotes/mo @ 70 lines avg, 4K SKUs, 2,353 accounts, ED-first Phase I (May 2026)`.

The body update must:
- **Not duplicate** content already present in the topic — link to the digest for the full data, summarise per-BU specifics in a table, surface only what's new in the comparison sub-block.
- **Cite the digest** at the top of the new subsection so the source is one click away.
- **Update the topic's `updated:` frontmatter date** to today.

#### 7d. ADR 0005 tension

The body update for division anchors creates a tension with [ADR 0005 — Topics are anchors, not content](../../../agent/wiki/decisions/0005-topics-are-anchors.md), which states topics should be link-dominated. This skill recognises that for **division summary pages** the convention has drifted in practice — the existing platform anchors carry observed-systems, pain-point, and workshop-question prose because consultants treat them as the per-division single-pane-of-glass during pursuit work. The hybrid behaviour here matches the de facto pattern, not the strict ADR.

If the project wants pure anchor behaviour, declare an empty division-anchor list and every topic gets link-only — no special case. If the project wants the hybrid, declare the division anchors. Do not create a new ADR or amend ADR 0005 from inside this skill — that is a project-level governance decision.

### 8. Run `hso-wiki-lint` (recommended)

```powershell
powershell -ExecutionPolicy Bypass `
    -File "claude-code/skills/hso-wiki-lint/scripts/Invoke-WikiLint.ps1" `
    -AgentPath "agent"
```

Exit code 0 means the new files pass the MVP invariants. Non-zero means something needs attention. Note: division-anchor body updates may produce `[topics-are-anchors]` warnings — this is expected per Step 7d and is acknowledged drift, not a regression.

### 9. Report to the user

Tell the user:

- Number of artifacts processed
- Where raw files (or captures) were staged
- Where digests were written
- Cross-references between artifacts (e.g., "The OTI Matrix references the same processes listed in the Inventory document")
- Topics and people flagged, **and what was done to each topic page** (link-only vs body update)
- Lint result (clean / findings)
- Recommended next steps for solution design

## Critical rules

### DO:

- Copy local files into `agent/raw/discovery/` before extracting — the wiki cites a stable repo path, not a client laptop path that may move.
- Write digests to `agent/wiki/digests/` with full frontmatter per the schema.
- Cite raw files in the digest's `sources:` frontmatter via relative paths (`../../raw/discovery/...`).
- Delegate to `hso-wiki-capture` for external sources that can't be saved as local files. Don't invent a workflow for non-local material in this skill.
- Read existing digests before generating new ones — to avoid duplication and identify cross-references.
- Preserve specific values (dates, amounts, names) verbatim from the source.
- Add a log fragment under `agent/log/` on every ingest (append to `agent/log.md` only in pre-ADR-0062 repos).
- **Propagate to topic anchors before reporting back to the user (Step 7).** Link-only for cross-cutting topics; body update + link for division anchors; missing anchors get a stub via `hso-wiki-update-topic` first (ADR 0065). Closing this loop is mandatory — leaving it for the user or a follow-up skill is the failure mode this version of the skill exists to fix.
- Run `hso-wiki-lint` after writing to catch drift immediately.

### DO NOT:

- Edit a raw file after it's been copied. Raw is immutable per ADR 0003. Use `-v2` suffix for new versions.
- Overwrite an existing digest silently. Ask the user first.
- Include verbatim quotes from a `summary-only` capture. The fidelity ceiling forbids it.
- Maintain a separate README.md index for discovery artifacts. `index.md` (regenerated by lint) is the catalog.
- Hardcode client names, URLs, or credentials in digests.
- Leave a `topics:` slug dangling — missing anchors get a stub via `hso-wiki-update-topic` in Step 7 (ADR 0065). Don't author the stub directly in this skill; the template lives in one place.
- Create **people pages** from this skill. People pages are maintained by `hso-wiki-ingest-transcript` (meeting participation) or the maintainer per [ADR 0065](../../../agent/wiki/decisions/0065-ingest-skills-maintain-people-and-topics.md) — this skill only tags `people:` frontmatter.
- Promote prose into a topic body for **cross-cutting** topics — only division anchors get body updates per Step 7c. Cross-cutting topics stay strictly link-only per ADR 0005.
- Process `.pptx` files directly — ask the user to export as PDF first.
- Process video or audio files directly — route to `hso-wiki-ingest-transcript` or ask for the accompanying transcript.

## Related

- [ADR 0001 — Adopt hybrid `agent/` wiki for product knowledge](../../../agent/wiki/decisions/0001-adopt-hybrid-wiki.md)
- [ADR 0003 — External source captures](../../../agent/wiki/decisions/0003-external-source-captures.md)
- [ADR 0005 — Topics are anchors, not content. SOPs live in `wiki/sop/`.](../../../agent/wiki/decisions/0005-topics-are-anchors.md) — governs how digests link to anchor pages
- [`agent/schema.md`](../../../agent/schema.md) — frontmatter schema and invariants
- `hso-wiki-capture` — for non-local sources (ADO items, Confluence, Slack, live-editable docs)
- `hso-wiki-lint` — runs after every ingest to verify schema compliance
- `hso-wiki-update-topic` — sister skill for **creating** new anchor pages (invoked from Step 7 when a `topics:` slug has no anchor, ADR 0065) and for synthesis-mode link proposals across all anchor sections. **This skill (`hso-wiki-ingest-discovery-artifact`) handles routine post-ingest updates to existing anchors internally in Step 7** — `hso-wiki-update-topic` is no longer the implicit follow-up to ingestion.
- `hso-wiki-ingest-transcript` — sister skill for meeting transcripts

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
