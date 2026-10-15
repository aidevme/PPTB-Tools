# Process profile — basic

Stock Azure DevOps **Basic** process (Epic → Issue → Task; no Bug type). Schema:
[_schema.md](_schema.md); governed by the
process-profile abstraction decision.

```yaml
profile: basic
class: stock
process:
  name: Basic
  typeId: b8a3a935-7e91-48b8-a94c-606d37c3e9f2   # verified live against a Dataverse-backed Azure DevOps org 2026-07-23
  base: null
mapping:
  requirement:
    workItemType: Issue
    acceptanceCriteria: description    # checklist bullets in System.Description; Basic has no AC field
    ruleFrFold: allowed
    parent: Epic
    testCases: opt-in
  slice:
    workItemType: Task                 # child of the Issue realizing its primary fr_ref (ruling O1)
    buildTypeExpression: tag:build:<slug>
    links:
      parent: Issue of primary fr_ref (Hierarchy-Reverse)
      blockedBy: System.LinkTypes.Dependency-Reverse
  defectType: Issue                    # tagged `defect` to distinguish from requirement Issues
  decisionMirroring: none              # ruling O2
  states:
    Issue: [To Do, Doing, Done]
    Task: [To Do, Doing, Done]
    closeVerb: Done
  sharedFields: []
tags:
  bpc: universal
```

## Notes

- **Defects and requirements share the `Issue` type** — the `defect` tag plus a Related
  link to the requirement Issue keeps them queryable apart. This replaces the old
  CLAUDE.md template's manual "Basic → Issue" defect-type row.
- Basic is the cheapest sandbox target for profile dry-runs.
