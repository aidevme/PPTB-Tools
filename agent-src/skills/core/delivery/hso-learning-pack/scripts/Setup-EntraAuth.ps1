# Setup-EntraAuth.ps1
#
# Automates the Entra (Azure AD) configuration that the SWA Entra-gated mode needs:
#
#   1. Create (or reuse) an Entra app registration
#   2. Add the SWA's redirect URI to that app registration
#   3. Create a client secret
#   4. Set the SWA app settings (AAD_CLIENT_ID, AAD_CLIENT_SECRET)
#
# Idempotent: re-running against an existing app reg reuses it and refreshes
# the client secret only if -RotateSecret is passed (or if the appsettings
# don't already contain a working pair).
#
# Usage:
#   .\Setup-EntraAuth.ps1 -StaticWebAppName <swa-name> `
#                         -ResourceGroup    <rg-name>
#
#   .\Setup-EntraAuth.ps1 -StaticWebAppName <swa-name> `
#                         -ResourceGroup    <rg-name> `
#                         -AppDisplayName   "<Product> Learning Pack" `
#                         -SecretYears      2 `
#                         -RotateSecret
#
# Prereqs:
#   - Az CLI logged in:   az login
#   - Your account must have permission to create Entra app registrations
#     (Application Developer role or higher in the tenant).
#   - The Static Web App must already exist (Deploy-LearningPack.ps1 creates it).
#requires -Version 5.1

param(
    [Parameter(Mandatory = $true)]
    [string]$StaticWebAppName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    # Default display name derives from the SWA name so each project gets a
    # distinct Entra app registration. Override with -AppDisplayName to control.
    [string]$AppDisplayName,

    # How long the client secret should live, in years. Max 2 years per Entra policy.
    [ValidateRange(1, 2)]
    [int]$SecretYears = 2,

    # If passed, always create a fresh client secret and update SWA settings,
    # even if a working pair already exists.
    [switch]$RotateSecret
)

$ErrorActionPreference = 'Stop'

# Derive a sensible app display name from the SWA name if the caller didn't
# supply one. Example: "hso-inextitsm-learning" -> "hso-inextitsm-learning Auth"
if (-not $AppDisplayName) {
    $AppDisplayName = "$StaticWebAppName Auth"
}

Write-Host ""
Write-Host "=== Learning Pack -- Entra auth setup ===" -ForegroundColor Cyan
Write-Host ""

# 1. Verify Az CLI session
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) { throw "Az CLI is not logged in. Run 'az login' first." }
Write-Host "Signed in as : $($account.user.name)" -ForegroundColor Gray
Write-Host "Tenant       : $($account.tenantId)" -ForegroundColor Gray
Write-Host ""

# 2. Resolve the SWA and its default hostname
Write-Host "==> Looking up Static Web App '$StaticWebAppName' in '$ResourceGroup'..." -ForegroundColor Cyan
$swa = az staticwebapp show --name $StaticWebAppName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
if (-not $swa) {
    throw "Static Web App '$StaticWebAppName' not found in '$ResourceGroup'. Run Deploy-LearningPack.ps1 first."
}
$swaHost     = $swa.defaultHostname
$redirectUri = "https://$swaHost/.auth/login/aad/callback"
Write-Host "  hostname    : $swaHost" -ForegroundColor Gray
Write-Host "  redirect URI: $redirectUri" -ForegroundColor Gray
Write-Host ""

# 3. Find or create the Entra app registration
Write-Host "==> Checking for existing Entra app registration '$AppDisplayName'..." -ForegroundColor Cyan
$existing = az ad app list --display-name $AppDisplayName --output json | ConvertFrom-Json
$appId    = $null
$objectId = $null

if ($existing -and $existing.Count -ge 1) {
    if ($existing.Count -gt 1) {
        Write-Host "  WARNING: $($existing.Count) registrations share display name '$AppDisplayName'. Reusing the first." -ForegroundColor Yellow
    }
    $appId    = $existing[0].appId
    $objectId = $existing[0].id
    Write-Host "  reusing existing app reg" -ForegroundColor Green
    Write-Host "    appId    = $appId" -ForegroundColor Gray
    Write-Host "    objectId = $objectId" -ForegroundColor Gray
} else {
    Write-Host "  creating new app registration..." -ForegroundColor Cyan
    $newApp = az ad app create `
        --display-name $AppDisplayName `
        --sign-in-audience AzureADMyOrg `
        --web-redirect-uris $redirectUri `
        --enable-id-token-issuance true `
        --output json | ConvertFrom-Json
    if (-not $newApp) { throw "Entra app registration creation failed." }
    $appId    = $newApp.appId
    $objectId = $newApp.id
    Write-Host "    appId    = $appId" -ForegroundColor Green
    Write-Host "    objectId = $objectId" -ForegroundColor Gray

    # Give Entra a moment to propagate (avoids 'app not found' on the next command)
    Start-Sleep -Seconds 4
}
Write-Host ""

# 4. Ensure the redirect URI is registered (idempotent)
Write-Host "==> Ensuring redirect URI is set on the app registration..." -ForegroundColor Cyan
$appDetail   = az ad app show --id $appId --output json | ConvertFrom-Json
$currentUris = @($appDetail.web.redirectUris)
if ($currentUris -notcontains $redirectUri) {
    $newUris = $currentUris + $redirectUri
    az ad app update --id $appId --web-redirect-uris @newUris --output none
    Write-Host "  added redirect URI" -ForegroundColor Green
} else {
    Write-Host "  redirect URI already present" -ForegroundColor Gray
}

# Make sure ID token issuance is enabled (sometimes default to false)
az ad app update --id $appId --enable-id-token-issuance true --output none
Write-Host ""

# 4b. Ensure the Microsoft Graph delegated permissions SWA needs are present + consented.
# Without these, the token exchange completes but the userinfo lookup fails and
# /.auth/complete hangs (user lands back on /.auth/login/aad in a quiet loop).
Write-Host "==> Ensuring Microsoft Graph delegated permissions (openid, profile, email, offline_access, User.Read)..." -ForegroundColor Cyan
$graphAppId       = '00000003-0000-0000-c000-000000000000'
$requiredScopes = @(
    @{ id = '37f7f235-527c-4136-accd-4a02d197296e'; name = 'openid'         },
    @{ id = '14dad69e-099b-42c9-810b-d002981feec1'; name = 'profile'        },
    @{ id = '64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0'; name = 'email'          },
    @{ id = '7427e0e9-2fba-42fe-b0c0-848c9e6a8182'; name = 'offline_access' },
    @{ id = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'; name = 'User.Read'      }
)
$appNow            = az ad app show --id $appId --output json | ConvertFrom-Json
$graphBlock        = $appNow.requiredResourceAccess | Where-Object { $_.resourceAppId -eq $graphAppId }
$existingScopeIds  = @()
if ($graphBlock) { $existingScopeIds = @($graphBlock.resourceAccess | ForEach-Object { $_.id }) }
$missing = $requiredScopes | Where-Object { $existingScopeIds -notcontains $_.id }
if ($missing.Count -gt 0) {
    $apiArgs = $missing | ForEach-Object { "$($_.id)=Scope" }
    az ad app permission add --id $appId --api $graphAppId --api-permissions @apiArgs --output none 2>$null
    Write-Host "  added: $(( $missing | ForEach-Object { $_.name } ) -join ', ')" -ForegroundColor Green
} else {
    Write-Host "  all required scopes already on the app reg" -ForegroundColor Gray
}

# Always grant tenant-wide admin consent (idempotent -- same call no-ops if already granted).
# Requires the signed-in user to be Global Admin / Privileged Role Admin / Cloud App Admin.
Write-Host "==> Granting tenant-wide admin consent..." -ForegroundColor Cyan
az ad app permission admin-consent --id $appId 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  admin consent granted" -ForegroundColor Green
} else {
    Write-Host "  WARNING: admin-consent call did not succeed -- your account may lack the role." -ForegroundColor Yellow
    Write-Host "  An admin can grant via: https://login.microsoftonline.com/$($account.tenantId)/adminconsent?client_id=$appId" -ForegroundColor Yellow
}
Write-Host ""

# 5. Determine whether we need a new client secret
$existingAppSettings = az staticwebapp appsettings list `
    --name $StaticWebAppName `
    --resource-group $ResourceGroup `
    --output json | ConvertFrom-Json

# az returns these as either an object with .properties or a flat object -- handle both
$settingsMap = @{}
if ($existingAppSettings) {
    if ($existingAppSettings.properties) {
        foreach ($p in $existingAppSettings.properties.PSObject.Properties) {
            $settingsMap[$p.Name] = $p.Value
        }
    } else {
        foreach ($p in $existingAppSettings.PSObject.Properties) {
            $settingsMap[$p.Name] = $p.Value
        }
    }
}

$existingClientId     = $settingsMap['AAD_CLIENT_ID']
$existingHasSecret    = $settingsMap.ContainsKey('AAD_CLIENT_SECRET') -and -not [string]::IsNullOrEmpty($settingsMap['AAD_CLIENT_SECRET'])
$clientIdMatches      = ($existingClientId -eq $appId)
$needNewSecret        = $RotateSecret -or (-not $existingHasSecret) -or (-not $clientIdMatches)

Write-Host "==> SWA appsettings check:" -ForegroundColor Cyan
Write-Host "  existing AAD_CLIENT_ID matches  : $clientIdMatches" -ForegroundColor Gray
Write-Host "  AAD_CLIENT_SECRET present       : $existingHasSecret" -ForegroundColor Gray
Write-Host "  RotateSecret flag passed        : $RotateSecret" -ForegroundColor Gray
Write-Host "  -> action: $(if ($needNewSecret) { 'create new client secret + update SWA settings' } else { 'no changes needed' })" -ForegroundColor $(if ($needNewSecret) { 'Yellow' } else { 'Green' })
Write-Host ""

if ($needNewSecret) {
    Write-Host "==> Creating client secret (valid $SecretYears year(s))..." -ForegroundColor Cyan
    $secretYears = $SecretYears
    $endDate = (Get-Date).AddYears($secretYears).ToString('yyyy-MM-dd')
    $secretJson = az ad app credential reset `
        --id $appId `
        --append `
        --display-name "swa-$StaticWebAppName-$(Get-Date -Format yyyyMMdd)" `
        --end-date $endDate `
        --output json | ConvertFrom-Json
    if (-not $secretJson -or -not $secretJson.password) {
        throw "Client secret creation failed. (Likely cause: insufficient permissions on the app registration.)"
    }
    $clientSecret = $secretJson.password
    Write-Host "  secret created (expires $endDate)" -ForegroundColor Green
    Write-Host ""

    Write-Host "==> Setting SWA appsettings AAD_CLIENT_ID + AAD_CLIENT_SECRET..." -ForegroundColor Cyan
    az staticwebapp appsettings set `
        --name $StaticWebAppName `
        --resource-group $ResourceGroup `
        --setting-names "AAD_CLIENT_ID=$appId" "AAD_CLIENT_SECRET=$clientSecret" `
        --output none
    Write-Host "  appsettings updated" -ForegroundColor Green
    Write-Host ""
}

# 6. Summary
Write-Host "================================================" -ForegroundColor Green
Write-Host " Entra auth setup complete" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host " App reg name : $AppDisplayName" -ForegroundColor Gray
Write-Host " App ID       : $appId" -ForegroundColor Gray
Write-Host " Tenant ID    : $($account.tenantId)" -ForegroundColor Gray
Write-Host " SWA host     : https://$swaHost" -ForegroundColor Gray
Write-Host " Redirect URI : $redirectUri" -ForegroundColor Gray
Write-Host ""
Write-Host " Sign in:  https://$swaHost" -ForegroundColor Cyan
Write-Host " (Unauthenticated requests redirect to Entra; sign-in returns to the pack.)" -ForegroundColor Gray
Write-Host ""

if ($needNewSecret) {
    Write-Host " NEW SECRET created -- already pushed to SWA appsettings." -ForegroundColor Yellow
    Write-Host " (The secret value is NOT printed here; retrieve via Az CLI if needed:" -ForegroundColor Gray
    Write-Host "    az staticwebapp appsettings list --name $StaticWebAppName --resource-group $ResourceGroup)" -ForegroundColor Gray
    Write-Host ""
}

# 7. Permission consent check (informational -- admin consent may be needed in some tenants)
$tenantConsentUrl = "https://login.microsoftonline.com/$($account.tenantId)/adminconsent?client_id=$appId"
Write-Host " If your tenant requires admin consent for openid/profile, grant it at:" -ForegroundColor Gray
Write-Host "   $tenantConsentUrl" -ForegroundColor DarkCyan
Write-Host ""
