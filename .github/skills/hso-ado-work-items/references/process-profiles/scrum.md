# Process profile — scrum

Stock Azure DevOps **Scrum** process. Schema: [_schema.md](_schema.md); governed by the
process-profile abstraction decision.

```yaml
profile: scrum
class: stock
process:
  name: Scrum
  typeId: 6b724908-ef14-45cf-84f8-768b5384da45   # verified live against a Dataverse-backed Azure DevOps org 2026-07-23
  base: null
mapping:
  requirement:
    workItemType: Product Backlog Item
    acceptanceCriteria: field:Microsoft.VSTS.Common.AcceptanceCriteria
    ruleFrFold: allowed
    parent: Feature
    testCases: opt-in
  slice:
    workItemType: Task                 # child of the PBI realizing its primary fr_ref (ruling O1)
    buildTypeExpression: tag:build:<slug>
    links:
      parent: PBI of primary fr_ref (Hierarchy-Reverse)
      blockedBy: System.LinkTypes.Dependency-Reverse
  defectType: Bug
  decisionMirroring: none              # ruling O2
  states:
    Product Backlog Item: [New, Approved, Committed, Done]
    Task: [To Do, In Progress, Done]
    closeVerb: Done
  sharedFields: []
tags:
  bpc: universal
```

## Notes

- **Close-at-merge** applies `Done` (not `Closed`) — the pipeline's attribution write-back
  must use the profile's `closeVerb`.
- Scrum's `Impediment` type is not used by this projection.
