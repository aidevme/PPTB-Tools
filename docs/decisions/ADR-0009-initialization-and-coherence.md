---
adr: 0009
title: Initialization engine & whole-solution coherence contract
status: accepted
date: 2026-09-10
author: aidevme
supersedes: []
---

# ADR-0009 — Initialization engine & coherence contract

## Context
Five parts (Agent, Server, Client, PCF, Pipelines) were built independently against the ADR-0003 token
contract. Reusability only pays off if a **single, mechanical step** turns the neutral blueprint into a
coherent named project — and if there is a **test** proving the result has no leftover tokens and a
sound config chain. CDX and HINT both shipped an `Initialize-CustomerProject.ps1`; this ADR fixes the
merged, hardened engine and the coherence invariants it must preserve, and records the whole-solution
integration pass that verified them.

## Options considered
1. **Blind global string replace** (`Customer`→X, `customer`→x, `hso_customer_`→p) across the tree.
   Pros: trivial. Cons: **corrupts** standard Dataverse identifiers (`customerid`, `parentcustomerid`,
   `customertypecode`), the generic form variable `customerId`, and any word containing the substring;
   order-dependent self-corruption (`hso` inside `hso_customer_`). Rejected — not bulletproof.
2. **Per-part init scripts.** Pros: local knowledge. Cons: five drift surfaces; no single coherence
   proof; the token contract is cross-cutting by definition. Rejected.
3. **One ordered, scope-aware engine + a copy-to-temp verification test** (chosen). A single ruleset,
   longest-token-first, with regex anchors and path scopes so generic identifiers survive; structured
   handling for config-value fields; file/folder renames; idempotency + a re-run guard; and a test that
   initializes a throwaway copy as `Contoso` and asserts zero orphans, a coherent chain, and a real build.

## Decision
Ship `ProjectTemplate/InitializeProjectScript/Initialize-CustomerProject.ps1` (+ `README.md`,
`HANDOVER-RUNBOOK.md`, `Test-Initialization.ps1`) as the keystone. It rewrites the ADR-0003 tokens across
the ProjectTemplate tree — content **and** token-bearing file/folder names — using this **ordered**
ruleset (longest/most-specific first so shorter tokens can't corrupt them):

| # | Token | → | Scope |
|---|-------|---|-------|
| 0 | `deployment-parameters-<projectCode>` | `deployment-parameters-<newProjectCode>` | all |
| 1 | `HSO.Customer` | `HSO.<CustomerName>` (HSO kept) | all |
| 2 | `hso_customer_` | `<publisherPrefix>_` | all |
| 3 | `cust_` (resolved old prefix) | `<publisherPrefix>_` | all (word-anchored) |
| 4 | `customer_` (web-resource prefix) | `<publisherPrefix>_` | all |
| 5 | `customer<UPPER>` (control-name token) | `<publisherUniqueName>` | **PCFControls only** |
| 6 | `customer[-.]` (slug) | `<publisherUniqueName>` | all |
| 7 | `Customer` (PascalCase) | `<CustomerName>` | all |
| 8 | config `projectCode`/`publisherUniqueName`/`publisherPrefix` values | new identity | config JSON |

**Scope, not a cleverer regex, is what keeps generic Dataverse names safe:** the lowercase-`customer`
+ UPPER rule (the only camelCase collision with the generic `customerId`) runs **only under
`PCFControls/`**; the slug rule matches `customer` only before `-`/`.`, which no standard Dataverse
identifier uses. Generated/build zones (`node_modules`, `bin`, `obj`, `dist`, `out`, `coverage`,
`packages`, `dataverse-gen`, PCF `generated/`) and this script's own folder are never rewritten.

Identity source of truth: `PipelinesHelpers/config/pipeline-defaults.json` `projectInfo.*`; parameters
override, omissions fall back. The engine is idempotent (a state marker records the applied identity;
re-running the same identity is a no-op) and **refuses** to re-initialize over a different identity
without `-Force`. `-WhatIf`/`-DryRun` preview without writing.

## The coherence contract (invariants a fresh init MUST satisfy)
1. **Zero token orphans** in source: no `HSO.Customer`, `hso_customer_`, `cust_`, PascalCase `Customer`,
   `customer_`, PCF `customer<UPPER>`, or `customer[-.]` remain (generated zones excluded).
2. **Config dependency chain intact** (ADR-0003): `publisherPrefix → solution names → schema names →
   web-resource paths → client `config.ts` `webResourcePrefix` → PCF namespace` all resolve to the same
   identity. Proven values for `Contoso`: prefix `cnto`, solutions `Contoso{Base,PCF,Build,Flows,…}`,
   schema `cnto_*`, client `webResourcePrefix:"cnto_"`, PCF `namespace="Contoso"`.
3. **Settings-file name agreement**: the `deployment-parameters-<projectCode>.json` file, its YAML
   references, and the emitter (`Ado-Emitter.ps1`, which builds the name from `projectInfo.projectCode`)
   all produce the same name — else the deploy can't find its `--settings-file`.
4. **Orphan-guard prefix agreement**: `monitoring/Get-OrphanedComponents.ps1`'s default schema prefix is
   retargeted to the project's prefix (it scans for the wrong prefix otherwise).
5. **Generic Dataverse identifiers preserved**: `customerid`/`parentcustomerid`/`customertypecode`/
   `customerId` survive untouched.

`Test-Initialization.ps1` asserts 1–5 on a temp copy and (best-effort) builds the renamed Server
solution. It is the executable form of this contract.

## Rationale
- **Bulletproof over clever.** The ordered+scoped ruleset is auditable and each rule has a one-line
  justification; the test proves both non-destruction (orphans = 0) and non-over-reach (generics intact),
  the two failure modes a rename engine has.
- **Config as source of truth** keeps the human-facing knob (`pipeline-defaults.json`) authoritative and
  lets the engine and any config-edit skill propagate the *whole* chain, never one link (ADR-0003 §chain).
- **Idempotent + guarded** makes init safe to re-run and impossible to double-apply destructively.

## Consequences
- A new engagement is one dry-run + one command + one test away from a building repo (see the runbook).
- The **only** variability in a live project is exactly these tokens, so a later template upgrade diffs
  cleanly against a customer repo (enables `hso-project-upgrade` / generated-file review, ADR-0003).
- Two coherence bugs were found and fixed during integration by the test itself (the orphan-guard prefix
  and the settings-file name); see `docs/review-logs/integration-01-review-r01.md`.
- The schema prefix has two neutral spellings in the blueprint (`hso_customer_` in Server/`config.ts`;
  `cust_` in `deployment-parameters`/monitoring); the engine reconciles both to `<publisherPrefix>_`.
  Accepted as a cosmetic dual-representation, not a functional gap (documented, covered by rules 2+3).
- Client type-checking (`tsc`) is not exercised by the test when `node_modules` is absent from the temp
  copy; the Client part's own converged suite covers it. Recorded as a known best-effort gap.
