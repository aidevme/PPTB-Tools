<#
.SYNOPSIS
    Shared Atlassian Cloud authentication for the hso-atlassian-* skills.

.DESCRIPTION
    Atlassian Cloud uses HTTP Basic with `email:api_token`, base64-encoded. It is NOT Entra, so it
    does not belong in hso-shared-scripts - none of that library's MSAL bootstrap, tenant discovery,
    device-code handling, or Conditional Access fallback applies here. This module is the
    Atlassian-local equivalent, dot-sourced by the Atlassian skills the same way hso-shared-scripts is
    dot-sourced elsewhere (the sibling-library pattern).

    Settings resolution follows the house order used by the shared auth resolver:
      1. Explicit parameters               (always win)
      2. Environment variables             ATLASSIAN_BASE_URL / _EMAIL / _API_TOKEN
      3. auth-settings.json                (gitignored; same file the Dataverse settings use)

    Deliberately NOT .env / .env.local - project config is resolved through CLAUDE.local.md and the
    gitignored settings file instead.

    Runs under Windows PowerShell 5.1 and PowerShell 7. No modules required.

.NOTES
    The API token is a SECRET. Put it in auth-settings.json (gitignored) or an environment
    variable - never in CLAUDE.md, CLAUDE.local.md, or any tracked file.
#>

Set-StrictMode -Version Latest

function Get-AtlassianSettings {
    <#
    .SYNOPSIS
    Resolves Atlassian base URL, account email, and API token.

    .PARAMETER BaseUrl
    Atlassian Cloud site, e.g. https://yourorg.atlassian.net

    .PARAMETER Email
    Account email used as the Basic-auth username.

    .PARAMETER ApiToken
    Atlassian API token. Create at https://id.atlassian.com/manage-profile/security/api-tokens
    #>
    [CmdletBinding()]
    param(
        [string]$BaseUrl,
        [string]$Email,
        [string]$ApiToken
    )

    # --- 2. environment variables ---
    if (-not $BaseUrl)  { $BaseUrl  = $env:ATLASSIAN_BASE_URL }
    if (-not $Email)    { $Email    = $env:ATLASSIAN_EMAIL }
    if (-not $ApiToken) { $ApiToken = $env:ATLASSIAN_API_TOKEN }

    # --- 3. auth-settings.json ---
    if (-not $BaseUrl -or -not $Email -or -not $ApiToken) {
        $skillsRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $candidates = @(
            $env:ATLASSIAN_AUTH_SETTINGS_PATH
            (Join-Path $skillsRoot 'auth-settings.json')
            (Join-Path (Get-Location) '.claude\auth-settings.json')
            (Join-Path (Get-Location) 'auth-settings.json')
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

        $settingsPath = $candidates | Select-Object -First 1
        if ($settingsPath) {
            try {
                $json = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
                if (-not $BaseUrl  -and $json.PSObject.Properties['AtlassianBaseUrl'])  { $BaseUrl  = $json.AtlassianBaseUrl }
                if (-not $Email    -and $json.PSObject.Properties['AtlassianEmail'])    { $Email    = $json.AtlassianEmail }
                if (-not $ApiToken -and $json.PSObject.Properties['AtlassianApiToken']) { $ApiToken = $json.AtlassianApiToken }
            } catch {
                Write-Warning "Could not parse $settingsPath : $($_.Exception.Message)"
            }
        }
    }

    $missing = @()
    if (-not $BaseUrl)  { $missing += 'BaseUrl  (-BaseUrl,  $env:ATLASSIAN_BASE_URL,  or AtlassianBaseUrl)' }
    if (-not $Email)    { $missing += 'Email    (-Email,    $env:ATLASSIAN_EMAIL,     or AtlassianEmail)' }
    if (-not $ApiToken) { $missing += 'ApiToken (-ApiToken, $env:ATLASSIAN_API_TOKEN, or AtlassianApiToken)' }
    if ($missing.Count) {
        throw ("Atlassian settings missing:`n  " + ($missing -join "`n  ") +
               "`nSet them as environment variables or in a gitignored auth-settings.json." +
               "`nCreate an API token at https://id.atlassian.com/manage-profile/security/api-tokens")
    }

    [pscustomobject]@{
        BaseUrl  = $BaseUrl.TrimEnd('/')
        Email    = $Email
        ApiToken = $ApiToken
    }
}

function Get-AtlassianSetting {
    <#
    .SYNOPSIS
    Resolves a single non-credential Atlassian setting through the same order as the credentials.

    .DESCRIPTION
    Some Atlassian skills carry configuration that is not a secret - JIRA_ALLOWED_STATUSES, for
    instance, which fences which status transitions a skill may perform. Those resolved from .env
    upstream alongside the credentials. Keeping one resolution path for both means a consultant
    configures Atlassian in one place rather than two.

    .PARAMETER Key
    Environment variable name, e.g. JIRA_ALLOWED_STATUSES.

    .PARAMETER SettingsName
    Property name in auth-settings.json. Defaults to the Key with underscores removed and
    PascalCase applied - JIRA_ALLOWED_STATUSES becomes JiraAllowedStatuses.

    .PARAMETER Default
    Returned when the setting is found nowhere.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Key,
        [string]$SettingsName,
        [string]$Default
    )

    $v = [Environment]::GetEnvironmentVariable($Key)
    if ($v) { return $v }

    if (-not $SettingsName) {
        $SettingsName = ($Key.ToLower().Split('_') | ForEach-Object {
            if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
        }) -join ''
    }

    $skillsRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $settingsPath = @(
        $env:ATLASSIAN_AUTH_SETTINGS_PATH
        (Join-Path $skillsRoot 'auth-settings.json')
        (Join-Path (Get-Location) '.claude\auth-settings.json')
        (Join-Path (Get-Location) 'auth-settings.json')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

    if ($settingsPath) {
        try {
            $json = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
            if ($json.PSObject.Properties[$SettingsName]) { return [string]$json.$SettingsName }
        } catch { }
    }
    return $Default
}

function Get-AtlassianHeaders {
    <#
    .SYNOPSIS
    Builds the HTTP Basic auth headers for an Atlassian Cloud REST call.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Email,
        [Parameter(Mandatory)][string]$ApiToken
    )
    # Basic auth is email:api_token, base64 of the UTF-8 bytes. Atlassian documents UTF-8, and it
    # matters: ASCII would silently mangle a non-ASCII character in an email address, producing a
    # 401 that looks like a wrong token. Identical to ASCII for ordinary credentials.
    $pair  = "{0}:{1}" -f $Email, $ApiToken
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
    @{
        Authorization = "Basic " + [System.Convert]::ToBase64String($bytes)
        Accept        = 'application/json'
    }
}

function Test-AtlassianConnection {
    <#
    .SYNOPSIS
    Verifies the credentials before any real call, and fails with a message that says which of the
    three plausible causes it is.

    .DESCRIPTION
    Returns the authenticated account on success. Distinguishes a bad token (401) from a token that
    is valid but lacks access (403) from a wrong site URL (404 / DNS), because those need different
    fixes and the raw REST error does not say which.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][hashtable]$Headers
    )
    $uri = "$BaseUrl/rest/api/3/myself"
    try {
        $me = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get -ErrorAction Stop
        return $me
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        switch ($status) {
            401 { throw "401 from $BaseUrl - the email or API token is wrong, or the token was revoked. Tokens are per-account: confirm the email matches the account that created it." }
            403 { throw "403 from $BaseUrl - credentials are valid but this account lacks access. Check the Atlassian product (Jira/Confluence) is licensed for it." }
            404 { throw "404 from $BaseUrl - the REST path was not found, which usually means BaseUrl points at the wrong site or includes a path. Expected the site root, e.g. https://yourorg.atlassian.net" }
            default { throw "Could not reach $BaseUrl : $($_.Exception.Message)" }
        }
    }
}
