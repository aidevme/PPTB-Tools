---
title: "Integration — whole-solution convergence"
part: 6
kind: review-log
iteration: 03
author: aidevme
date: 2026-09-10
status: accepted
---

# Integration — whole-solution convergence

The integration pass built the missing keystone (the init engine), enforced cross-part coherence, and
neutralised client-specific leakage, looping on its own fixes until the verification test and the leakage
re-grep both came back clean. All BLOCKER/HIGH findings from `integration-01-review-r01.md` are resolved
and verified with REAL runs; residual risks are registered below, not dropped.

## What this pass changed

### 1. Built the init engine (the keystone)
`ProjectTemplate/InitializeProjectScript/` now holds `Initialize-CustomerProject.ps1` (+ `README.md`,
`HANDOVER-RUNBOOK.md`, `Test-Initialization.ps1`). It rewrites the ADR-0003 tokens across the tree
(content + token-bearing names), ordered longest-first and scope-aware so generic Dataverse identifiers
survive; it is idempotent, guards against destructive re-init, and supports `-WhatIf`/`-DryRun`.
Design + coherence contract: **ADR-0009**.

### 2. Fixed two BLOCKER coherence bugs (found by the test itself)
- **C1 — orphan-guard prefix.** `monitoring/Get-OrphanedComponents.ps1` hardcoded `@('cust_')`; a project
  on `cnto_` would scan the wrong prefix. The `cust_` rule was broadened to tree-wide (word-anchored).
- **C2 — settings-file name.** The deploy `--settings-file` name is derived by `Ado-Emitter.ps1` from
  `projectInfo.projectCode`, but the file/YAML used `-customer.json` and the slug rule would have produced
  `-contoso.json` (≠ the emitter's `-CNTO.json`). Added rule 0 keying the name to `projectCode`; file,
  YAML, and emitter now all yield `deployment-parameters-CNTO.json`.

### 3. Neutralised client-specific leakage (kept every lesson)
An independent scan + cleanup pass across shipped template code and ported docs (`ProjectTemplate/**`,
`AGENTS.md`, `CLAUDE.md`, `agent-src/skills/**/SKILL.md`). `AGENTS.md`/`CLAUDE.md` were already clean.

## Final coherence evidence — `Test-Initialization.ps1` (real run)

Initializes a throwaway copy as `Contoso / cnto / contoso / CNTO / Contoso`. **ALL HARD ASSERTIONS
PASSED**, 0 failures:

- **Orphans = 0** for every token class (`HSO.Customer`, `hso_customer_`, `cust_`, PascalCase `Customer`,
  PCF `customer<UPPER>`, slug `customer[-.]`, `customer_`) across 252 source files.
- **Generics preserved** — 39 standard Dataverse names (`customertypecode`, `parentcustomerid`, …) intact
  (proof the engine did not over-reach).
- **Config chain coherent** — `pipeline-defaults` prefix `cnto` / slug `contoso` / code `CNTO` /
  solutionPrefix `Contoso`; 5 solutions all `Contoso*`, `defaultSolution=ContosoBuild`; client
  `config.ts webResourcePrefix="cnto_"`; PCF `namespace="Contoso"`, `constructor="ContosoInsightCard"`;
  `deployment-parameters-CNTO.json` file + YAML + emitter agree; schema prefix `cnto_`.
- **Renames correct** — `HSO.Contoso.D365.sln`, `HSO.Contoso.Data/…csproj` (RootNamespace `HSO.Contoso.Data`),
  `cnto_widget.cs`, `HSO.Contoso.snk`, `ContosoChoiceField.pcfproj`; old-token folders gone.
- **Idempotent** — a second run with the same identity is a byte-for-byte no-op; **guard** — a run with a
  different identity is refused without `-Force`.
- **Build (real)** — `dotnet build HSO.Contoso.D365.sln` **succeeded** on the renamed solution. Client
  `tsc` was SKIPPED (temp copy omits `node_modules`); the Client part's own converged suite covers it.

## Final leakage evidence — before → after (independent re-grep, non-generated source)

| Category | Before | After | Kept (justified) |
|----------|-------:|------:|------------------|
| Client name (live-delivery source) | 55 | **1** | `Server/README.md:125` — the line *is* the rule ("never put a real customer name in template files"). |
| Ticket IDs `AP-nnnn` | 14 | **0** | — |
| Real solution names (wave + PCF-wave aggregators) | 2 | **0** | — |
| Real env URL (`dev1demos14.crm3…`) | 1 | **0** | — |
| Person names (`Keith Whatling`; shipped-tool author) | 2 | **0** | — |
| Real-looking record GUID (test fixture) | 1 | **0** | swapped for a synthetic GUID |

Lessons were preserved, not deleted — e.g. `store.ts` now reads "a virtual control whose `getOutputs()`
returns `{}` has `notifyOutputChanged` dropped by the platform" instead of citing the ticket. The
`out/` bundles and `obj/` nuget caches still contain the old client name only as pre-cleanup **build artifacts** and
the machine path `…\workspace\…`; both are gitignored and regenerate clean — not shipped source.

**Deliberately preserved** (per scope): `agent-src/sync/skills-manifest.json` `source:` provenance;
`docs/review-logs/**` + `docs/decisions/**` (audit trail — citing sources there is correct); the rule
line above; and the internal design-lineage codenames **CDX**/**HINT** (~18, not customer/PII — the same
class of legitimate provenance as the manifest `source:` fields).

## Residual risks (whole solution)

1. **Client `tsc`/PCF `npm` not re-run post-init here** — excluded from the temp copy for speed; each
   part converged with its own green suite, and the Server build IS re-run post-rename. First real
   engagement should `npm ci && npm run build` the Client + kept PCF scaffolds once (runbook step 5).
2. **`pac`/deploy paths unexercised** — local-only by mandate. The init makes the settings-file name,
   solution names, and publisher prefix coherent; the first real export/deploy should confirm the ADO
   Environment names match `pipeline-defaults.json` and the connection GUIDs are filled.
3. **Committed build output in the working tree** (`bin/obj/out/dist/coverage`) is gitignored noise; the
   init and its test skip it. A one-time clean before first commit is cosmetic.
4. **Schema-prefix dual spelling** (`hso_customer_` vs `cust_`) is reconciled by the engine but remains a
   cosmetic inconsistency in the neutral blueprint (ADR-0009 §Consequences).
5. **Agent-layer parity** (`agent-src` → `.claude`/`.github`) is Part-1's converged mechanism; this pass
   only touched `SKILL.md` prose for leakage. A `sync.ps1` + `verify-parity.ps1` run should follow any
   SKILL.md edit before commit (ADR-0008).

## Conclusion
A fresh `Initialize-CustomerProject.ps1` run yields a coherent, buildable, token-free project — proven by
a passing end-to-end test that includes a real `dotnet build`. Client-specific provenance is gone from
shipped code and docs (one intentional rule line aside), with every technical lesson preserved. The
whole solution is integration-verified. **Converged.**
