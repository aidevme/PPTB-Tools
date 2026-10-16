# Part 4 (Pipelines) — Expert self-review r01

Reviewer role: senior Power Platform ALM / Azure DevOps architect.
Scope: `ProjectTemplate/Pipelines/**` + `ProjectTemplate/PipelinesHelpers/**`.
Method: build → static verification (parse, YAML lint, schema, integrity, idempotency) → line-by-line
critique against the 13 required behaviours from the live-delivery source and general ALM correctness → fix → re-verify.

## Verification evidence gathered before critique
- **PowerShell parse**: all 17 `.ps1` parsed with `[Parser]::ParseFile` — pwsh 7.6.5. (1 error found + fixed, see R01-01.)
- **Generator run**: stamps all 12 marker-bearing pipelines from the sample config; dry-run + real run both clean.
- **YAML parse**: 14/14 pipeline YAMLs `yaml.safe_load` clean (pyyaml 6.0.3) — ADO `${{ }}` keys are valid YAML strings.
- **Outside-marker integrity**: skeletonised diff vs pre-stamp backup — 0 files changed outside a marker region.
- **Config schema**: all 3 config JSONs validate against their draft-07 schemas (`jsonschema`).
- **Idempotency**: second generator run updates 0 files.

## Findings

| # | Sev | File | Finding | Disposition |
|---|-----|------|---------|-------------|
| R01-01 | High | `scripts/solution-deploy/Import-Solutions.ps1` | `"…deploymentTier=$dt: not deployed…"` — `$dt:` parsed as a scoped-variable reference → parse error, script would never run. | **Fixed**: `${dt}`. Re-parsed clean. |
| R01-02 | Med | `scripts/emitters/Ado-Emitter.ps1` | `*-ENV-VALUES` markers emitted only the list items, dropping the `values:` key → a `type: string` parameter followed directly by `- 'x'` is invalid YAML. | **Fixed**: value bodies now prepend `  values:`. Re-parsed all YAML clean. |
| R01-03 | Med | `scripts/emitters/Ado-Emitter.ps1` | `deploymentParametersFile`, `importCeilingHours`, `deleteAndPromoteMaxSubmissions` were hardcoded in `deploy-solutions.yml`/`sprint-deploy.yml` and not stamped — on a project rename the settings-file path would still say `-customer`, silently binding no connection references/env vars. | **Fixed**: added scalar stamping (`Set-ScalarDefault … -Key value`) from `projectInfo.projectCode` + `pipelineDefaults.deployPipeline.*`. |
| R01-04 | Low | generator | The `# --- auto-generated …` note is emitted at column 0 inside indented marker regions (e.g. a `values:` list). | **Accepted**: YAML comments are position-independent; pyyaml confirms valid. Cosmetic only. |
| R01-05 | Low | design | Scalar stamping (`Set-ScalarDefault`) edits a named `default:`/`value:` *outside* a marker block. | **By design, documented**: the "nothing outside markers moves" guarantee is about generated *blocks*; a short, explicitly-named allow-list of scalar defaults is a separate, intentional channel (CDX pattern). Recorded in ADR-0007. |
| R01-06 | Info | deploy/sprint | ADO boolean params expand to `True`/`False`; scripts compare against lowercase `'true'`. | **Verified no-op**: both ADO expression `ne()`/`eq()` and PowerShell `-eq` are case-insensitive. No change. |
| R01-07 | Med | `solution-deploy/deploy-solutions.yml` | `DeployUAT`/`DeployProduction` `dependsOn: PackSolutions`, which is runtime-*skipped* in Solutions-Packed mode — a default `succeeded()` would then skip the deploy. | **Verified correct**: explicit `condition: and(not(failed()), not(canceled()))` overrides the implicit `succeeded()`, so a skipped (not failed) pack does not block the deploy; a failed pack does. |
| R01-08 | Info | `deploy-steps.yml` | `settings.json`, plugin snapshot, and `solutionsImported` cross tasks. | **Verified**: all consumers run in the *same* deployment job (same agent/temp/variable scope). OK. |

## Requirement-by-requirement critique (the 13)

All 13 traced to concrete emitter/script/YAML and spot-checked. See the convergence doc for the coverage
table. No requirement found unaddressed in r01. The only defects were the three implementation bugs above
(R01-01..03), all fixed and re-verified; the remaining items are verifications with no code change.

## Outcome
r01 found 3 fixable defects (1 High, 2 Medium) and 5 verifications. All fixes applied and the full
verification suite re-run green (parse / YAML / integrity / schema / idempotency). No open High/Medium
findings remain → proceed to convergence (r02 confirms the re-verified state; no further code changes were
needed, so a separate r02 log would only restate this green run — folded into convergence).
