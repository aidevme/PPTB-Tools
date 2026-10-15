---
name: hso-excel-analyzer
layer: atomic
scope: core
description: Extract structure, formulas, macros, validations, and cross-sheet dependencies from Excel workbooks (.xlsx/.xltx/.xlsm/.xltm) so a legacy spreadsheet tool can be reverse-engineered into a Dataverse design. Use for "analyze this Excel file", "extract the formulas", or "reverse-engineer this spreadsheet". Extraction only — digests belong to hso-wiki-ingest-discovery-artifact.
allowed-tools: Bash, Read, Write
---

# Excel Analyzer

Extract comprehensive structural information from an Excel workbook and produce a machine- and
human-readable analysis that informs Dataverse solution design.

Spreadsheets are the most common thing a Dataverse app replaces, and the design questions they
answer are hidden in places the eye doesn't reach: a calculation chain three sheets deep, a
validation list that is really a lookup relationship, a named range nothing references any more.
This skill surfaces all of it mechanically so the design conversation starts from what the workbook
actually does rather than what someone remembers it doing.

## When to use this skill

- "Analyze an Excel file", "extract formulas", "document a spreadsheet", "reverse-engineer an Excel tool"
- A client-provided workbook needs to become a Dataverse feature spec or data model
- You need the calculation logic and business rules a replacement app must preserve
- A discovery artifact is a workbook and the raw extraction must precede the digest

## When NOT to use

| Situation | Use instead |
|---|---|
| Filing the workbook as a discovery artifact — raw copy, digest, log entry | [`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md) |
| Reviewing a live Dataverse system (which *emits* an Excel pack) | [`hso-analyze-system-review`](../hso-analyze-system-review/SKILL.md) |
| Extracting from an Access database instead of a workbook | [`hso-msaccess-extractor`](../hso-msaccess-extractor/SKILL.md) |
| Turning the findings into requirements or a spec | [`hso-requirements-author`](../hso-requirements-author/SKILL.md) |
| Designing the resulting tables and columns | [`hso-dataverse-data-modeling`](../hso-dataverse-data-modeling/SKILL.md) |

**Boundary.** This skill stops at the analysis report. It does **not** write digests, copy files into
`agent/raw/`, or touch the artifact index — `hso-wiki-ingest-discovery-artifact` owns that pipeline
and this skill feeds it.

## Prerequisites

- Python 3.x with `openpyxl`
- Optional: `oletools` for VBA macro extraction (`pip install oletools`). Without it the script
  detects that macros exist but cannot read their code.

## Workflow

### 1. Run the extraction

```bash
python <skill_path>/scripts/analyze_excel.py "<workbook>" -o "<output_path>" --format markdown
```

| Argument | Purpose |
|---|---|
| `<workbook>` | Path to a `.xlsx`, `.xltx`, `.xlsm`, or `.xltm` file |
| `-o <output_path>` | Output file. Writes to stdout if omitted — **always pass this on Windows** to avoid console encoding errors |
| `--format markdown\|json` | `markdown` for human review (default), `json` for programmatic consumption |
| `--max-rows N` | Rows scanned per sheet (default 1000) |
| `--max-cols N` | Columns scanned per sheet (default 200) |
| `--max-formulas N` | Formulas captured per sheet (default 500) |

The script extracts sheets (name, state, dimensions, protection), formulas with cell addresses and
cached values, Excel tables, named ranges (including broken ones, with scope and the reason they are
broken), data validations, conditional formatting, cross-sheet references, merged ranges, cell
comments with authors, input cells identified by unlocked protection, **pivot tables**, **charts**,
**external workbook links**, VBA modules, and a data sample per sheet.

**Exit codes:** `0` success · `1` file not found · `2` the workbook could not be opened (unsupported
format, encrypted, or corrupt — the message names the cause and the fix).

### Truncation is always reported

The three caps exist to stop a pathological workbook running forever. When any of them bites, the
run does **not** quietly return a partial answer — it sets `truncated: true`, records per-sheet
counts (`rows_scanned` of `rows_total`, `formulas_captured` of `formulas_total_seen`), marks the
sheet `PARTIAL` in the Sheet Overview, and prints an `INCOMPLETE ANALYSIS` banner naming the caps
and how to raise them. Treat that banner as blocking: a design conversation run off a silently
truncated inventory is worse than no inventory.

Raising a cap is the normal response for a large workbook:

```bash
python <skill_path>/scripts/analyze_excel.py "<workbook>" -o "<out>" --max-rows 50000 --max-formulas 10000
```

The formula cap bounds **formula collection only**. Comments and input cells are always collected
across the full scanned range.

### 2. Read the report through a design lens

The raw extraction is an inventory; the value is in what each section implies for the target design.

| Section | Read it as |
|---|---|
| Sheet overview | The workbook's architecture — which sheets are input, calculation, reference, output |
| Excel tables | Candidate Dataverse tables — they are already structured records |
| Data validations | Candidate choice columns or lookup relationships |
| Cross-sheet references | The data flow, and therefore the relationships |
| Input cells | User-editable fields — the form surface |
| Named ranges | Reusable reference data; broken ones are dead logic worth flagging |
| Formulas | The business rules a replacement must preserve or deliberately change |
| Pivot tables | Aggregations the replacement must reproduce — usually a view, chart, or rollup column |
| Charts | The measures the business actually watches; the titles name them |
| External links | A hard dependency on another file — normally a second source system to integrate or absorb |

### 3. Hand off

Pass the report to the skill that owns the next step — do not duplicate their work here:

- **Filing it as a discovery artifact** → [`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md),
  which copies the workbook to `agent/raw/discovery/`, writes the digest to `agent/wiki/digests/`,
  and adds the log fragment.
- **Turning findings into requirements** → [`hso-requirements-author`](../hso-requirements-author/SKILL.md).
- **Designing the schema** → [`hso-dataverse-data-modeling`](../hso-dataverse-data-modeling/SKILL.md).

## Critical rules

### DO
- Always write to a file with `-o`. Console output mangles non-ASCII on Windows.
- Report broken named ranges and orphaned formulas — dead logic is a design finding, not noise.
- Distinguish a formula that encodes a **business rule** from one that is a spreadsheet
  **workaround**. Only the first has to survive into the Dataverse design.

### DO NOT
- Do not write digests or artifact-index entries from this skill — that is
  `hso-wiki-ingest-discovery-artifact`'s pipeline, and duplicating it causes drift.
- Do not treat the cached value as the truth when it disagrees with the formula; the workbook may
  have been saved without recalculating.
- Do not copy client workbook contents into any shared artifact.

## Supported formats

Only the OOXML formats openpyxl can read: **`.xlsx`, `.xltx`, `.xlsm`, `.xltm`**.

Anything else is rejected up front with an actionable message rather than a traceback:

| Format | Why | What to do instead |
|---|---|---|
| `.xls` | Legacy BIFF; openpyxl cannot read it at all | Re-save as `.xlsx`, or use [`Read-ExcelContent.ps1`](../hso-wiki-ingest-discovery-artifact/scripts/Read-ExcelContent.ps1) (Excel COM) if cell **values** are enough |
| `.xlsb` | Binary workbook format | Re-save as `.xlsx` |
| `.csv` | Not a workbook — no sheets, formulas, or validations exist | Read it directly |
| `.ods` | OpenDocument | Re-save as `.xlsx` |
| Password-protected | openpyxl cannot decrypt | Remove protection in Excel and re-save |

`.xls` matters more than the others: legacy spreadsheet tools — exactly this skill's target — are
often still in that format. The COM route reads them but yields values only, no structure.

## Known limits

- **Caps, but never silent.** Defaults are 1000 rows / 200 columns / 500 formulas per sheet; any cap
  that bites is reported per sheet and raisable via `--max-rows` / `--max-cols` / `--max-formulas`.
- **Not extracted:** Power Query / M queries, slicers, and chart *series* detail (charts are
  inventoried by type and title only). Pivot tables report name, location, source, and cache fields
  — not their full field layout.
- **Double load.** The workbook is loaded twice (once for formulas, once for cached values), which
  roughly doubles peak memory on large files.
- **Pivot/chart/external-link extraction reads openpyxl private attributes** (`_pivots`, `_charts`,
  `_external_links`). Every access is defensive and degrades to an `(unreadable)` entry rather than
  failing the run, but these are not part of openpyxl's public API and could shift between versions.
- openpyxl's `Data Validation extension is not supported` warning is expected on workbooks using
  extended validation rules — standard validations are still extracted.
- **VBA detection requires the real package marker.** Macro presence is determined by the presence
  of `xl/vbaProject.bin`, not `wb.vba_archive` — the latter is truthy for every workbook when loaded
  with `keep_vba=True` and reports macros on macro-free files.

## Pairs with the ingest skill's Excel reader

[`hso-wiki-ingest-discovery-artifact`](../hso-wiki-ingest-discovery-artifact/SKILL.md) ships
[`Read-ExcelContent.ps1`](../hso-wiki-ingest-discovery-artifact/scripts/Read-ExcelContent.ps1).
The two are complementary, not competing:

| | This skill | `Read-ExcelContent.ps1` |
|---|---|---|
| Reads | **Structure** — formulas, validations, names, pivots, VBA | **Values** — every cell as text |
| Engine | openpyxl (Python) | Excel COM |
| Needs Excel installed | No | **Yes** |
| Formats | OOXML only | Anything Excel opens, including `.xls` |

Use both on a workbook that matters: structure here, values there.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Ported from prior in-house reference skills and neutralised for the reusable template (dropped internal license header, stripped stray project tags). |
