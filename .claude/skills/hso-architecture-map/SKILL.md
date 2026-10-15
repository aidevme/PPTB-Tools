---
name: hso-architecture-map
layer: foundation
scope: core
description: >
  Maintains the architecture map (TOPO — Topology of Platform Objects) at
  agent/wiki/system/solution-map.topo: a living document tracking every solution component's intent,
  dependencies, and interconnections. Cross-cutting — invoked as a mandatory sub-step by the build
  skills whenever a component is created, modified, or removed, and on /topo-validate and /topo-update.
allowed-tools: Read, Write, Edit, Grep, Glob
---

# Architecture Map (TOPO — Topology of Platform Objects)

The single source of truth for how solution components relate and why they exist. The map is
platform-agnostic; concrete implementations are captured via a platform profile.

## When to use

Invoke (or have another skill invoke) this skill whenever you:

- Create, modify, or remove a solution component — data entity, server logic, client logic, API,
  shared function, background process, UI control, config pattern, or integration boundary.
- Add or remove a dependency between components.
- Run `/topo-validate` (regenerate the graph + consistency check) or `/topo-update`.
- Initialise a project (seed the map from the template — SOP-1).

This skill is cross-cutting: the build skills call it as a mandatory sub-step (see §5).

## Where things live

| Artefact | Location |
|---|---|
| Live solution map | `agent/wiki/system/solution-map.topo` (this project) |
| Blank template | `templates/solution-map.topo` (this skill) |
| Maintenance rule | `topo-maintenance.md` (this skill) |
| Language spec + SOPs | `shared/dv/agent/wiki/reference/topo-language-spec.md`, `.../topo-standard-operating-procedures.md` |

The `.topo` file lives under `agent/wiki/system/` because it IS a current-state snapshot. It is not
`.md`, so the wiki linter does not require frontmatter on it. After a material change, append a
one-line entry to `agent/log.md`.

## 1. Component tags

| Tag | Type | When to create |
|---|---|---|
| `[DE]` | Data Entity | New table/collection designed |
| `[DF]` | Data Field | Field added that drives logic |
| `[DR]` | Data Relationship | Relationship between entities |
| `[SL]` | Server Logic | Server-side component created |
| `[CL]` | Client Logic | Client-side component created |
| `[API]` | API | Exposed interface created |
| `[SF]` | Shared Function | Reusable function created |
| `[BP]` | Background Process | Async/scheduled process created |
| `[UC]` | UI Control | Custom UI component created |
| `[CFG]` | Config Pattern | Config entity + handler pair |
| `[IB]` | Integration Boundary | External system connection |

## 2. Relationship types

`depends_on` (A requires B) · `serves` · `triggers` · `flows_to` · `realizes` · `configures` ·
`contains` · `subscribes_to` · `maps_to` (abstract→concrete) · `supersedes`.

## 3. Bidirectional dependency rule (NON-NEGOTIABLE)

Every `depends_on` MUST have a mirror `depended_on_by` on the target, and vice versa. Always update
BOTH sides. `/topo-validate` fails on any unmatched edge.

## 4. Update contracts (trigger → primary SOP)

| Trigger | SOP | Updates |
|---|---|---|
| Project init (no map) | SOP-1 | Create map from template |
| New data entity | SOP-2 | `[DE]` + `[DR]`, update related |
| New server logic | SOP-3 | `[SL]`, update `[DE]` list + `[SF]` back-refs |
| New client logic | SOP-4 | `[CL]`, update `[DE]` list, SET PARITY |
| New API | SOP-5 | `[API]`, update backing `[SL]` back-refs |
| New shared function | SOP-6 | `[SF]` |
| New background process | SOP-7 | `[BP]`, update trigger entity + APIs |
| New UI control | SOP-8 | `[UC]`, update parent `[DE]` |
| New config pattern | SOP-9 | `[CFG]` + `[DE]` + `[SL]` |
| New integration boundary | SOP-10 | `[IB]` (contract/boundary/operational) |
| New/removed dependency | SOP-11/12 | Update BOTH sides |
| Component removed | SOP-13 | Remove block + ALL cross-refs |
| New logic-driving field | SOP-14 | `[DF]` under parent `[DE]` |

## 5. Build skills that MUST update the map

`hso-dataverse-data-modeling` (`[DE]`/`[DF]`/`[DR]`) · `hso-plugin-development` (`[SL]`) ·
`hso-formscript-development` (`[CL]`, SET PARITY) · `hso-pcf-control-development` (`[UC]`) ·
`hso-dataverse-customapi` (`[API]`) · `hso-powerautomate-writer` (`[BP]`).

## 6. What the map is NOT

Not a full schema doc (only logic-driving fields), not a code reference (only intent/interfaces),
not a deployment guide, not comprehensive — only interconnections.

## 7. Anti-patterns to reject

Listing every field · prose in blocks · manual Mermaid edits (regenerate via `/topo-validate`) ·
skipping `depended_on_by` · platform details in abstract blocks · freeform relationships ·
components without a map update.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-10 | maciejnowicki | Ported from prior in-house skills and neutralised for the reusable template; live map stays project-local, language spec + SOPs inherited via shared/dv. |
