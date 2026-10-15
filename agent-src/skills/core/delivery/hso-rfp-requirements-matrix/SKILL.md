---
name: hso-rfp-requirements-matrix
layer: orchestration
scope: core
description: Fill a client's RFP functional-requirements compliance matrix (the vendor-response columns — fit verdict, required product/ISV, effort/cost, comments) from any Excel format. Profiles the workbook, maps the client taxonomy onto a canonical verdict model, reuses prior answers (human-confirmed), and writes a draft back in the client's native columns preserving formatting. Use for ERP/D365 RFP requirements worksheets, fit-gap, or compliance matrices. Draft-only; a consultant reviews before submission. Not RFP prose/IP-fit (hso-presales-rfp-architect) or requirements authoring (hso-requirements-author).
---

# RFP Requirements-Matrix

Turn a client's requirements worksheet — every RFP ships a different column schema — into a
**drafted compliance/fit matrix**: the vendor-response columns filled (fit verdict, required
product/ISV, effort/cost, comment), written back into the client's own template with formatting
preserved. This is an **accelerator that produces a reviewable first draft**, not an autopilot.

## When to use this skill

- Responding to an ERP / D365 RFP that includes a functional-requirements **compliance worksheet**
- Completing a **fit-gap** or fit-assessment matrix the client supplied as Excel
- Filling the always-empty, high-value columns (required product / ISV, comments, cost) where a
  bare verdict column already exists
- Re-scoring an existing matrix into a different client's template (canonical → project)

## When NOT to use this skill

- Writing RFP narrative responses or an IP-vs-custom recommendation → `hso-presales-rfp-architect`
- Authoring system-agnostic requirements (the WHAT/WHY) from transcripts → `hso-requirements-author`
- Building an estimate / pricing → `hso-estimate-from-content`
- Looking up which HSO IP/accelerator fits → `hso-ip-reference`
- A current-state **integration register** (no priority / no response column) — that is context for
  the product column, not a matrix to score (see [references/format-profiles.md](references/format-profiles.md))

## Prerequisites

- Python with `openpyxl` — install once: `python -m pip install -r scripts/requirements.txt`
  (openpyxl reads/writes .xlsx preserving formatting; no Excel install needed).
- The client's requirements workbook saved locally (.xlsx / .xlsm).

## Configuration

Read from `CLAUDE.md` / `CLAUDE.local.md`:
- **Author Name** — attribution on any analysis written.
- **Answer Bank Path** — location of the configured (non-committed) answer bank; if absent, run
  with the bundled generic seed only and tell the consultant the bank is empty.

## Workflow

### 1. Choose output mode (ask)

Ask the consultant which output to produce (the skill can do either):

- **Canonical → project** *(default)* — answer once in the [canonical model](references/canonical-model.md),
  emit the client's native format. Best for one RFP.
- **Client-native** — work directly in the client's own taxonomy/sheet. Use when the client mandates
  their template verbatim or the canonical mapping is contested.

### 1b. Prepare the canonical working surface (optional but recommended)

Generate a blank **consolidated canonical matrix** — the working/review surface you populate
once and review in a consistent HSO layout (Legend + Matrix sheets, with verdict/effort/
fit/confidence dropdowns):

```
python scripts/New-ConsolidatedTemplate.py --out consolidated-matrix.xlsx
```

A pre-generated copy is checked in at [`templates/consolidated-matrix-template.xlsx`](templates/consolidated-matrix-template.xlsx)
if you just want to see/copy the artifact without running anything. **Regenerate it whenever the
canonical model changes** so the static file does not drift from the generator.

This is **not the client deliverable** — it is where you do the thinking. Use it especially when
the RFP is *not* a fillable worksheet (requirements in a PDF/Word doc): populate the consolidated
matrix directly, then project to whatever the client needs. For a client that ships a structured
worksheet you may skip straight to step 2 and work in their grid.

### 2. Profile the workbook (confirm — never assume)

```
python scripts/Read-MatrixWorkbook.py "<workbook.xlsx>" --json profile.json
```

Show the consultant the detected per-sheet **column map** (requirement / number / priority /
response / cost / product / comment) and **response columns**, plus scored-req vs section-header
counts. **Get confirmation or corrections** before writing anything. Identify the format archetype
(binary-availability, coded-SI, single-choice ladder, dual-score fit, integration register) from
[references/format-profiles.md](references/format-profiles.md).

### 3. Match & classify (human-confirmed reuse)

For each scored requirement (skip `is_section` rows):
- Find candidate matches in the **answer bank** (see [references/answer-bank.md](references/answer-bank.md))
  and **propose** the reuse — the consultant confirms each match before its verdict/comment are reused.
  No silent auto-match.
- For unmatched requirements, draft a canonical **verdict** + **effort band**, grounded in D365
  capability knowledge (`hso-d365-guidance-reference`, `hso-fasttrack-reference`, product docs).
  Flag these `confidence: auto` for review.

### 4. Enrich

- **Required product / ISV + IP-fit:** call `hso-ip-reference` per requirement — not only to name the
  product for the column, but to ask *"is there HSO IP/accelerator that fits this requirement?"*. The
  consultant may supply supplemental references per run (a SharePoint folder, a file list). Promote
  durable finds back to the catalog/bank (look-beyond, feed-back — see [references/answer-bank.md](references/answer-bank.md)).
- **Cost / effort:** hand effort bands to `hso-estimate-from-content` when a costed view is needed.
- **Comment:** write a short justification per non-`Standard` verdict.
- Set the per-row **confidence / audited flag** (`auto` | `reviewed` | `audited`).
- **Tag IP-fit candidates** (see IP-fit fan-out below): for each `hso-ip-reference` hit, record the IP
  name, **fit strength**, the **client priority** of the triggering row(s), and whether it is a
  **differentiator** — as evidence, not a decision.

### 5. Project & write back

Build a responses JSON keyed by sheet → rows → `{column_index: value}` (0-based indices from the
**confirmed** profile), projecting each canonical verdict onto the client's columns/codes per
[references/canonical-model.md](references/canonical-model.md). Then:

```
python scripts/Write-MatrixResponses.py "<workbook.xlsx>" responses.json
```

Writes a new `*_DRAFT.xlsx`, preserves formatting, never overwrites requirement/priority cells, and
skips non-blank cells unless `--overwrite-nonblank`.

### 6. Report

Tell the consultant: counts by verdict; **low-confidence / unaudited rows flagged for review**; the
list of ISV/third-party rows and the products proposed; sheets/rows skipped; the draft path. Offer to
bank newly-confirmed answers (into the configured bank, **not** this repo). Hand the **IP-fit candidate
list** to the next step (below).

## IP-fit fan-out

This skill is the one place that touches every requirement individually, so it is the natural place to
**surface HSO IP candidates with evidence** — but it does **not** decide what to propose, demo, or
document. It emits a structured candidate list; downstream skills + the consultant decide.

- **Determine fit** → `hso-ip-reference` (the single matching service; do not re-implement catalog matching here).
- **Propose?** → `hso-presales-rfp-architect` owns the IP-vs-custom proposal decision and the RFP narrative.
- **Demo?** → `hso-presales-demo-architect` consumes high-priority, well-fit, **differentiator** candidates.
- **Document / record in-use?** → `hso-ip-project-config` (`ip-in-use.md`) + `hso-engagement-deliverables`.

Each IP-fit candidate carries: IP name · fit strength · triggering requirement row(s) · client priority ·
differentiator (y/n). That evidence is the contract the architect/demo/documentation skills consume.
**Surface candidates; let the architect and the human decide.**

## Operations reference

| Action | Command |
|---|---|
| Generate consolidated canonical template | `python scripts/New-ConsolidatedTemplate.py --out consolidated-matrix.xlsx` |
| Profile a workbook | `python scripts/Read-MatrixWorkbook.py "<wb.xlsx>" --json profile.json` |
| Preview more rows | add `--max-preview 20` |
| Write drafted responses | `python scripts/Write-MatrixResponses.py "<wb.xlsx>" responses.json [--out path]` |
| Replace existing values | add `--overwrite-nonblank` (default skips & warns) |

## Critical rules

### DO
- Confirm the detected column mapping with the consultant before any write-back.
- Keep the original workbook immutable — write to `*_DRAFT.xlsx`.
- Human-confirm every answer-bank match; flag LLM-drafted rows `confidence: auto`.
- Source products catalog-first (`hso-ip-reference`); promote supplemental finds back.
- Treat output as **draft-only** — a consultant reviews every verdict, product, and comment before
  it reaches the client.

### DO NOT
- Commit any client's requirement text, answers, names, or pricing into this shared repo — the
  bundled answer bank is **generic / de-identified only**.
- Auto-submit, or present a matrix to a client without human review.
- Score integration-register artifacts — they are context, not a matrix.
- Hardcode the answer-bank path or a client format — detect/confirm, or read from config.

## Related

- [references/canonical-model.md](references/canonical-model.md) — canonical verdict set, effort bands, projections
- [references/format-profiles.md](references/format-profiles.md) — archetypes & column detection
- [references/answer-bank.md](references/answer-bank.md) — reuse store schema, governance, seeding
- `hso-presales-rfp-architect` — RFP prose responses + IP-vs-custom split; owns the *propose* decision (calls this for the matrix)
- `hso-ip-reference` / `hso-ip-project-config` — product/ISV catalog + IP-fit matching service; per-project IP declaration (`ip-in-use.md`)
- `hso-presales-demo-architect` — consumes differentiator IP-fit candidates for the demo
- `hso-engagement-deliverables` — documents proposed/confirmed IP
- `hso-requirements-author` — authors the WHAT/WHY (upstream of scoring)
- `hso-estimate-from-content` — effort/cost from the verdict+effort output

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
