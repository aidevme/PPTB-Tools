<#
.SYNOPSIS
    Acquire an Azure DevOps token on a managed device via the Azure CLI WAM broker and cache it
    where the shared ADO skills read it.

.DESCRIPTION
    Fallback auth for managed Windows devices where Conditional Access blocks the device-code flow
    ("your admin requires the device requesting access to be managed"). Device-code tokens are not
    device-bound, so CA rejects them even though the device IS managed and compliant.

    Uses `az` (WAM broker -> carries the device PRT, satisfying "require managed/compliant device"),
    scoped to the org's tenant, then writes the token to %TEMP%\AdoAuthCache_<hash>.json in the exact
    format the shared ADO-Auth.ps1 reads (Get-AdoTokenFromCache) — so subsequent hso-ado-work-items /
    hso-ado-pull-requests calls reuse it silently (~1 hour).

    ADO's Entra resource ID is the fixed first-party GUID 499b84ac-1321-427f-aa17-267ca6975798.
    Unlike Dataverse there is no per-org resource URL, so nothing is auto-discovered from a 401 —
    only the tenant needs resolving, and it defaults to the current az session's tenant.

    Sibling of Connect-DataverseViaAzCli.ps1; same bridge pattern, different resource and cache file.

.PARAMETER OrgUrl
    Azure DevOps org base URL (e.g. https://dev.azure.com/<org>). Trailing slash is trimmed.
    This is the cache key — it must match what the calling skill passes as -OrgUrl, or the cache
    hash will not line up and the skill will prompt anyway.

.PARAMETER Tenant
    Tenant GUID. Optional — defaults to the tenant of the current az session.

.PARAMETER ForceLogin
    Force a fresh `az login` even if an az session already exists.

.PARAMETER SkipValidation
    Skip the post-auth connection-data validation call.

.EXAMPLE
    pwsh -NoProfile -File .\Connect-AdoViaAzCli.ps1 -OrgUrl "https://dev.azure.com/<org>"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OrgUrl,
    [string]$Tenant,
    [switch]$ForceLogin,
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'
$orgUrl = $OrgUrl.TrimEnd('/')

# Azure DevOps first-party application ID — fixed across all tenants and orgs.
$AdoResourceId = '499b84ac-1321-427f-aa17-267ca6975798'

# --- 0. Azure CLI present? ---
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI ('az') not found. Install it (https://aka.ms/installazurecli) or use a PAT via the skill's -Pat parameter."
}

# --- 1. Ensure an az session exists ---
$loggedIn = $false
if (-not $ForceLogin) {
    az account show 2>$null | Out-Null
    $loggedIn = ($LASTEXITCODE -eq 0)
}
if ($ForceLogin -or -not $loggedIn) {
    Write-Host "[INFO] Launching 'az login' (WAM broker — a native Windows account dialog should appear)..."
    if ($Tenant) {
        az login --tenant $Tenant --allow-no-subscriptions --only-show-errors | Out-Null
    } else {
        az login --allow-no-subscriptions --only-show-errors | Out-Null
    }
}

# --- 2. Resolve the tenant (default: the current az session's tenant) ---
if (-not $Tenant) {
    $Tenant = az account show --query tenantId -o tsv 2>$null
    if (-not $Tenant) { throw "Could not resolve a tenant from the az session. Pass -Tenant <guid>." }
    Write-Host "[INFO] Using az session tenant: $Tenant"
}

# --- 3. Acquire an ADO token for that tenant ---
# The wrong-ACCOUNT trap (distinct from the wrong-tenant one, and nastier): when az holds several
# signed-in identities, `--tenant X` still authenticates as the DEFAULT subscription's account. If
# that account is a guest or belongs to another org, Entra rejects it with AADSTS50020 "user account
# from identity provider ... does not exist in tenant" - which reads like the tenant is wrong when
# the tenant is right and the identity is wrong. Pin the subscription that actually lives in the
# target tenant so the correct identity is used.
$targetSub = az account list --all --query "[?tenantId=='$Tenant'].id | [0]" -o tsv 2>$null

function Get-AzAdoToken {
    if ($targetSub) {
        az account get-access-token --resource $AdoResourceId --subscription $targetSub -o json 2>$null
    } else {
        az account get-access-token --resource $AdoResourceId --tenant $Tenant -o json 2>$null
    }
}

if ($targetSub) {
    $asWho = az account list --all --query "[?id=='$targetSub'].user.name | [0]" -o tsv 2>$null
    Write-Host "[INFO] Using the identity signed in to tenant ${Tenant}: $asWho"
} else {
    Write-Warning "No subscription found in tenant $Tenant; falling back to --tenant, which uses the default account and may fail with AADSTS50020."
}
$raw = Get-AzAdoToken
if (-not $raw) {
    Write-Host "[INFO] Need an interactive sign-in for tenant $Tenant..."
    az login --tenant $Tenant --allow-no-subscriptions --only-show-errors | Out-Null
    $raw = Get-AzAdoToken
}
if (-not $raw) {
    throw "Failed to acquire an ADO token for tenant $Tenant. Confirm your account has access to $orgUrl."
}
$tokObj = $raw | ConvertFrom-Json
$token  = $tokObj.accessToken
if (-not $token) { throw "az returned no accessToken for the ADO resource." }

# Expiry — prefer the epoch 'expires_on' (unambiguous), fall back to local 'expiresOn'
if ($tokObj.PSObject.Properties['expires_on'] -and $tokObj.expires_on) {
    $expiryIso = [DateTimeOffset]::FromUnixTimeSeconds([int64]$tokObj.expires_on).LocalDateTime.ToString('o')
} elseif ($tokObj.expiresOn) {
    $expiryIso = ([datetime]::Parse($tokObj.expiresOn)).ToString('o')
} else {
    $expiryIso = (Get-Date).AddMinutes(55).ToString('o')   # conservative default
}

# Identity comes from the TOKEN, not from `az account show`. The latter reads the DEFAULT
# subscription, which with several signed-in identities is frequently not the one the token was
# issued against - so it would name an account that had nothing to do with this token, which is
# actively misleading in exactly the multi-identity situation this script exists to handle.
function Get-TokenIdentity {
    param([string]$Jwt)
    try {
        $payload = $Jwt.Split('.')[1]
        switch ($payload.Length % 4) { 2 { $payload += '==' } 3 { $payload += '=' } }
        $json = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($payload.Replace('-', '+').Replace('_', '/')))
        $claims = $json | ConvertFrom-Json
        foreach ($c in @('upn', 'unique_name', 'preferred_username', 'appid')) {
            if ($claims.PSObject.Properties[$c] -and $claims.$c) { return [string]$claims.$c }
        }
    } catch { }
    return $null
}
$user = Get-TokenIdentity -Jwt $token
if (-not $user) { $user = $asWho }   # fall back to the account pinned for this tenant
if (-not $user) { $user = '(unknown)' }

$urlHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($orgUrl.ToLower())
    )
).Replace('-', '').Substring(0, 16)
$cachePath = Join-Path $env:TEMP "AdoAuthCache_$urlHash.json"

# --- 4. VALIDATE BEFORE CACHING ---
# The cache is shared with every hso-ado-* skill. Writing an unusable token into it leaves the
# machine worse off than before this script ran - the next skill call reads the bad token and
# 401s, and nothing points at this script as the cause. So prove the token works first, and only
# then write it. If validation cannot run (-SkipValidation), say so rather than implying success.
if (-not $SkipValidation) {
    try {
        $h = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
        $conn = Invoke-RestMethod -Uri "$orgUrl/_apis/connectionData?api-version=7.1-preview" -Headers $h -Method Get -ErrorAction Stop
        $validatedAs = $conn.authenticatedUser.providerDisplayName
        Write-Host "[OK] Token validated against $orgUrl - authenticated as $validatedAs"
    } catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }

        Write-Host "[FAIL] Could not validate the token against $orgUrl" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Nothing was cached, so the existing cache (if any) is untouched." -ForegroundColor Red

        if ($status -in 401, 403) {
            # Genuinely an identity problem - the request reached ADO and was rejected.
            Write-Host "       HTTP $status - the token reached Azure DevOps and was refused." -ForegroundColor Yellow
            Write-Host "       Token identity: $user  |  tenant: $Tenant" -ForegroundColor Yellow
            Write-Host "       With several signed-in identities, az can issue a token for the wrong one." -ForegroundColor Yellow
            Write-Host "       Re-run with an explicit -Tenant for the org and confirm that identity has access." -ForegroundColor Yellow
        } else {
            # Transport, TLS, proxy or DNS - the request never got a verdict, so the token is
            # unproven rather than known-bad. Do not misdiagnose this as a permissions problem.
            Write-Host "       This looks like a transport problem (TLS, proxy, DNS or connectivity)," -ForegroundColor Yellow
            Write-Host "       not an authentication one - the request never reached a verdict, so the" -ForegroundColor Yellow
            Write-Host "       token is unproven rather than known-bad. Check connectivity and retry." -ForegroundColor Yellow
            Write-Host "       Token identity: $user  |  tenant: $Tenant" -ForegroundColor Yellow
        }
        exit 1
    }
} else {
    Write-Warning "-SkipValidation was passed: caching an UNVERIFIED token. If it is bad, every hso-ado-* call will 401 until the cache expires or this is re-run."
}

@{
    OrgUrl   = $orgUrl
    Token    = $token
    Expiry   = $expiryIso
    Username = $user
    CachedAt = (Get-Date).ToString('o')
} | ConvertTo-Json | Set-Content -Path $cachePath -Force

Write-Host "[OK] Authenticated as $user (tenant $Tenant)"
Write-Host "[OK] Token cached at $cachePath (expires $expiryIso)"
Write-Host "[OK] Shared ADO skills can now call $orgUrl without prompting (~1 hour)."

# Validation deliberately runs BEFORE the cache write above - see section 4. Nothing is verified
# after this point, because by here the token has already been proven good.
