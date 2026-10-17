---
title: "Integration — whole-solution review r01"
part: 6
kind: review-log
iteration: 01
author: aidevme
date: 2026-09-10
status: accepted
---

# Integration — whole-solution review (r01)

Fresh-eyes cross-part review after the five parts converged individually. Scope: the init keystone
(built this pass), cross-part token/config coherence, and client-specific leakage across shipped template
code + ported docs. Findings carry a severity and file; fixes applied this pass are marked, with r02
verification via `Test-Initialization.ps1` and the leakage re-grep.

Severity: **BLOCKER** (a fresh init yields a broken/incoherent project) · **HIGH** (coherence/leakage that
would ship wrong) · **MED** · **LOW**.

## A. Init-engine correctness (the missing keystone)

| # | Finding | Sev | Resolution | Verified |
|---|---------|-----|-----------|----------|
| I1 | No init engine existed — `InitializeProjectScript/` was empty; the token contract (ADR-0003) had no executor and no coherence proof. | BLOCKER | Built `Initialize-CustomerProject.ps1` (ordered, scope-aware rewrite + renames + idempotency + guard) and `Test-Initialization.ps1`. | test: **ALL HARD ASSERTIONS PASSED** |
| I2 | A blind `customer`→x replace would corrupt generic Dataverse names (`customerid`, `parentcustomerid`, `customertypecode`) and the client's generic `customerId`. | BLOCKER (design) | Scoped rules: camelCase rule PCF-only; slug rule matches only `customer[-.]`. Test asserts generics survive (39 intact) *and* zero orphans. | test |
| I3 | Order hazard — `hso` is a substring of `hso_customer_`; `cust` of `customer`. | HIGH (design) | Longest-first ordered ruleset with word-anchors; verified idempotent (re-run is a byte-for-byte no-op). | test |

## B. Cross-part coherence

| # | Finding | Sev | File | Resolution | Verified |
|---|---------|-----|------|-----------|----------|
| C1 | **Orphan-guard scans the wrong prefix.** `monitoring/Get-OrphanedComponents.ps1` hardcodes `$CustomPrefixes = @('cust_')`; a project on prefix `cnto_` would have its orphan guard silently match nothing. Original `cust_` rule was scoped to config files, leaving this `.ps1` untouched. | BLOCKER | `PipelinesHelpers/scripts/monitoring/Get-OrphanedComponents.ps1` | Broadened the `cust_` rule to tree-wide (word-anchored — safe off `custom`/`customer`). | test orphan-scan clean |
| C2 | **Settings-file name three-way mismatch.** The deploy `--settings-file` name is built by `Ado-Emitter.ps1` from `projectInfo.projectCode` (`deployment-parameters-<code>.json`), but the shipped YAML + file used `-customer.json`, and the slug rule would rename them to `-contoso.json` while the emitter emits `-CNTO.json` → deploy can't find its settings file. | BLOCKER | `Pipelines/solution-deploy/deploy-solutions.yml`, `sprint-deploy.yml`, `PipelinesHelpers/config/deployment-parameters-customer.json` | Added rule 0 keying this filename to `projectCode`; file, YAML, and emitter now all yield `deployment-parameters-CNTO.json`. | test: 3 new assertions pass |
| C3 | Config chain end-to-end: publisherPrefix → solution names → schema names → web-resource path → client `config.ts` → PCF namespace. | HIGH (verify) | (cross-part) | Proven coherent by the orphan test (0 token orphans anywhere) + explicit chain assertions. | test |
| C4 | `solution-organizer.json` vs what the parts imply: 5 solutions, importOrder Base→PCF→Build→Flows→FlowsTeamA (bootstrap base first, PCF before the build/forms, flows last), `defaultSolution=…Build`. | — (pass) | `PipelinesHelpers/config/solution-organizer.json` | Matches ADR-0007 and the parts' outputs; no change. | reviewed |
| C5 | Schema-prefix token has two neutral spellings: `hso_customer_` (Server, `config.ts`) vs `cust_` (`deployment-parameters`, monitoring). | LOW | (cross-part) | Accepted as cosmetic; engine reconciles both to `<publisherPrefix>_` (rules 2+3). Documented in ADR-0009. | test |
| C6 | Root `AGENTS.md`/`CLAUDE.md` sit outside `ProjectTemplate` (not init-processed). Confirmed they reference the tokens only as *documentation* of ADR-0003, not as live component tokens. | — (pass) | `AGENTS.md`, `CLAUDE.md` | No change needed; correctly token-neutral. | grep |

## C. Client-specific leakage (shipped code + ported docs)

Independent scan of `ProjectTemplate/**` (excluding build output), `AGENTS.md`, `CLAUDE.md`, and
`agent-src/skills/**/SKILL.md`. `AGENTS.md`/`CLAUDE.md` were **clean**. Leakage found and neutralised
(preserving each technical lesson) in a dedicated cleanup pass:

| # | Category | Sev | Count (r01) | Action |
|---|----------|-----|------------:|--------|
| L1 | Client name (live-delivery source) in comments/READMEs | HIGH | 55 | Genericised ("the reference delivery"/"a prior delivery"), lesson kept. |
| L2 | Real ticket IDs `AP-nnnn` in PCF gotchas/tests | HIGH | 14 | Stripped the `(AP-nnnn)` ref, kept the platform lesson. |
| L3 | Real solution names (the wave + PCF-wave aggregators) | MED | 2 | Genericised to descriptive neutral. |
| L4 | Real environment URL `dev1demos14.crm3.dynamics.com` (CDX toolchain leftover) | MED | 1 | → placeholder `your-dev-org.crm4.dynamics.com`. |
| L5 | Person names (`Author: aidevme` in a shipped tool; `Keith Whatling` in a skill changelog) | MED | 2 | Neutralised shipped-tool author; dropped the contributor name. |
| L6 | Real-looking Dataverse record GUID as a test fixture | LOW | 1 | Swapped for an obviously-synthetic GUID (kept the test consistent). |

**Deliberately preserved** (per task scope): `agent-src/sync/skills-manifest.json` `source:` fields
(provenance metadata); everything under `docs/review-logs/` and `docs/decisions/` (the analysis/build
audit trail — citing the live-delivery source/CDX/HINT there is correct); the rule line in `Server/README.md`
("never put a real customer name in template files") — it *is* the rule; and the internal
lineage codenames **CDX**/**HINT** (design-lineage, not customer/PII — analogous to the manifest
`source:` exception).

## D. Part-level issues spotted with fresh eyes

| # | Finding | Sev | Note |
|---|---------|-----|------|
| P1 | The template ships committed build output (`Server/**/bin,obj`, PCF `dist,out`, Client `coverage`) in the working tree though gitignored. Harmless (excluded from init + orphan scan) but noise. | LOW | Left as-is; a `git clean`-equivalent is a repo-hygiene chore, not an init concern. The init and its test both skip these zones. |
| P2 | Client `tsc` not exercised post-init (temp copy omits `node_modules`). | LOW | Client part's own converged suite type-checks; recorded as best-effort gap in ADR-0009. |
| P3 | `Solutions/` ships empty (populated by export). | — | Correct per CLAUDE.md (Dataverse→export→Solutions is one-way); nothing to retarget. |

All BLOCKER/HIGH items are resolved and verified. See `integration-03-convergence.md` for the final
evidence and residual-risk register.
