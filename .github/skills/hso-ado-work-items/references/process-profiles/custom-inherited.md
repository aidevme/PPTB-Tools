# Process profile — custom-inherited

An **inherited custom process template** (a stock process extended with custom work item
types — e.g. a Business Process Catalog based template plus backlog rework). This file is
the profile-form projection contract for such a process (see the process-profile
abstraction decision). `TBD(discovery)` entries are filled by observation against the live
inherited process (`_apis/wit/fields`, `_apis/wit/workitemtypes`), never guessed.

**Detection signature** (ladder step 3): inherited process whose WIT vocabulary carries
`End to end` / `Process area` / `Process` (reference names `Endtoend`, `Processarea`) or
`MSBPC.*` fields; Epic/Feature disabled. Treated as proposed pending confirmation — confirm
with the user before recording.

```yaml
profile: custom-inherited
class: custom-canonical
process:
  name: TBD(discovery)                 # inherited process name/ID in the target org
  typeId: TBD(discovery)
  base: Agile                          # baseline stock process; confirm at discovery
mapping:
  requirement:
    workItemType: Requirement          # custom type — not User Story, not CMMI's Requirement
    acceptanceCriteria: test-case-children   # test-case-as-AC, created before build
    ruleFrFold: allowed                # n:1 into the parent capability's acceptance, tracked FR-n -> AC of #id
    parent: Process node (Hierarchy-Reverse), tagged BPC:<id> verbatim padded
    testCases: mandatory               # they ARE the acceptance criteria
  slice:
    workItemType: by build-precedence      # Data Migration > Integration > Workflow > Report > Security role > Extension (default)
    buildTypeExpression: native WIT
    links:
      related: optional, per build-type lineage (Extension -> Requirement(s) of fr_refs; Data Migration -> process/process-area node)
      blockedBy: System.LinkTypes.Dependency-Reverse
      parent: never                    # Build and Process/Requirements are two different trees
  defectType: Bug                      # born from failed Test Case runs; titled "Test Case [n] - [failure]";
                                       # rolls up test case -> Requirement; never parented to Build items
  decisionMirroring: Key decision      # 1:1 with each ADR, same procedure as a stock Decision type
  states: TBD(discovery)               # until known, only the two build-slice write moments are automated
  sharedFields:
    - { name: Client Owner, refName: TBD(discovery) }
    - { name: HSO Owner, refName: TBD(discovery) }
    - { name: Due Date, refName: TBD(discovery) }
tags:
  bpc: universal
```

## Notes

- **Type vocabulary** (Epic/Feature disabled): Process tree — `End to end`, `Process area`,
  `Process`, `Requirement`, `Test Case`; Project management — `Risk`, `Issue`,
  `Key decision`, `Change request`; Build Management — `Extension`, `Integration`,
  `Setup`, `Document`, `Report`, `Security role`, `Batch job`, `Workflow`, `Data flow`,
  `Data migration`, `Development` (unused by this projection), `Task`, `Action Item`.
- **Release stamping:** the brief records the catalog release mapped against
  (`catalogRelease:`); tags carry IDs verbatim from that release.
- **Never split a slice** to fit the type taxonomy; `design` slices are not projected.
- **Discovery scope** (fills the TBDs): field reference names for the shared fields
  (renames of baseline `Business owner` / `Business process lead`?), process name/ID, state
  models, Bug backlog setting, custom-field check. When a Business Process Catalog baseline
  is used, its extracts guide the mapping.
