# Canonical Requirements Model

One internal model that every client matrix format projects from/to. Answer **once**
in canonical terms; the skill emits each client's dialect on write-back.

> The concrete, fillable form of this model is the **consolidated canonical matrix**, generated
> by [`scripts/New-ConsolidatedTemplate.py`](../scripts/New-ConsolidatedTemplate.py) (Legend +
> Matrix sheets with dropdowns). The lists in that generator mirror this file — **keep the two in
> sync**: change a verdict / effort band / confidence value here and there.

## Canonical verdict set

| Canonical verdict | Meaning |
|---|---|
| `Standard` | Out-of-the-box / native behaviour, no configuration of note. |
| `Config-basic` | Met via standard user-accessible setup; no code. |
| `Config-complex` | Met via advanced configuration / simple scripting; no code. |
| `Modification/Extension` | Requires custom code (plugin, extension, PCF, form script) — no core source change. |
| `Custom-report/query` | Data exists; a custom report/inquiry must be built. |
| `ISV-embedded` | Met by a point solution embedded in the core app (shared DB/security/UX, no integration build). |
| `ISV-pre-integrated` | Met by a separately-marketed product that is pre-integrated (separate DB/login, no build). |
| `ISV-new` | Met by a point solution that needs an integration to be built. |
| `Not-supported` | Cannot be met by the proposed solution. |
| `Future` | On the product roadmap; not available today. |

## Effort band (delivery effort)

Standardized starting scale (seeded from the coded-SI archetype's 0–4); **expected to be
tweaked** as the answer bank grows. Tie to `hso-estimate-from-content` for cost.

| Band | Label | Rough meaning |
|---|---|---|
| 0 | None | Standard / config only |
| 1 | Light | Minor config-complex or a simple report |
| 2 | Moderate | A modest extension or single integration |
| 3 | Heavy | Significant extension / multi-entity integration |
| 4 | Major | Net-new build or ISV stand-up + integration |

## Per-row attributes

Every canonical row carries: `requirement_text`, `area` (hierarchy), `client_priority`,
`verdict` (above), `effort_band`, `product` (from `hso-ip-reference` / supplemental refs),
`comment` (justification), optional `fit_score` (vendor capability), and a
**`confidence` / `audited` flag** (`auto` | `reviewed` | `audited`). Never ship a row to a
client at `auto`.

## Projections to client formats

The write-back step maps the canonical verdict onto the client's own columns/codes.

### Binary-availability archetype (single verdict column, e.g. `Y / M / T`)
- `Standard`, `Config-*` → `Y`
- `Modification/Extension`, `Custom-report/query` → `M`
- `ISV-*` → `T`
- `Not-supported` → `N` (or blank + comment) · `Future` → `M`/comment

### Coded-SI archetype (single letter + effort, e.g. `S / M / C / N / T / F`)
- `Standard`, `Config-*` → `S`
- `Modification/Extension` → `M` (+ effort band) · `Custom-report/query` → `C` (+ effort band)
- `ISV-*` → `T` · `Not-supported` → `N` · `Future` → `F`

### Single-choice ladder archetype (one `X` across config / point-solution columns)
- `Config-basic` → "Basic Configuration" · `Config-complex` → "Complex Configuration"
- `ISV-embedded` → "Embedded Point Solution" · `ISV-pre-integrated` → "Pre-Integrated Point Solution"
- `ISV-new` → "New Point Solution" · `Modification/Extension` → "New Extension"/"Modification"
- `Not-supported` → "Not Supported"

### Dual-score fit-assessment archetype (graded vendor score + audited flag)
- Map verdict → score band (e.g. `Standard`/`Config-*` → "Above Average";
  `Modification`/`Custom` → "Average"; `ISV-new`/`Not-supported` → "Below Average"/"N/A").
- Carry the canonical `audited` flag straight into the client's Audited column.

### Integration-register archetype (NOT a compliance matrix)
Some artifacts are current-state integration inventories, not scored matrices. **Do not
score them** — read them as context for the `product`/ISV column. Detect: columns like
Type / From / To / Timing and no priority or response column.

## The two-instrument insight

A client matrix is usually one of two jobs: **compliance/effort** (verdict + effort, what
most ERP RFPs want) or **fit/prioritization** (graded score, used to compare packages).
The canonical model carries both, so one answer can drive either output.
