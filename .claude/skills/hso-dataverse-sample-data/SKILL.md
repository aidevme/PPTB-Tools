---
name: hso-dataverse-sample-data
layer: atomic
scope: core
description: Author repeatable, version-controlled sample / demo / seed / test data for Dataverse as CSV + manifest.psd1 + a per-dataset Import/Export/Remove PowerShell trio. Use when seeding records into Dev/Test/UAT/Demo, building demo or presales datasets, creating integration-test fixtures, or refreshing a demo environment. This is the right path whenever you would otherwise create more than a handful of records, or the data must be re-seedable. NOT for ad-hoc one-off CRUD (use hso-dataverse-data) or production/migration data.
---

# Dataverse Sample Data Skill

Author **repeatable, version-controlled** sample data as a per-dataset package: numbered CSVs + a
declarative `manifest.psd1` + an `Import` / `Export` / `Remove` PowerShell trio. Seeding becomes a
reviewable artifact and a one-command, idempotent, re-runnable operation — instead of records created
one Web API call at a time.

## When to use this skill

- Seeding demo, presales, training, or integration-test records into a **non-production** environment.
- Building a dataset that must be **re-seedable** (CI fixtures, nightly demo refresh, regression isolation).
- Anytime authoring would otherwise mean **more than a handful** of `Create` calls.
- Capturing records a developer hand-built in Dev back into version control (`Export`).
- Tearing a dataset down cleanly between iterations (`Remove`).

## When NOT to use this skill

- **Ad-hoc, one-off CRUD** — a single query, a manual patch, one record: use [`hso-dataverse-data`](../hso-dataverse-data/SKILL.md).
- **Migration data** (real historical records from a legacy system) — [Data Migration SOP family](../../../shared/dv/agent/wiki/sop/data-migration/) (SSIS + KingswaySoft by default).
- **Configuration / reference data** the solution requires to function — [`hso-dataverse-data`](../hso-dataverse-data/SKILL.md) routed through [`configuration-data-strategy.md`](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md).
- **Production** of any kind — sample data must never reach a production environment (enforced by the trio's blocklist guard).

## Slice Consumption Contract (executor side of the architect→builder pipeline) — *conditional*

**Authority:** [`slice-consumption-contract-best-practices.md`](../../../shared/dv/agent/wiki/sop/alm-best-practices/slice-consumption-contract-best-practices.md) — read before building any slice inside the pipeline. It is the canonical, executor-side contract for [ADR 0018](../../../agent/wiki/decisions/0018-agentic-delivery-architect-builder-pipeline.md)'s architect→builder pipeline. The summary here is a labeled pointer, not a substitute.

**This contract applies when a slice's `touches` include sample / seed data** — the architect routes those touches to this skill. When they do: author the dataset (manifest + CSVs) to build **exactly** the records the slice specifies (counts, parent lookups, required fields populated); **trust and verify — don't rebuild — your `blocked_by` slices** (the tables/columns/lookups the records bind to already exist); and **read the records back against the slice's `acceptance`** — record counts match, lookups resolve to the right parents, required fields populated — not against an SOP rule the spec never invoked. Out-of-pipeline, ad-hoc seeding is governed by this skill's own standards, not the slice contract.

## Authority

**Authority for sample-data architecture, the manifest contract, idempotency, and the validation workflow — read [`sample-data-validation-workflow.md`](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md) before authoring or running a dataset.** The SOP is the canonical, authored standard; this SKILL.md operationalizes it but does not replace it.

**Authority for the shared `Common-Functions.ps1` module, GUID preservation, and environment-specific record remapping — read [`configuration-data-strategy.md`](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md)** before designing the import (sample data inherits these primitives from the configuration-data peer).

### Task -> primary authority

| Task | Primary authority (read first) |
|------|--------------------------------|
| Dataset architecture, manifest, per-dataset trio, anti-patterns | [`sample-data-validation-workflow.md`](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md) |
| Shared module, GUID preservation, env-specific remap | [`configuration-data-strategy.md`](../../../shared/dv/agent/wiki/sop/configuration-data/configuration-data-strategy.md) |
| Bulk-write fundamentals, service-protection envelope | [data-migration umbrella](../../../shared/dv/agent/wiki/sop/data-migration/migration-strategy-and-tooling-best-practices.md) §7–8 |
| Extract-then-analyse validation reports | [`sample-data-validation-workflow.md` §10](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md#10-validation-workflow--extract-analyse-report) |

> Digest only — the SOPs above are authoritative; read them before designing. The bullets and tables in this skill are labeled pointers, not substitutes for the standard.

## Prerequisites

- Repo scaffolded by [`hso-dataverse-init-repo`](../hso-dataverse-init-repo/SKILL.md): provides the `SampleData/` root and the repo-root `.scripts/Common-Functions.ps1` the generated trio dot-sources.
- A **non-production** target environment URL (read from `CLAUDE.md`).
- Auth: interactive Office 365, a pre-obtained `-AccessToken`, or a service principal via `.claude/auth-settings.json` (the generated scripts resolve all three).

## Workflow

### 0. Understand the purpose and tailor the data to it (do this first)

Sample data is only useful if it is **realistic and speaks to its audience** — generic "Test Account 1 / 2 / 3"
rows undermine a demo and hide real bugs from the dev team. Before scaffolding, establish *who the data is for*
and *what it must demonstrate*, then source or shape it accordingly:

- **Augmenting an existing / live implementation** (audience = the delivery team, realism = production-shaped):
  ask the user for **(a)** existing historical records, or **(b)** a small, scrubbed extract from production if one
  is available. Mirror the real data's distributions, volumes, and edge cases so seeded records exercise the same
  code paths real data will. Never copy unscrubbed production PII into a shared or non-secure environment.
- **A demo or presales scenario** (audience = a specific customer or prospect): ask for the **customer / prospect
  name**, then research their public web presence (use WebSearch / WebFetch) — the products or services they sell,
  their industry, terminology, and segments — and shape account names, products, and scenarios to match. Data that
  reflects the prospect's own business makes the demo land; generic data does not.
- **Integration-test fixtures** (audience = automated tests): tailor to the **scenarios under test** — parent/child
  shapes, boundary values, the intentional-inconsistency cases the logic must handle ([SOP §9.3](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md#93-the-intentional-inconsistency-case)).

If the purpose or audience is unclear, **ask before authoring** — the wrong shape of data is worse than none. Record
the purpose and any sourcing decisions in the dataset's `README.md`. (In this shared repo, keep all illustrative
content generic / Contoso; the tailoring above happens per engagement in the consuming repo.)

### 1. Scaffold a dataset

```powershell
powershell -ExecutionPolicy Bypass `
    -File ".claude/skills/hso-dataverse-sample-data/scripts/New-SampleDataset.ps1" `
    -DatasetName SubscriptionBilling
```

Creates `SampleData/Datasets/SubscriptionBilling/` with `manifest.psd1`, `Import-/Export-/Remove-SubscriptionBilling.ps1`, `README.md`, starter CSVs, and a `.gitignore`. Pure local file generation — no Dataverse connection.

### 2. Author the manifest and CSVs

- Edit `manifest.psd1`: declare each table in **dependency order** (parents first) with `FileName`, `TableName`, `EntitySet`, `PrimaryKey`, `NameField`, `Select`, `FieldTypes`, `Lookups`, and the authoritative `Ids` array. Field-type codes and the manifest contract are in [SOP §5](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md#5-the-manifestpsd1-contract).
- Replace the starter CSVs: **primary-key column first**, UTF-8, deterministic GUIDs from Dev, lookups as `_<field>_value`, option sets as integer values, dates as ISO 8601.

### 3. Dry-run, then seed

```powershell
.\SampleData\Datasets\SubscriptionBilling\Import-SubscriptionBilling.ps1 -EnvironmentUrl "<EnvironmentUrl>" -Interactive -DryRun
.\SampleData\Datasets\SubscriptionBilling\Import-SubscriptionBilling.ps1 -EnvironmentUrl "<EnvironmentUrl>" -Interactive
```

The import upserts every row **by primary-key GUID** (create-if-absent, patch-changed-if-present; blank CSV value = leave-alone), so it is idempotent — re-running converges to the same state. Add scenario-specific post-seed steps (status transitions, action invocations) in the marked region of the generated `Import` script, keeping each step guarded so the whole script stays re-runnable.

### 4. Export / Remove as needed

- `Export-<Dataset>.ps1` reads the declared records back into the CSVs deterministically (drift detection, demo capture).
- `Remove-<Dataset>.ps1` deletes the dataset's records in reverse order, scoped to the manifest — safe to re-run.

### 5. Validate (optional)

For datasets that exercise non-trivial business logic, follow the extract-then-analyse loop in [SOP §10](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md#10-validation-workflow--extract-analyse-report): extract a timestamped JSON snapshot, then analyse against expected outcomes.

## Configuration

Read from `CLAUDE.md`: **EnvironmentUrl** (non-production) · **Publisher prefix**
Read from `CLAUDE.local.md` / `.claude/auth-settings.json`: service-principal credentials (pipeline auth)

## Critical Rules

### DO
- **Tailor the data to its purpose and audience first** (Step 0) — production-shaped for a live build, prospect-shaped for a demo, scenario-shaped for tests. Realistic data is the point.
- Preserve **deterministic GUIDs** from the CSV on create (the idempotency + cross-environment-reference contract).
- Keep tables in **dependency order**; primary-key column **first** in every CSV; UTF-8 always.
- Keep the trio idempotent — guard every scenario-specific step with an existence/status check.
- Use the **fictional Contoso** company and generic table names in anything authored here — this is shared IP.

### DO NOT
- Seed sample data into **production** (the trio blocks known production patterns; keep `.scripts/ProductionEnvironments.txt` current).
- Re-introduce a **single mega-orchestrator** driving all datasets via a `-DatasetName` switch — the per-dataset trio is the unit ([SOP §3](../../../shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md#3-per-dataset-script-architecture)).
- Let Dataverse generate fresh GUIDs on import (breaks idempotency and cross-env links).
- Write **NULL on blank CSV fields** (breaks SystemRequired fields like `statecode`) — blank means leave-alone.
- Put client names, real environment URLs, secrets, or engagement specifics in any dataset, script, or manifest.

## Changelog

Moved out of this file per [ADR 0021](../../../agent/wiki/decisions/0021-skill-changelogs-in-sibling-file.md) — see **[CHANGELOG.md](CHANGELOG.md)**.
