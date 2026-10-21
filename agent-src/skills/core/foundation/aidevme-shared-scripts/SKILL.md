---
name: aidevme-shared-scripts
metadata:
  layer: foundation
  scope: core
description: |
  Shared PowerShell library dot-sourced by other aidevme- skills: Dataverse + Azure DevOps
  authentication (Get-DataverseToken / Get-AdoToken), the single Invoke-DataverseApi Web API
  invoker, ADO REST invoker, entity-name pluralisation, and project-config resolution. This is a
  LIBRARY skill, not a directly-invoked one.
  Use when:
  (1) You need to understand or change shared auth / Web API / project-config behaviour
  (2) You are authoring a skill that must call Dataverse or Azure DevOps (dot-source these modules
      rather than re-implementing auth or an HTTP invoker)
  Does NOT do anything on its own — there is no "run the shared-scripts skill" action; other skills
  reference its `scripts/` via a sibling-skill relative path.
---

# aidevme-shared-scripts (library skill)

`aidevme-shared-scripts` ships the centralised PowerShell modules the Dataverse and Azure DevOps skills
depend on, so auth and Web API logic live in exactly one place. It is **not invoked on its own** —
other skills dot-source its modules.

## Location in this template

The library lives at `agent-src/skills/core/foundation/aidevme-shared-scripts/` (source of truth) and is
fanned out **verbatim** by [`agent-src/sync/sync.ps1`](../../../../sync/sync.ps1) to
`.claude/skills/aidevme-shared-scripts/` and `.github/skills/aidevme-shared-scripts/`, exactly like any other
skill (ADR-0008). Because a skill folder is the unit of distribution, keeping the modules **inside**
this skill's `scripts/` folder means every consumer reaches them by one relative path that resolves
identically in both tool surfaces (the ADR-0019 sibling-library pattern):

```
<skills-root>/
├── aidevme-shared-scripts/scripts/   ← modules live here
├── aidevme-dataverse-data/scripts/   ← consumers dot-source ..\..\aidevme-shared-scripts\scripts
└── hso-ado-work-items/scripts/
```

This keeps the library under the `verify-parity.ps1` MD5 gate like every other generated skill — no
separate top-level `shared-scripts/` directory and no change to the sync mechanism were needed. It
supersedes the older Claude-only convention of a hand-maintained `.claude/shared-scripts/` folder
(which cannot exist in a template where `.claude/` is a generated output).

## Modules (`scripts/`)

| File | Purpose |
|------|---------|
| `Dataverse-Auth.ps1` | Dataverse auth (Interactive / DeviceCode / ServicePrincipal / ManagedIdentity), token caching, settings resolver |
| `Dataverse-WebApi.ps1` | HTTP headers, error handling, the single `Invoke-DataverseApi` wrapper, OData URL builder |
| `Dataverse-EntityNames.ps1` | Table logical name → OData entity-set name (pluralisation) |
| `ADO-Auth.ps1` | Azure DevOps auth (MSAL + PAT fallback), token caching |
| `ADO-WebApi.ps1` | ADO REST headers, error handling, the shared `Invoke-AdoRestMethod` wrapper |
| `Test-AdoWebApi.ps1` | Smoke test for the ADO invoker |
| `ProjectConfig.ps1` | Project-tier config resolved from the consuming repo's `CLAUDE.md` / `CLAUDE.local.md` (`Find-RepoRoot`, `Get-MarkdownConfigValue`, `Get-ProjectConfig`, …). **PS 5.1-clean.** |
| `Lint-SharedInvokerUsage.ps1` | Maintainer tool — flags skills that re-implement or shadow the shared invoker |
| `Lint-ScriptEncoding.ps1` | Maintainer tool — flags shipped scripts that cannot run under Windows PowerShell 5.1 |

### Managed-device auth fallbacks (standalone — run, don't dot-source)

For the case where a Conditional Access "require managed/compliant device" policy blocks the flows
`Get-DataverseToken` / `Get-AdoToken` use. They acquire a token by a different route and write it into
**the same cache files those functions already read**, so the next skill call picks it up with no
prompt and no code change.

| Script | Gets a token for | Route |
|---|---|---|
| `Connect-AdoViaAzCli.ps1` | Azure DevOps → `AdoAuthCache_<hash>.json` | Azure CLI WAM broker |
| `Connect-DataverseViaAzCli.ps1` | Dataverse → `DataverseAuthCache_<hash>.json` | Azure CLI WAM broker |
| `Connect-DataverseViaDeviceCode.ps1` | Dataverse → `DataverseAuthCache_<hash>.json` | Device code (where CA permits it) |

The WAM-broker scripts work where device code does not because they carry the device's Primary Refresh
Token, which satisfies "require managed device". Both discover the target's own tenant from its
unauthenticated 401 challenge (Dataverse) or the az session (ADO); override with `-Tenant <guid>` when
discovery can't reach the endpoint. They run under both Windows PowerShell 5.1 and PowerShell 7 by
design — they are the fallback for hosts where the other paths already failed.

## How to consume (dot-source pattern)

At the top of any skill script (which lives at `skills/<skill>/scripts/`), resolve the sibling library
skill and dot-source the modules you need:

```powershell
$sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl
```

For ad-hoc / composed scripts where `$PSScriptRoot` doesn't point into a skill folder, use the robust
resolver in [`references/shared-modules.md`](references/shared-modules.md).

## Runtime

PowerShell 7+ (`pwsh`) for the auth and Web API modules (they use PS7 idioms). **`ProjectConfig.ps1`
is deliberately PS 5.1-clean** — its consumers include a `#Requires -Version 5.1` linter — and it
skips `Set-StrictMode` because it is dot-sourced (a mode set in a dot-sourced file leaks into the
caller's scope). Keep both properties when editing it.

## Auth settings

The resolver reads (in priority order) explicit parameters → environment variables → a gitignored
`auth-settings.json` (`.claude/auth-settings.json` in a consuming repo) → default Interactive. No
tenant, org, or client identity is baked into the neutral template; the Microsoft **public** client
IDs (Common Data Service `51f81489-…`, Azure CLI `04b07795-…`) and the fixed Azure DevOps resource ID
(`499b84ac-…`) are the only GUIDs shipped, and those are Microsoft's own well-known values.

## Reference

- [`references/shared-modules.md`](references/shared-modules.md) — auth modes, `auth-settings.json`,
  function signatures, the ad-hoc resolver, and execution patterns.
- [`references/verification-quick-client.md`](references/verification-quick-client.md) — policy +
  blessed recipe for ad-hoc Web API clients on verification legs (read-only probes / throwaway
  fixtures only; all metadata writes stay on skill scripts).

## Notes on this port

- Ported from the ForgeUSA `aidevme-shared-scripts` library and **neutralised** to the ADR-0003 token
  contract (no client / org / tenant / user identity; Forge-USA dev-clone cred paths removed).
- The Forge governance modules `Wiki-Tiers.ps1` and `Resolve-GovernanceContext.ps1` were **not**
  ported — they encode a multi-tier policy-registry governance model this template has not adopted;
  see `docs/skill-merge/things-to-review-later.md`.
- The Forge `license:` frontmatter line was dropped (neutral-by-construction; see ADR-0003 and the
  review-later note on agent-model improvement E).

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | aidevme | Wave-0 port from ForgeUSA; neutralised; governance modules deferred; placed as a foundation library skill under the ADR-0008 sync (no sync change needed). |
| 2026-10-21 | aidevme | New [CHANGELOG.md](CHANGELOG.md): the skill's full history from its commits. |
