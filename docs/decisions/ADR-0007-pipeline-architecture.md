---
adr: 0007
title: Pipeline architecture — config-driven marker-block generation with live-delivery-source runtime hardening
status: accepted
date: 2026-09-10
author: aidevme
supersedes: []
---

# ADR-0007 — Pipeline architecture

## Context
The template needs one reusable, best-in-class Power Platform ALM pipeline suite covering export, multi-env
deploy, reference data, provisioning, cloning, dependency validation, code validation, solution cleanup,
organizing, sprint deploy, and deployment-parameter discovery. Three sources feed it:

- **CDX** (`PipelinesHelpers/`) contributed the *generation* idea: hand-authored ADO YAML with
  comment-delimited marker regions, rewritten from JSON config by `Update-PipelineDefaults.ps1`.
- **HINT** contributed the *config blueprints* (`pipeline-defaults.json`, `solution-organizer.json`,
  `deployment-parameters-{code}.json`) and the "template, not hardcode" governance.
- **The live-delivery source** (`.worktrees/Phase1/pipelines`) contributed the *battle-tested runtime*: version-compare
  deploys, holding-solution self-heal, verify-not-trust polling, both-layer cancel, binary-aware change
  detection, version-bump-with-rollback, and more — 13 hard-won behaviours listed in the build brief.

Constraints (ADR-0001..0003): neutral tokens only, local-only build, reusability is the primary metric,
hard-won lessons must be encoded as guards/scripts (not prose).

## Options considered
1. **N hand-maintained pipelines per project.** Pros: nothing to learn. Cons: near-duplicates drift; the
   live-delivery-source lessons get copy-pasted and rot. Rejected — fails reusability.
2. **Fully generated pipelines (emit whole YAML from config).** Pros: maximal DRY. Cons: the generator
   becomes the product; any bespoke per-project step means editing the generator; huge blast radius; hard
   to review a generated 900-line deploy. Rejected — brittle, un-inspectable.
3. **Marker-block generation over hand-authored YAML, with the heavy runtime in shared PowerShell that the
   YAML calls and that reads config at runtime.** Pros: pipelines stay real, reviewable, and editable;
   only the small varying regions are machine-owned; runtime logic is unit-inspectable and
   version-controlled once; a project can add hand-authored steps freely. Cons: two mechanisms (stamp +
   runtime-read). **Chosen.**

## Decision
Adopt **marker-block stamping over hand-authored ADO YAML**, backed by **shared PowerShell scripts that read
the JSON config at runtime**, with the emitter **factored per CI target**.

- **Generator**: `PipelinesHelpers/scripts/Update-PipelineDefaults.ps1` (dispatcher) →
  `common/Marker-Common.ps1` (marker primitives) → `emitters/Ado-Emitter.ps1` (the ADO target). A second
  target is a sibling `emitters/GhActions-Emitter.ps1` exposing `Invoke-GhActionsEmitter` with the same
  signature plus a `-Emitter github` case — the dispatcher already routes it.
- **Marker regions** (`# ===== NAME-START/END =====`) are the only *blocks* the generator rewrites; a short,
  explicitly-named allow-list of **scalar defaults** (`targetBranch`, `importMaxAsyncWaitMinutes`,
  `importCeilingHours`, `deleteAndPromoteMaxSubmissions`, `deploymentParametersFile`) is also stamped in
  place. Everything else is hand-authored and never touched.
- **Config blueprints** are the single source of truth: `pipeline-defaults.json` (identity, environments,
  knobs), `solution-organizer.json` (solution names + `importOrder` + release role), and
  `deployment-parameters-{code}.json` (per-env connection refs + env-var values).
- **Runtime hardening** lives in `PipelinesHelpers/scripts/solution-deploy/*` (+ `common/`, `reference-data/`,
  `monitoring/`) and is called by the YAML. `solution-organizer.json` is read at runtime, so ordering and
  membership take effect on the next run with no re-generation.
- **Two roles for `solution-organizer.json`** — generated (per-solution params) *and* runtime (ordering) —
  is the deliberate CDX×live-delivery-source merge.

## Rationale
- **Reusability**: a new project fills three JSON files and runs one script. Neutral tokens (ADR-0003) rename
  the rest.
- **Reviewability**: the deploy pipeline is real YAML a reviewer can read; generated regions are small and
  labelled; the 0-diff outside-marker integrity check proves the generator never touches hand-authored logic.
- **Testability / "bulletproof means proven"**: every script parses under pwsh; every pipeline parses as
  YAML; configs validate against schema; the generator is idempotent. The live-delivery-source behaviours are encoded as
  scripts with the original hard-won comments (why `80071151` is retryable, why cancel must hit both layers,
  why DeleteAndPromote has a submission cap), not as prose that rots.
- **Safety**: `deploymentTarget` compile-time-gates which stages exist; Prod hardcodes overwrite=false and
  is gated by an ADO Environment approval + exclusive-lock check that a human — never the assistant —
  satisfies. This mirrors the Dev-only-write / Prod-read-only discipline the delivery repo enforces.
- **Extensibility**: the per-emitter split means GitHub Actions is an additive file, not a rewrite.

## Consequences
- Builders of a new project touch only `PipelinesHelpers/config/*.json`, then run the generator and
  `Setup-AzureDevOps.ps1`; they may add hand-authored steps to any pipeline without fighting the generator.
- The generator's contract (marker names + the scalar allow-list) is itself an interface: renaming a marker
  in a YAML without updating the emitter yields a warning, not silent breakage.
- The 13 live-delivery-source behaviours are now portable IP: any engagement inherits version-compare-not-downgrade,
  holding self-heal, verify-not-trust, both-layer cancel, and the packed-store deploy source by default.
- Commitments: the async/holding paths are verified statically only (local-only rule); a first sandbox run
  is the remaining proof. Reference-data and hotfix stores are committed (git-diffable) by design.
