---
name: hso-update-solution-docs
layer: atomic
scope: core
description: Update Dataverse solution documentation after a PR merge. Use when a solution export PR is merged and the documentation needs to be updated to reflect the new components. Reads the PR analysis report and updates Solutions/.docs/[SolutionName]/[SolutionName].md accordingly. Triggers include "update docs for merged PR", "sync docs with solution", "document new components", or when solution documentation is out of date.
---

# Update Solution Documentation

Update solution documentation based on PR analysis reports after a solution export PR is merged.

## Required Parameters

| Parameter | Required | Default |
|-----------|----------|---------|
| **PR Analysis Report** | YES | - |
| **Solution Name** | No | `EstimationSolution` |

**If analysis report not provided, ask:** "What is the path to the PR analysis report? (e.g., `Solutions/PR_Analysis/PR_11_origin_solution-export_57_Comprehensive_Analysis.md`)"

**If no analysis report exists:** Use `hso-analyze-dataverse-solution-changes` skill first to generate it.

## Execution

**Authority for the post-merge documentation-update workflow — read before updating any docs:** [agent/wiki/sop/alm-best-practices/pr-analysis-workflow.md](../../../agent/wiki/sop/alm-best-practices/pr-analysis-workflow.md) ("Phase 2: Post-Merge Documentation Update" + "Documentation Update Standards").

**Authority for documentation section formats — read before writing entity/option-set/API/plugin/PCF/flow sections:** [references/documentation-formats.md](references/documentation-formats.md) (convenience digest of the SOP's "Documentation Update Standards").

| Task | Primary authority |
|------|-------------------|
| Post-merge doc-update workflow / what to update / spec status moves | agent/wiki/sop/alm-best-practices/pr-analysis-workflow.md ("Phase 2: Post-Merge Documentation Update") |
| Documentation Update Standards (version markers, section formats) | pr-analysis-workflow.md ("Documentation Update Standards"); references/documentation-formats.md is the convenience digest |
| Generating the PR analysis report (prerequisite) | `hso-analyze-dataverse-solution-changes` skill |

### Step 1: Read Analysis Report

```bash
Read Solutions/PR_Analysis/PR_[ID]_[branch]_Comprehensive_Analysis.md
```

Extract from report:
- New/modified tables with fields and relationships
- New/updated PCF controls with versions
- New global option sets with values
- New Custom APIs with parameters
- New plugin steps with triggers
- New cloud flows
- New web resources
- App module changes

### Step 2: Update Documentation

Read and update `Solutions/.docs/[SolutionName]/[SolutionName].md`:

| Section | Update Based On |
|---------|-----------------|
| **Overview** | Version number, feature summary |
| **Architecture > Solution Components** | Entity/control/workflow counts |
| **Data Model** | New entity relationships |
| **Entities** | New entities, modified fields |
| **Custom APIs** | New API definitions |
| **Plugins** | New plugin steps |
| **PCF Controls** | Updated versions, new controls |
| **Workflows** | New cloud flows |
| **Option Sets** | New global option sets with values |
| **Web Resources** | New JS libraries, icons |
| **Model-Driven App** | New sitemap entities, commands |
| **Footer** | Current month/year |

**Format templates (digest only):** The Step 2 mapping above and [references/documentation-formats.md](references/documentation-formats.md) are a quick reference. [agent/wiki/sop/alm-best-practices/pr-analysis-workflow.md](../../../agent/wiki/sop/alm-best-practices/pr-analysis-workflow.md) ("Documentation Update Standards") is authoritative for version markers and section formats — read it before designing the doc update, and treat `references/documentation-formats.md` as a convenience copy of those templates.

### Step 3: Update Related Documents

1. Update `Solutions/.docs/README.md` last modified date
2. Rename related specs from `2-InProgress_` to `3-Completed_` prefix

### Step 4: Report Summary

Provide to user:
- Sections updated
- New entities/option sets added
- Specs moved to completed

## Example

```
User: "The PR for solution-export/57 was merged. Update the docs."

Agent:
1. Read Solutions/PR_Analysis/PR_11_origin_solution-export_57_Comprehensive_Analysis.md
2. Extract: 4 new tables, 7 option sets, 4 Custom APIs, 6 plugin steps
3. Read Solutions/.docs/EstimationSolution/EstimationSolution.md
4. Update version 1.0.0.150 -> 1.0.0.157, add Approval System section,
   update counts (21 -> 25 entities), add APIs/plugins, update footer
5. Update Solutions/.docs/README.md date
6. Rename 2-InProgress_Estimate_Approval.md to 3-Completed_Estimate_Approval.md
7. Report summary
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No analysis report | Run `hso-analyze-dataverse-solution-changes` first |
| Documentation file not found | Create from template |
| Conflicting versions | Use version from most recent PR analysis |

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
