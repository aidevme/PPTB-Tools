# Process profile — cmmi

Stock Azure DevOps **CMMI** process. Schema: [_schema.md](_schema.md); governed by the
process-profile abstraction decision.

```yaml
profile: cmmi
class: stock
process:
  name: CMMI
  typeId: 27450541-8e31-4150-9947-dc59f998fc01   # verified live against a Dataverse-backed Azure DevOps org 2026-07-23
  base: null
mapping:
  requirement:
    workItemType: Requirement          # CMMI's stock type — distinct from the inherited custom Requirement
    acceptanceCriteria: description    # Gherkin bullets in System.Description; CMMI has no AC field
    ruleFrFold: allowed                # n:1 into the parent Requirement's Description AC section
    parent: Feature
    testCases: opt-in
  slice:
    workItemType: Task                 # child of the Requirement realizing its primary fr_ref (ruling O1)
    buildTypeExpression: tag:build:<slug>
    links:
      parent: Requirement of primary fr_ref (Hierarchy-Reverse)
      blockedBy: System.LinkTypes.Dependency-Reverse
  defectType: Bug
  decisionMirroring: none              # ruling O2 — note CMMI ships a stock Review/Decision-adjacent
                                       # type set (Change Request, Review); opt-in override may target those
  states:
    Requirement: [Proposed, Active, Resolved, Closed]
    Task: [Proposed, Active, Resolved, Closed]
    closeVerb: Closed
  sharedFields: []
tags:
  bpc: universal
```

## Notes

- **`Microsoft.VSTS.CMMI.ImpactAssessmentHtml`** carries origin tracking (spec/brief
  back-reference) per the SKILL.md type guide — it is *not* the AC home.
- CMMI creates items in `Proposed`; the work-starts transition is `Proposed → Active`.
