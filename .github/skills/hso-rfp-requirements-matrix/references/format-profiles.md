# Format Profiles & Column Detection

`Read-MatrixWorkbook.py` auto-detects column roles by header keywords, then you
**confirm the mapping with the consultant** before write-back. This file lists the
archetypes seen in the wild and how each maps, plus what to do when detection is weak.

## Detected roles

| Role | Header cues (substring, case-insensitive) |
|---|---|
| `number` | number, id, seq, req #, item # |
| `requirement` | application requirement, requirement (description), sub-function, subtopic, attribute, specification, capability |
| `priority` | priority, client score, weight, importance, criticality |
| `cost` | cost, price |
| `product` | required product, product(s), module, primary product, solution component |
| `comment` | comment, notes, additional detail, internal comments |
| response (0..n) | availability, standard, modify, custom, cannot, 3rd party, future, vendor score, fit, basic/complex configuration, embedded, pre-integrated, point solution, not supported, response |

## Archetypes

| Archetype | Shape | Response columns | Output projection |
|---|---|---|---|
| **Binary-availability** | one verdict column | e.g. `D365 Availability` = `Y/M/T` | write canonical → `Y/M/T`; fill Cost / Product / Comments |
| **Coded-SI** | one coded column + effort | `S/M/C/N/T/F` (+ effort 0–4) + Comment | write code + effort + justification |
| **Single-choice ladder** | several columns, one `X` | Basic/Complex Config, Embedded/Pre-integrated/New Point Solution, Extension, Not Supported | place a single `X` in the mapped column |
| **Dual-score fit** | graded scores | Client Score + Vendor Score + Audited + Notes | write vendor score band + audited flag |
| **Integration register** | inventory, no scoring | Type / From / To / Timing | **do not score** — context only for Product column |

See [canonical-model.md](canonical-model.md) for the exact verdict→dialect mapping per archetype.

## When detection is weak

- **No requirement column found** → the profiler emits a warning. Ask the consultant which
  column holds requirement text; pass the corrected index to the writer.
- **Multiple candidate response columns** (ladder archetype) → all are captured in
  `response_columns`; confirm which set is the answer ladder vs. metadata.
- **Multi-row / merged headers** → `detect_header_row` picks the best single row; if the real
  header spans two rows, confirm the column indices manually against the printed profile.
- **Macro workbook (.xlsm)** → openpyxl reads it; write-back drops macros. If the client needs
  macros preserved, fill a copy and have the consultant paste values into the original.
- **Section-header rows** → flagged `is_section` (text but no priority and no response). Do not
  score them. The heuristic can misclassify a sub-list parent that carries a priority of `-`;
  spot-check around list groups.

## Write-back contract

`Write-MatrixResponses.py` takes a responses JSON keyed by sheet → rows → `{col_index: value}`
using **0-based column indices from the confirmed profile**. It:
- preserves the client's formatting/formulas (loads non-read-only),
- never writes requirement / number / priority cells,
- skips cells that already have a value unless `--overwrite-nonblank`,
- always writes to a new `*_DRAFT.xlsx` — the original is immutable.
