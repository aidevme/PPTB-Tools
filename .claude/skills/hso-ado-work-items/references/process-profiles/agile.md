# Process profile — agile

Stock Azure DevOps **Agile** process. Schema: [_schema.md](_schema.md); governed by the
process-profile abstraction decision.

```yaml
profile: agile
class: stock
process:
  name: Agile
  typeId: adcc42ab-9882-485e-a3ed-7678f01f66bc   # verified live against a Dataverse-backed Azure DevOps org 2026-07-23
  base: null
mapping:
  requirement:
    workItemType: User Story
    acceptanceCriteria: field:Microsoft.VSTS.Common.AcceptanceCriteria
    ruleFrFold: allowed                # n:1 into the parent story's AC field, tracked FR-n -> AC of #id
    parent: Feature                    # when the engagement uses the Feature layer; else unparented
    testCases: opt-in
  slice:
    workItemType: Task                 # child of the story realizing its primary fr_ref (ruling O1)
    buildTypeExpression: tag:build:<slug>   # e.g. build:extension, build:data-migration (ADR 0048 precedence)
    links:
      parent: story of primary fr_ref (Hierarchy-Reverse)
      blockedBy: System.LinkTypes.Dependency-Reverse   # Predecessor
  defectType: Bug
  decisionMirroring: none              # ruling O2 — opt-in via project override
  states:
    User Story: [New, Active, Resolved, Closed]
    Task: [New, Active, Closed]
    closeVerb: Closed
  sharedFields: []
tags:
  bpc: universal
```

## Notes

- **AC formatting:** Gherkin or checklist as HTML bullets in the AC field (never `<pre>`),
  per the SKILL.md formatting standards.
- **Slice tasks** may additionally set `Microsoft.VSTS.Common.Activity` where the
  buildType maps cleanly (Extension → Development, etc.) — the `build:<slug>` tag stays
  the authoritative expression.
- **BPC parenting:** when the catalog hierarchy exists as work items (hydrated backlog),
  the story parents under its process node instead of a Feature — tags stay on regardless
  (per the repo's own BPC tagging ruling).
