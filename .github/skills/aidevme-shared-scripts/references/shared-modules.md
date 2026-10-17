# Shared Modules

Centralized PowerShell functions used across all skills that interact with Dataverse Web API and Azure DevOps REST API.

> **Runtime: PowerShell 7+ (`pwsh`).** The modules and the snippets in this README use PS7 idioms
> (ternary `? :`, null-coalescing `??`, pipeline chain operators). Invoke them with `pwsh`, not
> Windows PowerShell 5.1 (`powershell.exe`) — a 5.1 host will throw on those constructs. If you must
> run under 5.1, rewrite ternaries as `if/else` and avoid `??`/`?.`.

## Authentication Modes

Both auth modules use a **settings-driven resolver** that auto-selects the right auth flow. The priority is:

1. **Explicit parameters** (e.g., `-Interactive`, `-ClientId`/`-ClientSecret`) — backward-compatible
2. **Environment variables** (`DATAVERSE_AUTH_MODE`, `ADO_AUTH_MODE`, etc.)
3. **Settings file** (`<repo-root>/auth-settings.json` — gitignored, see template; resolved at
   `.claude/auth-settings.json` in a consuming repo — the populated creds never live inside the
   generated/synced skill tree)
4. **Default**: Interactive

### Available Modes

| Mode | Dataverse | ADO | Use Case |
|------|:---------:|:---:|----------|
| `Interactive` | ✅ | ✅ | Local dev with browser (default) |
| `DeviceCode` | ✅ | ✅ | Local headless/SSH, MFA-friendly |
| `ServicePrincipal` | ✅ | ✅ | Automated pipelines, hosted agents |
| `ManagedIdentity` | ✅ | ✅ | Azure-hosted agents (zero secrets) |
| `Pat` | — | ✅ | ADO orgs restricting OAuth consent |

### Configuration

Copy [`auth-settings.template.json`](auth-settings.template.json) to the consuming repo's gitignored
`.claude/auth-settings.json` and set values for your scenario:

```json
{
  "DataverseAuthMode": "ServicePrincipal",
  "DataverseEnvironmentUrl": "https://yourorg.crm.dynamics.com",
  "AdoAuthMode": "Interactive",
  "AdoOrgUrl": "https://dev.azure.com/<org>"
}
```

Environment variables override file settings:
- `DATAVERSE_AUTH_MODE`, `DATAVERSE_ENVIRONMENT_URL`, `DATAVERSE_CLIENT_ID`, `DATAVERSE_CLIENT_SECRET`, `DATAVERSE_TENANT_ID`
- `ADO_AUTH_MODE`, `ADO_ORG_URL`, `ADO_PAT`, `ADO_CLIENT_ID`, `ADO_CLIENT_SECRET`, `ADO_TENANT_ID`

### Environment Guard

When `DataverseEnvironmentUrl` is set in settings, the resolver **rejects** requests targeting a different URL. This prevents accidental operations against the wrong environment.

## Modules

| File | Purpose |
|------|---------|
| `Dataverse-Auth.ps1` | Dataverse authentication (interactive MSAL.PS + service principal), token caching |
| `Dataverse-WebApi.ps1` | HTTP headers, error handling, `Invoke-DataverseApi` wrapper, OData URL builder |
| `Dataverse-EntityNames.ps1` | Table logical name to entity set name (pluralization) |
| `ADO-Auth.ps1` | Azure DevOps authentication (interactive MSAL.PS + PAT fallback), token caching |
| `ADO-WebApi.ps1` | ADO REST headers, error handling, and the shared `Invoke-AdoRestMethod` wrapper |
| `ProjectConfig.ps1` | Project-tier config resolved from the consuming repo's CLAUDE.md / CLAUDE.local.md (PS 5.1-clean) |

## Usage — Dataverse

At the top of any Dataverse skill script, dot-source the modules you need:

```powershell
# Resolve the sibling aidevme-shared-scripts library skill relative to this script
$sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
. "$sharedDir\Dataverse-EntityNames.ps1"

# Authenticate
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive

# Make API calls
$headers = Get-DataverseHeaders -Token $token -IncludeAnnotations $true
$url = Build-DataverseQueryUrl -BaseUrl $EnvironmentUrl -EntitySetName "accounts" -Top 10
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

# Or use the generic wrapper
$response = Invoke-DataverseApi -Method Get -Endpoint "accounts?`$top=10" -IncludeAnnotations $true
```

### Loading from an ad-hoc / composed script (ADR 0013)

The `$PSScriptRoot` form above only resolves for a script that lives **inside a skill folder**
(`skills/<skill>/scripts/` or `references/`). When you compose a throwaway script (e.g. in a temp
dir) or run inline, `$PSScriptRoot` points at the wrong place — don't go searching for the module.
In a generated project the modules live in the sibling library skill at
**`.claude/skills/aidevme-shared-scripts/scripts/`** (and, identically, `.github/skills/...`), and the
session's working directory is the repo root, so dot-source by the repo-root-relative path:

```powershell
$shared = ".claude\skills\aidevme-shared-scripts\scripts"            # generated project (runtime)
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl
```

Robust resolver — tries each known location, picks the first that exists (never search for it):

```powershell
$shared = @(".claude\skills\aidevme-shared-scripts\scripts",
            ".github\skills\aidevme-shared-scripts\scripts",
            (Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts")) |
          Where-Object { Test-Path "$_\Dataverse-Auth.ps1" } | Select-Object -First 1
. "$shared\Dataverse-Auth.ps1"; . "$shared\Dataverse-WebApi.ps1"
```

### Running composed calls (execution pattern)

How a composed call is *run* matters as much as how it's written:

- **Default to a temp `.ps1` run with `-File`** — not `-Command "..."` piped through Bash. Inline
  `-Command` strings hit backtick/quote-escaping hell with OData (`` `$expand ``, `` `$filter ``) and
  nested `& { }`. Write the script to a temp file and run `powershell.exe -File <path>`. This is the
  default, not the fallback. **Scope: this is for a self-contained call you author** — all values are
  literals baked into the script body, so there is no typed-parameter marshalling to go wrong.
- **But when you INVOKE a skill script that takes typed parameters, do NOT marshal them across a fresh
  `-File` process — call it in-process with the `&` call operator.** `powershell.exe -File Script.ps1
  -Switch ... -ArrayParam a,b ...` re-parses every argument as a **string** in a new process, and three
  build-wave defects came from exactly this (skill-gap register #8–#10):
  - **Array params flatten:** `-KeyColumns a,b` (or a PowerShell array) arrives as a single string, so an
    alternate key meant to span two columns silently became **one**.
  - **Booleans coerce to strings:** `-IsAuditEnabled $true` arrives as `"True"`/`"1"`, which the Web API
    rejects with an **OData 400 (Edm.Boolean)**.
  - **Some scripts hang** (zero output, idle process) under `-File`.
  The fix: dot-source the script (or `& <path> -Param $typedValue`) **inside the current PowerShell
  session** so arrays stay arrays and `$true` stays a boolean. Reserve `-File` for the literals-only case
  above; never use it to pass an array or boolean into a skill script.
- **Never pipe `powershell.exe` output into a PowerShell cmdlet from Bash.** In
  `powershell.exe ... | Select-String ...` the Bash shell owns the pipe, so `Select-String` runs as a
  (nonexistent) Bash command and the PS output never reaches it. Do all filtering/formatting
  **inside** the script, or don't filter.

### Function signatures (the three you'll use most)

```powershell
Get-DataverseToken   -EnvironmentUrl <url>          # resolves auth from settings; sets the script-scope token + env
Get-DataverseHeaders -Token <tok> [-SolutionName <s>] [-ReturnRepresentation $true] [-IncludeAnnotations $true] [-MergeLabels $true]
Invoke-DataverseApi  -Method <m> -Endpoint <relative> [-Body <obj>] [-SolutionName <s>] [-Headers <ht>] [-ReturnRepresentation $true]
```

After `Get-DataverseToken`, `Invoke-DataverseApi` reuses the script-scope token and env — you can
omit `-Token` / `-EnvironmentUrl`. Pass `-SolutionName` to add the `MSCRM.SolutionUniqueName` header
on a solution-aware write.

## Usage — Azure DevOps

ADO-Auth.ps1 depends on `Dataverse-Auth.ps1` for the `Install-MsalModuleIfMissing` function:

```powershell
$sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"   # provides Install-MsalModuleIfMissing
. "$sharedDir\ADO-Auth.ps1"

# Interactive authentication (MSAL.PS)
$auth = Get-AdoToken -OrgUrl "https://dev.azure.com/MyOrg" -Interactive
$headers = Get-AdoHeaders -Token $auth.Token

# PAT fallback
$auth = Get-AdoToken -OrgUrl "https://dev.azure.com/MyOrg" -Pat $myPat
$headers = Get-AdoHeaders -Pat $auth.Pat
```

## Standalone copies (data-migration bundles)

Some skills ship a **standalone** helper library that gets copied verbatim into a generated repo's data
scripts (a migration/reference-data bundle, for example). Such a copy must remain self-contained — no
dependency on this library skill — because the bundle runs where `aidevme-shared-scripts` is not present.
When you improve auth or API logic here, back-port the relevant change into any standalone copy so the
two do not drift.
