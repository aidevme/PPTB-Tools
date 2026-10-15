# Canonical ADO process profiles

One file per known process; the projection layer every producer skill resolves against
(the process-profile abstraction decision — resolve-then-realize). Dimension contract and
file shapes: [_schema.md](_schema.md).
A consumer repo pins its choice in `agent/wiki/system/ado-projection-profile.md` (evidence
+ overrides only) with a marker row in its `CLAUDE.md` Project-config table.

| Profile | Process | Class | FR item | AC home | Slice realization | Defect |
|---|---|---|---|---|---|---|
| [agile](agile.md) | Agile (stock) | stock | User Story | AC field | child Task + `build:` tag | Bug |
| [scrum](scrum.md) | Scrum (stock) | stock | Product Backlog Item | AC field | child Task + `build:` tag | Bug |
| [cmmi](cmmi.md) | CMMI (stock) | stock | Requirement | Description | child Task + `build:` tag | Bug |
| [basic](basic.md) | Basic (stock) | stock | Issue | Description | child Task + `build:` tag | Issue (`defect` tag) |
| [custom-inherited](custom-inherited.md) | inherited custom process template | custom-canonical | Requirement (custom) | Test Case children | native Build Management WIT | Bug (from failed Test Case run) |
| [none](none.md) | — | opt-out | — | — | — | — |

- **Resolution:** detect-or-ask ladder (procedures in SKILL.md) — stock GUID match
  auto-selects; the inherited-custom signature proposes; unknown customs get a seeded
  interview whose answers become `overrides` on a `custom:<slug>` profile; no API access →
  ask, record `detectedVia: user`.
- **Universal invariants:** BPC tags (`BPC:<id>` / `BPC:proposed:<key>` / `BPC:unmapped`)
  and build-slice semantics (1:1 slice, precedence classification, never-split,
  create-at-grill / close-at-merge) hold on every profile.
- **A project's own template backlog** may be exempted from these profiles — governed by
  the repo's own conventions ledger directly.
