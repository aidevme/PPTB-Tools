<#
.SYNOPSIS
    Acquire a Dataverse Web API token on a managed device via the Azure CLI WAM broker and cache it
    where the shared Dataverse skills read it.

.DESCRIPTION
    Fallback auth for managed Windows devices where Conditional Access blocks device-code flow and the
    embedded-webview / background MSAL flows fail. Uses `az` (WAM broker → carries the device PRT, so
    it satisfies "require managed/compliant device" CA), scoped to the ORG's own tenant, then writes
    the token to %TEMP%\DataverseAuthCache_<hash>.json in the format the shared Dataverse-Auth.ps1
    reads — so subsequent hso-dataverse-* skill calls reuse it without prompting (~1 hour).

    Requires Azure CLI. Runs under BOTH Windows PowerShell 5.1 and PowerShell 7, deliberately:
    this is the fallback for hosts where the other auth paths already failed, so requiring a
    particular host to run it would defeat the point (ADR 0017 / ADR 0058).

.PARAMETER EnvironmentUrl
    Dataverse org base URL (e.g. https://yourorg.crm.dynamics.com). Trailing slash is trimmed.

.PARAMETER Tenant
    Org tenant GUID. Optional — auto-discovered from the org's unauthenticated 401 challenge if omitted.

.PARAMETER ForceLogin
    Force a fresh `az login` even if an az session already exists.

.PARAMETER SkipValidation
    Skip the post-auth WhoAmI validation call.

.EXAMPLE
    pwsh -NoProfile -File .\Connect-DataverseViaAzCli.ps1 -EnvironmentUrl "https://yourorg.crm.dynamics.com"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [string]$Tenant,
    [switch]$ForceLogin,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
$envUrl = $EnvironmentUrl.TrimEnd('/')

# --- 0. Azure CLI present? ---
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') not found. Install it (https://aka.ms/installazurecli) or use the standard interactive auth."
}

# --- 1. Discover the org tenant from its unauthenticated 401 (no sign-in needed) ---
if (-not $Tenant) {
    # The 401 IS the payload here - its WWW-Authenticate header names the org's tenant. PS7 can
    # ask for it directly with -SkipHttpErrorCheck; Windows PowerShell 5.1 has no such switch and
    # throws on any non-2xx, so there the same header is read off the exception's response.
    # Both paths are exercised: this script is a fallback for hosts where the PS7 flows already
    # failed, so requiring PS7 to run it would defeat the point (ADR 0017 / ADR 0058).
    $wa = $null
    $probeUri = "$envUrl/api/data/v9.2/WhoAmI"
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        try {
            $resp = Invoke-WebRequest -Uri $probeUri -SkipHttpErrorCheck -ErrorAction Stop
            $wa = $resp.Headers['WWW-Authenticate']
        } catch { }
    } else {
        try {
            Invoke-WebRequest -Uri $probeUri -UseBasicParsing -ErrorAction Stop | Out-Null
        } catch {
            if ($_.Exception.Response) { $wa = $_.Exception.Response.Headers['WWW-Authenticate'] }
        }
    }
    if ($wa -is [System.Array]) { $wa = $wa -join ' ' }
    if ("$wa" -match 'login\.microsoftonline\.com/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        $Tenant = $Matches[1]
    }
    if (-not $Tenant) {
        throw "Could not auto-discover the tenant for $envUrl from its 401 challenge. Pass -Tenant <guid> explicitly."
    }
    Write-Host "[INFO] Discovered org tenant: $Tenant"
}

# --- 2. Ensure an az session exists ---
$loggedIn = $false
if (-not $ForceLogin) {
    az account show 2>$null | Out-Null
    $loggedIn = ($LASTEXITCODE -eq 0)
}
if ($ForceLogin -or -not $loggedIn) {
    Write-Host "[INFO] Launching 'az login' (WAM broker — a native Windows account dialog should appear)..."
    az login --tenant $Tenant --allow-no-subscriptions --only-show-errors | Out-Null
}

# --- 3. Acquire a token for the ORG's tenant (not the default subscription tenant) ---
function Get-AzToken { az account get-access-token --resource $envUrl --tenant $Tenant -o json 2>$null }
$raw = Get-AzToken
if (-not $raw) {
    Write-Host "[INFO] Need an interactive sign-in for tenant $Tenant..."
    az login --tenant $Tenant --allow-no-subscriptions --only-show-errors | Out-Null
    $raw = Get-AzToken
}
if (-not $raw) {
    throw "Failed to acquire a token for $envUrl (tenant $Tenant). Confirm your account has access to this org."
}
$tokObj = $raw | ConvertFrom-Json
$token  = $tokObj.accessToken
if (-not $token) { throw "az returned no accessToken for $envUrl." }

# Expiry — prefer the epoch 'expires_on' (unambiguous), fall back to local 'expiresOn'
$expiryIso = $null
if ($tokObj.PSObject.Properties['expires_on'] -and $tokObj.expires_on) {
    $expiryIso = [DateTimeOffset]::FromUnixTimeSeconds([int64]$tokObj.expires_on).LocalDateTime.ToString('o')
} elseif ($tokObj.expiresOn) {
    $expiryIso = ([datetime]::Parse($tokObj.expiresOn)).ToString('o')
} else {
    $expiryIso = (Get-Date).AddMinutes(55).ToString('o')   # conservative default
}

$user = az account show --query user.name -o tsv 2>$null

# --- 4. Write the token into the shared cache (mirrors Dataverse-Auth.ps1 Get-TokenCachePath/Save-TokenToCache) ---
$urlHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($envUrl.ToLower())
    )
).Replace('-', '').Substring(0, 16)
$cachePath = Join-Path $env:TEMP "DataverseAuthCache_$urlHash.json"

@{
    EnvironmentUrl = $envUrl
    Token          = $token
    Expiry         = $expiryIso
    Username       = $user
    CachedAt       = (Get-Date).ToString('o')
} | ConvertTo-Json | Set-Content -Path $cachePath -Force

Write-Host "[OK] Authenticated as $user (tenant $Tenant)"
Write-Host "[OK] Token cached at $cachePath (expires $expiryIso)"
Write-Host "[OK] Shared Dataverse skills can now call $envUrl without prompting (~1 hour)."

# --- 5. Validate ---
if (-not $SkipValidation) {
    try {
        $h = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
        $who = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/WhoAmI" -Headers $h -Method Get
        Write-Host "[OK] WhoAmI succeeded — UserId=$($who.UserId)"
    } catch {
        Write-Host "[WARN] Token cached but WhoAmI validation failed: $($_.Exception.Message)"
        exit 1
    }
}