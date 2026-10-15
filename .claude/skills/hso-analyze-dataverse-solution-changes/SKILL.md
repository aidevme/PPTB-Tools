---
name: hso-analyze-dataverse-solution-changes
layer: orchestration
scope: core
description: Analyze Dataverse solution component changes by extracting detailed information from Dynamics 365 solution files. Use when the user asks to analyze solution changes, review what changed between branches, generate a solution analysis report, or check for best practice violations. Extracts Tables/Entities, PCF Controls, Global Option Sets, Custom APIs, Plugin Steps, Forms, Views, Workflows, Web Resources, Canvas Apps, and App Modules. Includes best practice violation detection for solution segmentation and naming convention validation.
---

# Analyze Dataverse Solution Changes

Extract changed solution components between git branches and generate a structured analysis report with best practice violation detection and naming convention validation.

## Required Parameters

| Parameter | Required | Default |
|-----------|----------|---------|
| **Source Branch** | YES | - |
| **Identifier** | No | Branch name |
| **Target Branch** | No | `origin/main` |

**If source branch not provided, ask:** "What branch should I analyze? (e.g., `solution-export/168`)"

## Execution

Run the PowerShell script:

```powershell
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-analyze-dataverse-solution-changes/scripts/Extract-SolutionComponentChanges.ps1" -SourceBranch "[BRANCH]" -PullRequestId "[ID]" -TargetBranch "origin/main"
```

**Parameters:**
- `-SourceBranch` (required): Branch to analyze (e.g., `origin/solution-export/168`)
- `-PullRequestId` (optional): Identifier for report filename
- `-TargetBranch` (optional): Comparison target, default `origin/main`
- `-SolutionPath` (optional): Path to Solutions folder, default `Solutions`
- `-OutputPath` (optional): Report output path, default `Solutions/PR_Analysis`

## Post-Execution

1. Read the generated report: `Solutions/PR_Analysis/PR_[id]_[branch]_Comprehensive_Analysis.md`
2. Present summary to user
3. **Highlight any best practice warnings prominently**, including:
   - OOB entity with all assets (HIGH severity)
   - Naming convention violations (MEDIUM/LOW severity)
4. Offer detailed analysis of specific components

## Best Practice Checks

Digest only — the **Dataverse Solutions SOP family** and `dataverse-naming-conventions.md` are authoritative; read the cited section before judging a finding. The OOB-entity-with-`behavior=0` check enforces segmentation §4's rule: **"Never add an OOB managed entity to a custom solution with `behavior=0`"** — use `behavior=1` (dependency) or `behavior=2` (shell) instead. Each row's Description is the actionable SOP rule, not just the symptom:

| Check | Severity | Description (rule the finding enforces) |
|-------|----------|-------------|
| OOB Entity All Assets | HIGH | Never add an OOB managed entity to a custom solution with `behavior="0"` (all assets); use `behavior=1`/`2` (segmentation §4) |
| Table Name Uppercase | MEDIUM | Custom table logical names must be lowercase per naming conventions |
| Field Naming Suffix | LOW | Fields must carry the expected type suffix (`_text`, `_num`, etc.) per naming conventions |
| Global Choice Uppercase | LOW | Global choice logical names must be lowercase per naming conventions |
| Web Resource Naming | LOW | Form scripts must follow the `{entity}_form.js` pattern per naming conventions |

See [references/component-types.md](references/component-types.md) for full naming convention details.

## Examples

```powershell
# Analyze solution export branch
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-analyze-dataverse-solution-changes/scripts/Extract-SolutionComponentChanges.ps1" -SourceBranch "origin/solution-export/168" -PullRequestId "13"

# Compare against develop branch
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-analyze-dataverse-solution-changes/scripts/Extract-SolutionComponentChanges.ps1" -SourceBranch "feature/new-feature" -TargetBranch "origin/develop"

# Analyze without identifier
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-analyze-dataverse-solution-changes/scripts/Extract-SolutionComponentChanges.ps1" -SourceBranch "release/1.0.0.157"
```

## Reference Documentation

**Skill References:**
- **[references/component-types.md](references/component-types.md)** - Component types, properties extracted, naming convention validation
- **[references/sample-output.md](references/sample-output.md)** - Sample output and troubleshooting

**SOP References:**

This skill spans multiple authoritative docs. Start from the finding type and go to its primary authority:

| Task / finding type | Primary authority |
|---|---|
| Naming-convention violations (table / field / global-choice / web-resource) | `dataverse-naming-conventions.md` |
| OOB-entity `behavior=0` (HIGH) / RootComponentBehavior / allowlist / connref-envvar boundary / first-party app version skew | `solution-segmentation-best-practices.md` (§4 / §5 / §3 / §6) |
| Default-publisher prefix (`cr8a3_*`) flags | `solution-publishers-and-versioning-best-practices.md` §3 |
| Positioning vs. Solution Checker / FastTrack SCV | `solution-checker-and-component-validation-best-practices.md` §8 |

Authoritative docs (each line states what the doc governs and that it is read-before-doing):

- [`shared/dv/agent/wiki/sop/dataverse-naming-conventions.md`](../../../shared/dv/agent/wiki/sop/dataverse-naming-conventions.md) — Authority for naming-convention validation (table/field/global-choice/web-resource naming) — read before interpreting or reporting any naming violation.
- [`shared/dv/agent/wiki/sop/dataverse-solutions/`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/) — the **Dataverse Solutions SOP family** (umbrella + 5 peers); the governing peers for this skill are:
  - [`solution-segmentation-best-practices.md`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-segmentation-best-practices.md) — Authority for solution-segmentation and RootComponentBehavior rules (§4 OOB-entity-`behavior=0` HIGH check with RootComponentBehavior 0/1/2 names verbatim from Microsoft's SolutionComponent reference; §5 FastTrack SCV allowlist patterns; §3 connection-reference / env-var deployment-settings boundary; §6 first-party app version skew) — read before judging any segmentation finding.
  - [`solution-publishers-and-versioning-best-practices.md`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-publishers-and-versioning-best-practices.md) — Authority for publisher/prefix rules (§3 Default Publisher trap; flagging components carrying default-publisher prefixes such as `cr8a3_*`) — read before reporting a publisher-prefix issue.
  - [`solution-checker-and-component-validation-best-practices.md`](../../../shared/dv/agent/wiki/sop/dataverse-solutions/solution-checker-and-component-validation-best-practices.md) — Authority for how this skill is positioned among validation surfaces (§8: Solution Checker code patterns vs. FastTrack SCV component placement vs. this skill's PR-time delta analysis) — read before characterizing this skill's scope vs. Solution Checker/SCV.

---

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
