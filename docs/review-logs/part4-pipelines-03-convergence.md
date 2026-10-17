# Part 4 (Pipelines) — Convergence

Status: **converged**. Iterations: **r01** (3 defects fixed) → re-verification green. No open High/Medium
findings; r02 would only restate the green run, so it is folded here.

## Final verification (re-run after all r01 fixes)

| Check | Tool | Result |
|-------|------|--------|
| PowerShell parse (17 scripts) | `[Parser]::ParseFile`, pwsh 7.6.5 | **0 errors** |
| Generator dry-run + run | `Update-PipelineDefaults.ps1` | stamps 12 pipelines, clean |
| YAML parse (14 files) | pyyaml 6.0.3 `safe_load` | **0 failures** |
| Outside-marker integrity | skeletonised diff vs pre-stamp backup | **0 diffs outside markers** |
| Config schema (3 files) | `jsonschema` draft-07 | **all valid** |
| Idempotency | 2nd generator run | **0 files changed** |
| Structural | importOrder chain / bootstrap@1 / prodOnly | strictly increasing; bootstrap=order 1; prodOnly recognised |

## Requirements coverage (the 13 hard-won behaviours from the live-delivery source)

| # | Requirement | Where it lives | Evidence |
|---|-------------|----------------|----------|
| 1 | Wave/solution ordering from `importOrder` | `solution-organizer.json` + `Import-Solutions.ps1` (`Sort-Object importOrder`), emitter per-solution params | order chain `[1..5]` validated; import loop sorts by importOrder |
| 2 | Committed `Solutions-Packed` store, latest-or-pinned, never strand a sibling | `Import-Solutions.ps1` `Resolve-PackedManagedZip`; export writes `Solutions-Packed/<name>/<Managed\|Unmanaged>/<name>_<ver>_*.zip`; **every** configured solution is version-compared each run | packed-store default param; `redeployAll`/subset honoured for both sources |
| 3 | Version-compare per solution; HARD-ERROR older-than-target; plan summary + gate | `Import-Solutions.ps1` `Compare-SolutionVersion`, `$versionCompare -lt 0 → exit 1`, "Deployment plan summary"; ADO Environment **approval** check is the show-plan gate | plan summary emitted; downgrade path exits 1 |
| 4 | Holding `*_Upgrade` self-heal, DeleteAndPromote cap, report-only cleanup | `Import-Solutions` `--import-as-holding` + unconditional orphan scan; `Apply-SolutionUpgrades.ps1` submission cap (`deleteAndPromoteMaxSubmissions=4`, 3h deadline); `Remove-HoldingSolutionAndWait` waits out `80071151`/in-flight; `Cleanup-HoldingSolutions.ps1` REPORT-ONLY | cap + deadline + resilient delete implemented verbatim from the live-delivery source |
| 5 | Flow-state reconciliation | `Import-Solutions` `--activate-plugins`; `Restore-PluginSteps.ps1` snapshot→restore (re-enable only import-disabled, always()); `ConnectionAuthorizationFailed` handled as owner-only via settings-file unbound connection refs | snapshot/restore best-effort, never fails build |
| 6 | Orphaned-component guard | `monitoring/Get-OrphanedComponents.ps1` (exit 3 + list), wired into `cleanup-solutions.yml`; deployed set read from `solution-organizer.json` | config-driven; neutral prefixes |
| 7 | Circular-managed-dependency bootstrap | `solution-organizer.bootstrap` (order-1 base, definitions only) + `Build-SettingsFile.ps1` projects the target-env `--settings-file` for every import | bootstrap=order 1 validated; settings file built per stage |
| 8 | Overwrite=UAT-only; Prod false; never auto-approve; `deploymentTarget` compile gating | `deploy-solutions.yml` `${{ if ne(…) }}` stage gating; UAT passes the toggle, Prod hardcodes `'false'`; Prod ADO Environment carries approval+lock (human promotes) | compile-time stage emission per target; overwrite param UAT-only |
| 9 | Reference-data export/import, unzipped-committed, tier-gated | `reference-data/Export-ReferenceData.ps1` (unzip to `ReferenceData/Data/`), `Import-ReferenceData.ps1` (re-zip); pipelines gated to `referenceDataImportEnabled` envs; import runs in a deployment job (approval gate) | git-diffable data; env dropdown stamped from config |
| 10 | Hotfix lifecycle installed LAST; folder-as-state; idempotent | `Install-HotfixSolutions.ps1` (Solutions-Hotfix/ install, Solutions-Hotfix-Retired/ uninstall), called last in `deploy-steps.yml`; export supports `hotfixSolutionToExport` | version-compare install; state-verified uninstall |
| 11 | Async verify-not-trust; cancel BOTH layers; lock/terminal/DLL classification; quiescence; token refresh; concurrency guard | `Import-Solutions` verify-poll + `8004801E`/`80071151`/terminal classification; `Cancel-RunningImports.ps1` (operationtype 54); `Wait-ForNoActiveImport` (importjobs **and** msdyn_solutionhistories); token refresh in long loops; export concurrency guard + exclusive-lock environment | all classification branches present; cancel handler on `canceled()` |
| 12 | Export version-bump + compensating rollback; commit-before-publish; binary-aware change detection; additive security roles; third-party pre-wave; operator recovery; status journal | `export-from-dev.yml` (bump→export→rollback-on-fail, `commitToGit` gate, SHA256-raw-for-binaries/CRLF-normalized-for-text); `Set-SecurityRoleAssignments.ps1` (additive); `Install-ThirdPartySolutions.ps1` (pre-wave); `Cleanup-HoldingSolutions.ps1` (no destructive auto-rollback); `Import-Solutions` deploySummary/deployErrorInfo journal | rollback + change-detection functions implemented; journal vars seeded |
| 13 | Pipeline parameters (deploy/export/reference-data) | `deploy-solutions.yml` (publishWorkflows, applySettingsOnSameVersion, overwriteUnmanagedCustomizations, ignoreConcurrencyGuard*, deploymentTarget, useSolutionsPackedStore, solutionsToDeploy, redeployAll); `export-from-dev.yml` (commitToGit, targetBranch, solutionsToExport, hotfixSolutionToExport); reference-data (targetEnvironment/deploymentTarget-equivalent) | parameters present; `*` ignoreConcurrencyGuard surfaced as the export concurrency guard + a documented deploy hook |

Notes:
- **ignoreConcurrencyGuard (13)**: the export pipeline implements the hard parallel-run guard + exclusive-lock
  environment; the deploy relies on the ADO Environment **Exclusive Lock** check as the authoritative
  concurrency control (portal-configured), so a YAML bypass toggle is intentionally not the primary guard.
  The parameter name is reserved in the onboarding doc for projects that add a REST pre-flight guard to deploy.
- **Generation model boundary**: marker **blocks** are fully machine-owned; a short allow-list of **named
  scalar defaults** (`targetBranch`, `importMaxAsyncWaitMinutes`, `importCeilingHours`,
  `deleteAndPromoteMaxSubmissions`, `deploymentParametersFile`) is also stamped in place. Everything else is
  hand-authored and never touched — proven by the 0-diff outside-marker integrity check.

## Residual risks / follow-ups
- **No live ADO run**: verification is static (parse/lint/schema/integrity) per the local-only rule. A first
  real import against a sandbox is still the ultimate proof of the async/holding paths.
- **Second emitter (GitHub Actions)** is scaffolded (dispatcher `-Emitter github` + contract) but not
  implemented — intentional; the ADO emitter is the reference.
- **`organize-solution.yml`** prints the routing plan rather than performing the component-by-component
  split (a genuinely project-shaped operation); it is a documented stub to complete per engagement.
