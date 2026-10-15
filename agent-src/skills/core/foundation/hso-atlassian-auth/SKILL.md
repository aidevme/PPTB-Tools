---
name: hso-atlassian-auth
layer: foundation
scope: core
description: |
  Shared Atlassian Cloud authentication for the hso-atlassian-* skills — settings resolution and
  HTTP Basic header construction for Jira and Confluence Cloud REST calls. This is a LIBRARY skill,
  not a directly-invoked one.
  Use when:
  (1) You are authoring a Jira or Confluence Cloud skill and need auth headers / settings
  (2) You need to understand or change shared Atlassian auth behaviour
  Does NOT authenticate Dataverse or Azure DevOps (use hso-shared-scripts for those). Other
  Atlassian skills dot-source its scripts/Atlassian-Auth.ps1 via a sibling-skill relative path.
---

# hso-atlassian-auth (library skill)

Settings resolution and Basic-auth headers for Atlassian Cloud. **Not invoked directly** — the
`hso-atlassian-*` skills dot-source `scripts/Atlassian-Auth.ps1`.

## Location in this template

Lives at `agent-src/skills/core/foundation/hso-atlassian-auth/` and is fanned out verbatim by
`agent-src/sync/sync.ps1` to `.claude/skills/` and `.github/skills/`, the same sibling-library pattern
as `hso-shared-scripts`.

## Why this is a separate library from `hso-shared-scripts`

`hso-shared-scripts` owns providers that authenticate **through Entra with MSAL / Azure CLI machinery**
(`Get-DataverseToken`, `Get-AdoToken`). Atlassian Cloud uses **HTTP Basic with `email:api_token`** —
none of that library's MSAL bootstrap, tenant discovery, device-code handling, or Conditional Access
fallback applies. Keeping Atlassian in its own sibling library keeps each library to one auth
mechanism rather than mixing unrelated ones in one folder.

## Usage

```powershell
$authDir = Join-Path $PSScriptRoot "..\..\hso-atlassian-auth\scripts"
. "$authDir\Atlassian-Auth.ps1"

$s = Get-AtlassianSettings                        # or -BaseUrl/-Email/-ApiToken explicitly
$h = Get-AtlassianHeaders -Email $s.Email -ApiToken $s.ApiToken
$me = Test-AtlassianConnection -BaseUrl $s.BaseUrl -Headers $h   # optional pre-flight
```

| Function | Does |
|---|---|
| `Get-AtlassianSettings` | Resolves base URL, email, API token. Throws listing exactly what is missing and where to put it. |
| `Get-AtlassianSetting` | Resolves a single non-credential setting (e.g. an allowed-status fence) through the same order. |
| `Get-AtlassianHeaders` | Builds the `Basic` header (UTF-8-encoded — Atlassian documents UTF-8). |
| `Test-AtlassianConnection` | Optional pre-flight against `/rest/api/3/myself`; distinguishes 401 / 403 / 404. |

## Settings resolution

1. **Explicit parameters** — always win.
2. **Environment variables** — `ATLASSIAN_BASE_URL`, `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`.
3. **`auth-settings.json`** (gitignored) — keys `AtlassianBaseUrl`, `AtlassianEmail`, `AtlassianApiToken`.

Override the settings file location with `ATLASSIAN_AUTH_SETTINGS_PATH`.

> **The API token is a secret.** It belongs in an environment variable or the **gitignored**
> `auth-settings.json` — never in `CLAUDE.md`, `CLAUDE.local.md`, or any tracked file.

## Why the pre-flight distinguishes status codes

- **401** — wrong email or API token, or the token was revoked (tokens are per-account).
- **403** — credentials valid, account lacks access (usually an unlicensed product).
- **404** — `BaseUrl` points at the wrong site or includes a path; it wants the site root.

## Notes on this port

Ported from the ForgeUSA `hso-atlassian-auth` library; already org-neutral (placeholder
`yourorg.atlassian.net` only). The Forge `license:` frontmatter line and the sibling `CHANGELOG.md`
were dropped in favour of this template's inline Changelog convention.

## Changelog

| Date | Author | Description |
|---|---|---|
| 2026-09-11 | maciejnowicki | Wave-0 port from ForgeUSA; neutralised; placed as a foundation library skill under the ADR-0008 sync. |
