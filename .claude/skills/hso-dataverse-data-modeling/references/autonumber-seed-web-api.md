# Setting an auto-number seed via the Web API (composed, not wrapped)

Per [ADR 0013](../../../../agent/wiki/decisions/0013-dataverse-skills-library-not-cli.md), the seed is a
thin one-call action. This file is the validated, copy-pasteable example for composing it against the
shared `Invoke-DataverseApi`.

> **Skill shortcuts (iteration-4):** because "starts at 1/100/1000" is in nearly every auto-number spec,
> the seed is also exposed as a thin **safety-bearing** helper (it composes this documented action with the
> value the caller already knows — not a 1:1 wrapper of an arbitrary endpoint):
> - **At table creation:** `CreateTable -PrimaryColumnAutoNumberFormat 'AGR-{SEQNUM:5}' -PrimaryColumnAutoNumberSeed 1` sets format **and** seed in one go.
> - **For an existing column:** `Operation SetAutoNumberSeed -TableName <t> -ColumnName <c> -AutoNumberSeedValue 1`.
> - When you set a format without a seed, the `[SEED]` note now prints a ready-to-run command with the
>   table/column names already substituted. The raw composed call below remains the reference for the
>   **populated-table** case (seed to `max + 1`).

## Background — format vs seed (why the PUT doesn't set the seed)

| Thing | Where it lives | How to set it |
|-------|----------------|---------------|
| **Format** (`AGR-{SEQNUM:5}`) | design-time attribute metadata; **travels in the solution** | PUT on `StringAttributeMetadata` — this is what `UpdateColumn -AutoNumberFormat` does |
| **Seed** (next sequence number) | per-environment **runtime counter state**; **not** in metadata, **not** in the solution | `SetAutoNumberSeed` unbound action (below) — **no SDK/plugin** |

The seed is environment-local *by design*: importing your solution into QA/Prod must not reset a live
counter back to 1. So there is no metadata property for it, and the old skill note ("cannot be set via
Web API / requires SDK/plugin") was drawn too broadly — the dedicated action sets it over plain HTTP.

> ⚠️ **The default seed on a fresh/empty table is 1000, NOT 1.** Applying the format alone (e.g.
> `AGR-{SEQNUM:5}`) and creating the first record yields **`AGR-01000`**, not `AGR-00001`. Nothing in the
> `UpdateColumn -AutoNumberFormat` output warns about this — it is a **silent correctness trap**. If a
> requirement specifies a low starting number (almost every spec that says "starts at 1"), you MUST call
> `SetAutoNumberSeed -Value 1` explicitly after setting the format. The skill now prints a `[SEED]` note
> on every auto-number conversion to flag this.

## Step 1 (existing data only) — find the current max with `hso-dataverse-data`

If the table already has rows, **seed to `max + 1`** or you risk colliding on the auto-number key. Read
the current high-water mark first. For a numeric `{SEQNUM}` embedded in a formatted string (e.g.
`AGR-00042`), pull the records and parse the sequence segment:

```powershell
# via hso-dataverse-data (Retrieve), then compute the max sequence client-side
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-data/scripts/Invoke-DataverseDataOperation.ps1" `
    -Operation Retrieve -EnvironmentUrl "https://yourorg.crm.dynamics.com" `
    -TableName "hsot_serviceagreement" `
    -Select "hsot_agreementnumber_text" -Top 5000
# parse the trailing digits of each hsot_agreementnumber_text (e.g. AGR-00042 -> 42); next seed = max + 1
```

On an empty table, the seed is simply your desired starting value (e.g. `1`) — but you still have to
**set it**, because the platform default is 1000 (see the warning above), not your starting value.

## Step 2 — call `SetAutoNumberSeed`

```powershell
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"   # adjust to the in-.claude path
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
$env   = "https://yourorg.crm.dynamics.com"
$token = Get-DataverseToken -EnvironmentUrl $env

# Unbound action: POST {env}/api/data/v9.2/SetAutoNumberSeed
$body = @{
    EntityName    = "hsot_serviceagreement"     # logical table name
    AttributeName = "hsot_agreementnumber_text"  # logical column name
    Value         = 1                            # next number to issue (max+1 on populated tables)
}
Invoke-DataverseApi -EnvironmentUrl $env -Token $token -Method Post -Endpoint "SetAutoNumberSeed" -Body $body
# 204 No Content on success. The next created record gets the formatted number at this seed.
```

## Gotchas

- **`Value` is the next number issued**, not the last one used. Seed `1` → first record is `…00001`.
- **The default seed on an untouched table is 1000** — so without an explicit `SetAutoNumberSeed`, the
  first record is `…01000`. Never assume a fresh counter starts at 1.
- The seed is **environment-specific** — set it again in each environment where the starting number
  matters (the 1000 default applies in each one). It does not export with the solution.
- Lowering the seed **below** existing data causes duplicate-key failures once the counter catches up —
  always seed `max + 1` on a populated table (Step 1).
- `EntityName` / `AttributeName` are **logical names** (lowercase), not schema names.
