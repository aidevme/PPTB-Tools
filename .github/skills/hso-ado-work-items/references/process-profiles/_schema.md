# Process-profile schema — the dimension contract

Governed by the process-profile abstraction decision (resolve-then-realize).
A **canonical profile** (files in this folder) answers every dimension below for one ADO
process. A **project profile file** (consumer repo,
`agent/wiki/system/ado-projection-profile.md`) picks a canonical profile and records only
detection evidence + engagement overrides — never a full copy.

## Dimensions every canonical profile must answer

| Dimension | Meaning |
|---|---|
| `requirement.workItemType` | The WIT one FR becomes (1:1, per ADR 0047/0049) |
| `requirement.acceptanceCriteria` | Where per-FR acceptance lives: `field:<refname>`, `description`, or `test-case-children` |
| `requirement.ruleFrFold` | Whether rule-FRs may fold n:1 into the parent item's acceptance (tracking rows `FR-n → AC of #id`) |
| `requirement.parent` | Parenting target for the FR item (`Hierarchy-Reverse`) |
| `requirement.testCases` | `opt-in` (engagement's test-execution section governs) or `mandatory` (test-case-as-AC) |
| `slice.workItemType` | What one build slice becomes — ADR 0048 semantics (1:1, never-split, create-at-grill / close-at-merge) hold on every profile; only this realization varies |
| `slice.buildTypeExpression` | How the ADR 0048 precedence classification is expressed: the WIT itself, or `tag:build:<slug>` |
| `slice.links` | Parent / Related / Predecessor topology for slice items |
| `defectType` | The WIT for defects |
| `decisionMirroring` | ADR → board mirroring target, or `none` (ruling O2: stock defaults to none; opt-in via override) |
| `states` | State model per projected WIT + `closeVerb` (the state applied at close-at-merge) |
| `sharedFields` | Fields to populate on every item when the process carries them |
| `tags.bpc` | Always `universal` — `BPC:<id>` / `BPC:proposed:<key>` / `BPC:unmapped` tags (ADR 0047/0050) work identically on every profile |

## Canonical profile file shape

One fenced YAML block (machine-readable, authoritative) followed by `## Notes` prose for
nuance the YAML can't carry. `TBD(<ref>)` marks a value awaiting discovery — never guess.
Stock `process.typeId` GUIDs were **verified live** against a Dataverse-backed Azure DevOps
org on 2026-07-23; `Get-AdoProcessProfile.ps1 -ListProcesses` re-verifies against any org.

```yaml
profile: <id>                 # agile | scrum | cmmi | basic | custom-inherited | none
class: stock | custom-canonical | opt-out
process:
  name: <ADO process name>
  typeId: <system-process GUID or TBD>
  base: <parent process for inherited ones, else null>
mapping:
  requirement: { workItemType, acceptanceCriteria, ruleFrFold, parent, testCases }
  slice: { workItemType, buildTypeExpression, links }
  defectType: <WIT>
  decisionMirroring: <WIT or none>
  states: { <wit>: [...], closeVerb }
  sharedFields: []
tags:
  bpc: universal
```

## Project profile file shape (consumer repo)

`agent/wiki/system/ado-projection-profile.md`, `type: system-state`, project tier. The
`CLAUDE.md` Project-config marker row points here; profile `none` still stamps the row
(ruling O5). Body carries one YAML block:

```yaml
profile: <canonical id or custom:<slug>>
canonical: hso-ado-work-items/references/process-profiles/<id>.md
base: <stock id, for custom:<slug> profiles>
process: { name, typeId, base }        # as detected
detectedVia: api | user                # user → re-verify opportunistically on first authenticated projection
detectedAt: YYYY-MM-DD
witSnapshot: [<work item type names>]  # drift-check baseline
overrides: {}                          # engagement deltas only, keyed by dimension path
```

- **Custom processes:** the seeded interview records answers as `overrides`
  against the base profile; the file is the ask-once-record-obey ledger entry.
- **Drift:** a create call failing on a missing WIT/field, or a stage-0 mismatch against
  `witSnapshot`, re-runs detection and surfaces the diff before any write.
- **Externally-orchestrated projects:** hydration writes this file only when
  absent; on conflict the repo file wins locally and the drift check escalates to a human.
- **Promotion:** a `custom:<slug>` profile recurring across engagements is promoted to a
  named canonical profile here via PR — the same path any project-tier knowledge follows.
