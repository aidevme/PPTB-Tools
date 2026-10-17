# Onboarding — Pipelines

This is the deployment machinery for a Power Platform / Dataverse project: real Azure DevOps YAML whose
per-project regions are **generated** from JSON config, backed by hardened PowerShell that carries the
lessons of many real releases. Read ADR-0007 for the why; this is the how.

## The mental model in 30 seconds
1. You fill in three JSON files under `ProjectTemplate/PipelinesHelpers/config/`.
2. You run one script — `Update-PipelineDefaults.ps1` — which stamps the marker regions of every pipeline.
3. You run `Setup-AzureDevOps.ps1` (+ a few portal steps) to create the ADO objects.
4. You import the pipelines. From then on: **export from Dev → deploy to UAT → (human approves) → Prod.**

## The three config files (the only things you edit)
| File | You set… |
|------|----------|
| `pipeline-defaults.json` | project code/publisher, and each **environment** (name, url, service connection, `tier`, `branch`, flags). `tier` is load-bearing: `dev` is never a deploy target, `prod` forces an approval gate + hardcodes overwrite off. |
| `solution-organizer.json` | your solutions, their **`importOrder`** (the dependency chain — get this right or a *first install* breaks), and role flags: `bootstrap` (the order-1 base holding connection-ref + env-var *definitions only*), `deploymentTier: prodOnly\|nonProd\|all`, `isPcf`. |
| `deployment-parameters-{code}.json` | per-environment connection GUIDs and env-var values → projected into the pac `--settings-file` on every import. |

Run `discover-deployment-parameters` against an environment to generate the third file's skeleton.

## Generate + set up
```powershell
# from PipelinesHelpers/scripts
pwsh -File Update-PipelineDefaults.ps1 -WhatIf   # preview
pwsh -File Update-PipelineDefaults.ps1           # stamp the marker blocks
pwsh -File Setup-AzureDevOps.ps1 -Organization https://dev.azure.com/<org> -Project <proj>   # dry-run
pwsh -File Setup-AzureDevOps.ps1 ... -Apply      # create environments + variable groups
```
Then, in the ADO **portal** (the CLI can't do these):
- Create a **service connection** (workload-identity federation) per environment, named exactly as
  `environments.*.serviceConnection`.
- On each **Environment**: add an **Exclusive Lock** check (serialises runs). On UAT/Prod: add an
  **Approvals** check. **The assistant never approves the Prod gate — a human promotes.**
- If you use **secret** env vars: grant the *Dataverse service principal* Key Vault Secrets User on the vault.
- Import each `Pipelines/**/*.yml`; point the `solutions` repo resource at `repositories.solutionsRepository`.

## The pipeline catalogue
| Pipeline | Purpose |
|----------|---------|
| `solution-export/export-from-dev.yml` | Export changed solutions from Dev (binary-aware change detection), version-bump with compensating rollback, unpack to `Solutions/`, drop versioned zips into `Solutions-Packed/`, commit. Also exports a single hotfix (`hotfixSolutionToExport`). |
| `solution-deploy/deploy-solutions.yml` | The release. Version-compare per solution (no silent downgrade), holding import + DeleteAndPromote, plugin snapshot/restore, additive security roles, hotfixes last. `deploymentTarget` chooses UAT / Prod / UAT-then-Prod (compile-time). |
| `deploy-to-dev/deploy-to-dev.yml` | Re-apply committed *unmanaged* XML back into Dev. |
| `reference-data-export` / `reference-data-import` | Config Migration data, committed unzipped (git-diffable). |
| `sprint-deploy/sprint-deploy.yml` | Fast mid-sprint deploy to a test-tier env (never Prod). |
| `validate-dependencies` | Read-only: report import-order vs installed; flags an uninstalled bootstrap. |
| `solution-cleanup` | Read-only: the orphaned-component placement guard (exit 3 if a custom component isn't in a deployed wave). |
| `discover-deployment-parameters` | Emit the `deployment-parameters` skeleton from a live env. |
| `solution-organizer` | Split a monolith into the per-concern solutions by component type (project stub). |
| `provision-environment` / `clone-environment` | Verify connectivity/publisher; report version parity. |
| `code-validation` | PR gate: build+test C# plugins and TS client/PCF. (No project-specific markers.) |

## Deploy parameters you will actually use
- **deploymentTarget** — `UAT only` (default) / `Prod only` / `UAT then Prod`.
- **useSolutionsPackedStore** — on (default): deploy the committed versioned zips (never strands a sibling).
  Off: pack managed from source this run.
- **solutionsToDeploy** — `(all)` or `Name=Version, Name2` to pin an exact tested set.
- **overwriteUnmanagedCustomizations** — UAT cleanup only; Prod ignores it.
- **redeployAll** — force re-import even when versions match (a full refresh; still never a downgrade).
- **publishWorkflows**, **applySettingsOnSameVersion**, **importMaxAsyncWaitMinutes**.

## When a deploy goes sideways
- The import loop **verifies against Dataverse** before declaring failure (a CLI wait-timeout is not a
  failure). Missing-deps / unresolved-references fail *fast*; lock conflicts (`80071151`) and the plugin-DLL
  lock (`8004801E`) retry.
- **Cancelling the pipeline is not enough** — a submitted import runs server-side. The cancel handler calls
  `Cancel-RunningImports.ps1` to stop the Dataverse async op too. On failure/cancel the cleanup step only
  *reports* leftover `*_Upgrade` holding solutions; the **next run** removes them resiliently.
- If Prod ends up wrong: there is **no destructive auto-rollback** — an operator re-runs with the correct
  pinned `solutionsToDeploy`, or investigates Solution History. The pipeline never blind-deletes on Prod.

## Adding a GitHub Actions target
The generator is emitter-factored. Add `PipelinesHelpers/scripts/emitters/GhActions-Emitter.ps1` exposing
`Invoke-GhActionsEmitter -Config -Organizer -PipelinesPath -WhatIf`, author the workflow YAML with the same
marker regions, and run `Update-PipelineDefaults.ps1 -Emitter github`.
