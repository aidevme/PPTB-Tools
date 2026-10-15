<#
.SYNOPSIS
    Acquire a Dataverse Web API token via the OAuth 2.0 device-code flow and cache it where the shared
    Dataverse skills read it.

.DESCRIPTION
    Self-contained device-code sign-in (no Azure CLI, no MSAL.PS dependency — raw REST against the v2.0
    endpoints). Prints a short user code + URL; you complete sign-in in any browser (including on your
    phone). On success it writes the token to %TEMP%\DataverseAuthCache_<hash>.json in the exact schema
    the shared Dataverse-Auth.ps1 (Get-TokenFromCache) reads, so subsequent hso-dataverse-* skill calls
    reuse it without prompting (~1 hour).

    Works in both Windows PowerShell 5.1 and PowerShell 7.

    NOTE: device-code tokens are not device-bound. If the org's Conditional Access requires a managed/
    compliant device, this flow may be blocked (AADSTS50005 / 53003) — use Connect-DataverseViaAzCli.ps1
    (WAM broker) in that case.

.PARAMETER EnvironmentUrl
    Dataverse org base URL (e.g. https://yourorg.crm.dynamics.com). Trailing slash trimmed.

.PARAMETER Tenant
    Tenant GUID for the org. REQUIRED — device-code flow must target a specific tenant; there is no
    default tenant baked into this neutral template.

.PARAMETER ClientId
    Public client used for the flow. Defaults to the Microsoft Common Data Service client
    (51f81489-12ee-4a9e-aaae-a2591f45987d) — the same client the shared auth module uses.

.PARAMETER SkipValidation
    Skip the post-auth WhoAmI call.

.EXAMPLE
    pwsh -NoProfile -File .\Connect-DataverseViaDeviceCode.ps1 `
        -EnvironmentUrl "https://yourorg.crm.dynamics.com" -Tenant "<tenant-guid>"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$Tenant,
    [string]$ClientId = '51f81489-12ee-4a9e-aaae-a2591f45987d',
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
$envUrl = $EnvironmentUrl.TrimEnd('/')
if (-not $envUrl.StartsWith('https://')) { $envUrl = "https://$envUrl" }

$authority = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0"
$scope     = "$envUrl/.default offline_access openid profile"

# --- 1. Request a device code ---
try {
    $dc = Invoke-RestMethod -Method Post -Uri "$authority/devicecode" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ client_id = $ClientId; scope = $scope }
}
catch {
    # `??` is PowerShell 7 only and this script must parse under 5.1 (ADR 0017) - it is a
    # fallback for hosts where the PS7 paths already failed, so it cannot require PS7 itself.
    $detail = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
    throw "Failed to start device-code flow: $detail"
}

Write-Host ""
Write-Host "=== Dataverse device-code sign-in ===" -ForegroundColor Cyan
Write-Host "  Environment: $envUrl"
Write-Host "  Tenant:      $Tenant"
Write-Host ""
Write-Host "  1. Open: " -NoNewline; Write-Host $dc.verification_uri -ForegroundColor Yellow
Write-Host "  2. Enter code: " -NoNewline; Write-Host $dc.user_code -ForegroundColor Yellow
Write-Host "  3. Sign in as the account that has access to this org."
Write-Host ""
Write-Host "  Waiting for sign-in..." -ForegroundColor Gray

# --- 2. Poll the token endpoint ---
$interval = [int]$dc.interval; if ($interval -lt 5) { $interval = 5 }
$deadline = (Get-Date).AddSeconds([int]$dc.expires_in)
$tok = $null

while ($null -eq $tok) {
    if ((Get-Date) -gt $deadline) { throw "Device code expired before sign-in completed. Re-run the script." }
    Start-Sleep -Seconds $interval
    try {
        $tok = Invoke-RestMethod -Method Post -Uri "$authority/token" `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{
                grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
                client_id   = $ClientId
                device_code = $dc.device_code
            }
    }
    catch {
        $body = $_.ErrorDetails.Message
        $err  = $null
        if ($body) { try { $err = ($body | ConvertFrom-Json).error } catch { } }
        switch ($err) {
            'authorization_pending' { continue }            # user hasn't finished yet
            'slow_down'             { $interval += 5; continue }
            'expired_token'         { throw "Device code expired. Re-run the script." }
            'authorization_declined'{ throw "Sign-in was declined." }
            default                 { throw "Token request failed: $body" }
        }
    }
}

$token   = $tok.access_token
$expiry  = (Get-Date).AddSeconds([int]$tok.expires_in)

# --- 3. Username from the access-token 'upn' / 'preferred_username' claim ---
function Get-JwtClaim([string]$jwt, [string[]]$names) {
    try {
        $p = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
        switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
        $claims = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
        foreach ($n in $names) { if ($claims.PSObject.Properties[$n] -and $claims.$n) { return $claims.$n } }
    } catch { }
    return $null
}
$user = Get-JwtClaim $token @('upn', 'preferred_username', 'unique_name')
if (-not $user) { $user = 'unknown' }

# --- 4. Write the shared cache (matches Dataverse-Auth.ps1 Get-TokenCachePath / Save-TokenToCache) ---
$urlHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($envUrl.ToLower())
    )
).Replace('-', '').Substring(0, 16)
$cachePath = Join-Path $env:TEMP "DataverseAuthCache_$urlHash.json"

@{
    EnvironmentUrl = $envUrl
    Token          = $token
    Expiry         = $expiry.ToString('o')
    Username       = $user
    CachedAt       = (Get-Date).ToString('o')
} | ConvertTo-Json | Set-Content -Path $cachePath -Force

Write-Host ""
Write-Host "[OK] Authenticated as $user" -ForegroundColor Green
Write-Host "[OK] Token cached at $cachePath (expires $($expiry.ToString('HH:mm:ss')))" -ForegroundColor Green
Write-Host "[OK] Shared Dataverse skills can now call $envUrl without prompting (~1 hour)." -ForegroundColor Green

# --- 5. Validate ---
if (-not $SkipValidation) {
    try {
        $who = Invoke-RestMethod -Uri "$envUrl/api/data/v9.2/WhoAmI" `
            -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' } -Method Get
        Write-Host "[OK] WhoAmI succeeded - UserId=$($who.UserId)" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] Token cached but WhoAmI validation failed: $($_.Exception.Message)" -ForegroundColor Yellow
        exit 1
    }
}