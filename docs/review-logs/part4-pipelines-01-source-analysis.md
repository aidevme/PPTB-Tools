---
title: "Part 4 — Pipelines / ALM: Source Analysis"
author: aidevme
type: analysis
status: accepted
created: 2026-09-10
scope: template-build
dimension: pipelines-alm
sources:
  - "CDX (HSO-Power Platform Pipeline Template - CDX)"
  - "HINT (HINT-Pipelines)"
  - "live-delivery source (workspace/NewHorizon-App-SalesAI-CRM, .worktrees/Phase1)"
note: >
  Consolidated from three sub-analyses (CDX generation engine, HINT agentised generation, live-delivery source proven
  runtime). Backfilled by the orchestrator for documentation completeness; the requirements below were
  embedded directly into the Part-4 builder brief, so the built system already reflects them.
---

# Part 4 — Pipelines / ALM: Comparative Source Analysis

## TL;DR
- **CDX + HINT share one idea — marker-block stamping.** Real, hand-authored Azure DevOps YAML files
  carry comment-delimited `# ===== NAME-START/END =====` regions; a PowerShell engine
  (`Update-PipelineDefaults.ps1`, ~2,000 lines) rewrites **only the interiors** from two JSON config
  files (`pipeline-defaults.json`, `solution-organizer.json`). Human-authored logic and generated
  regions co-own each file; a re-stamp is a minimal, diff-friendly change. HINT wraps this in a layered
  **skill state machine** (architecture → generation → update-config → diagnostics) that snapshots
  before and asserts *nothing outside the markers moved* after, plus **discovery-driven deployment
  parameters** (a pipeline scans solution XML for connrefs/env-vars).
- **The live-delivery source is the proven runtime.** Its `.worktrees/Phase1/pipelines/*` (deploy/export YAML + a family
  of resilient PowerShell scripts) encodes the hard-won behaviours the generators don't: committed
  packed-zip store, version-compare-per-solution (never strand a sibling / never silently downgrade),
  holding-solution self-heal, flow-state reconciliation, orphan-component guard, circular-dependency
  bootstrap, cancel-both-layers, DLL-lock retry, and more.
- **Recommendation:** keep CDX/HINT's config→marker-stamp generation and skill wrapping, and fold in
  **every** runtime behaviour of the live-delivery source as generator-emitted logic or shared scripts. Keep the emitter
  factored so ADO is one target and GitHub Actions can be added.

## 1. CDX generation model
Two config files drive it: `pipeline-defaults.json` (projectInfo, environments `{branch,url,serviceConnection,referenceDataImportEnabled,sprintDeployEnabled}`, repositories, solutionChecker/codeValidation knobs) and `solution-organizer.json` (`solutions[]` with `name/displayName/importOrder/componentTypes`). The engine JSON-schema-validates, globs every `Pipelines/**/*.yml`, and for each calls `Update-*` functions that build a block in memory and splice it in via `(?s)startMarker.*?endMarker`. It does **not** create pipelines — the catalogue (clone-environment, code-validation, deploy-to-dev, discover-deployment-parameters, provision-environment, reference-data-export/import, solution-cleanup/deploy/export/organizer, sprint-deploy, validate-dependencies) is fixed; what's config-driven is the content inside. CDX already emits real ALM logic: holding-solution resolve, first-install detect, importOrder sequencing, `--import-as-holding`/`--activate-plugins`/overwrite toggles, deployment-settings, third-party install, tri-state reference-data, mojibake guard, 3-bucket dependency validation, branch→env approval gates.

## 2. HINT agentised generation
Same engine, wrapped as skills: `hso-pipeline-architecture` (design-only: classify each need as Config-only / New / Hybrid), `hso-pipeline-generation` (snapshot → delegate → **integrity check** that only marker blocks changed; outside-marker change = hard violation), `hso-update-pipeline-config` (the sole config writer; mandatory cross-artifact impact analysis before editing), `hso-pipeline-diagnostics` (reads live run logs, matches an error catalogue, confirmation-gated fixes), `hso-deployment-parameters` (filled from the `discover-deployment-parameters` pipeline that **scans solution XML**), `hso-provision-environment` (provision/clone env → register into config). Novel: the marker-stamp primitive, skills-as-state-machine with explicit "Does NOT" fences, discovery-driven parameters, importOrder-as-config.

## 3. The live-delivery source's proven runtime — the requirements the generator MUST emit
(Enumerated with source files in the build brief; summarised here.)
1. **Wave/solution ordering** — `solutions.json` `order` + rationale; matters on first-install.
2. **Committed `Solutions-Packed` store** — versioned managed+unmanaged zips as default deploy source; latest-or-pinned resolve.
3. **Version-compare-per-solution** — import only behind; **hard-error on older** (no silent downgrade); deployment-plan summary + confirm gate; never strand a sibling.
4. **Holding-solution (`*_Upgrade`) self-heal** — holding import + DeleteAndPromote; unconditional orphan scan each run; resilient `80071151` waits; submission cap (~4); report-only cleanup on fail/cancel.
5. **Flow-state reconciliation** — plugin-step snapshot/restore + `--activate-plugins`; workflow activated-set diff + reactivate; overrides table; `ConnectionAuthorizationFailed` owner-only hard stop.
6. **Orphaned-component guard** — custom component in a ticket solution not in a deployed wave → exit non-zero + list.
7. **Circular-dependency bootstrap** — order-1 base solution, connref + env-var **definitions only**, satisfies the `--settings-file` on every import.
8. **Overwrite-unmanaged UAT-only** + Prod hardcoded false + **never auto-approve Prod**; `deploymentTarget` compile-time stage gating.
9. **Reference-data export/import** — schema files, unzipped-committed, same gating.
10. **Hotfix lifecycle** — installed last; folder-as-state (active installs, retired uninstalls); idempotent.
11. **Resilience** — verify-not-trust async polling; cancel BOTH layers (ADO run + Dataverse async `operationtype 54`); DLL-lock retry (mail-quiet gate); lock/terminal/DeleteAndPromote-block classification; `Wait-ForNoActiveImport` via importjobs **and** msdyn_solutionhistories; token refresh; concurrency guard.
12. **Provenance & recovery** — export version-bump + compensating rollback; commit-before-publish; binary-aware change detection; additive security roles; third-party pre-wave; no destructive auto-rollback; deployment-status journal.
13. **Full parameter sets** — deploy (`publishWorkflows, applySettingsOnSameVersion, overwriteUnmanagedCustomizations, ignoreConcurrencyGuard, deploymentTarget, useSolutionsPackedStore, solutionsToDeploy, redeployAll`), export (`commitToGit, targetBranch, solutionsToExport, hotfixSolutionToExport`), reference-data (`deploymentTarget`).

## 4. Gaps
- CDX/HINT hardcode the runtime behaviours they *do* have inside YAML; the live-delivery source has richer runtime logic but as a **live project** (hardcoded pipeline IDs 773/774, env URLs, solution names) — not templatised.
- Neither generator covers the live-delivery source's #2–#7, #10–#12 as *config-driven emitted* logic.
- The live-delivery source has no generation/config layer at all; CDX/HINT have no captured "why" for the resilient scripts.

## 5. Best-in-class recommendation
Config→marker-stamp generation (CDX/HINT) + the HINT skill wrapper + **all 13 of the live-delivery source's behaviours** as emitted pipeline logic / shared `PipelinesHelpers/scripts/` modules, with the emitter factored (`-Emitter ado|github`). `solution-organizer.json` is read at runtime by the deploy scripts (so ordering is always live) and consumed at generation time (per-solution params) — the deliberate merge of CDX and the live-delivery source.

## 6. Things easy to overlook (kept)
Discovery-driven deployment parameters (scan solution XML, don't hand-list) · `validate-dependencies` (3-bucket) · `clone-environment` / `provision-environment` · `solution-organizer` (split a monolith by component type) · the marker-integrity guard (only interiors change) · binary-aware change detection (no CRLF false exports) · the deployment-plan confirm gate (prevents no-op deploys).

*End of Part 4 — Pipelines source analysis (backfilled).*
