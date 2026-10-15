# Diagnose-SwaAuth.ps1
# Pull the current SWA + Entra auth state and flag the common loopback causes.
#
# Run with no params (uses .deploy-config.json) or pass -Name + -ResourceGroup.
#requires -Version 5.1

param(
    [string]$Name,
    [string]$ResourceGroup
)

$ErrorActionPreference = 'Stop'

# Resolve from cached deploy config if not passed
$configPath = Join-Path $PSScriptRoot '.deploy-config.json'
if ((-not $Name -or -not $ResourceGroup) -and (Test-Path $configPath)) {
    $cached = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $Name) { $Name = $cached.Name }
    if (-not $ResourceGroup) { $ResourceGroup = $cached.ResourceGroup }
}
if (-not $Name -or -not $ResourceGroup) {
    throw "Pass -Name and -ResourceGroup, or run after Deploy-LearningPack.ps1 (which caches them)."
}

Write-Host ""
Write-Host "=== Diagnose SWA + Entra auth: $Name / $ResourceGroup ===" -ForegroundColor Cyan
Write-Host ""

# 1. SWA SKU + status
$swa = az staticwebapp show --name $Name --resource-group $ResourceGroup --output json | ConvertFrom-Json
if (-not $swa) { throw "SWA $Name not found in $ResourceGroup." }
$hostname = $swa.defaultHostname
$sku      = $swa.sku.name

Write-Host "Static Web App" -ForegroundColor Yellow
Write-Host "  hostname  : https://$hostname"
Write-Host "  location  : $($swa.location)"
Write-Host "  SKU       : $sku" -NoNewline
if ($sku -eq 'Free') {
    Write-Host "   ! FREE TIER" -ForegroundColor Red
} else {
    Write-Host "   ok" -ForegroundColor Green
}
Write-Host ""

# 2. App settings
$settings = az staticwebapp appsettings list --name $Name --resource-group $ResourceGroup --output json | ConvertFrom-Json
$settingsMap = @{}
if ($settings.properties) {
    foreach ($p in $settings.properties.PSObject.Properties) { $settingsMap[$p.Name] = $p.Value }
} elseif ($settings) {
    foreach ($p in $settings.PSObject.Properties) { $settingsMap[$p.Name] = $p.Value }
}
$aadId     = $settingsMap['AAD_CLIENT_ID']
$aadSecret = $settingsMap['AAD_CLIENT_SECRET']

Write-Host "SWA App Settings" -ForegroundColor Yellow
Write-Host "  AAD_CLIENT_ID     : $(if ($aadId) { $aadId } else { '<MISSING>' })"
Write-Host "  AAD_CLIENT_SECRET : $(if ($aadSecret) { '(set, ' + $aadSecret.Length + ' chars)' } else { '<MISSING>' })"
Write-Host ""

# 3. Entra app registration (if AAD_CLIENT_ID is set)
$entraOk = $false
if ($aadId) {
    $app = az ad app show --id $aadId --output json 2>$null | ConvertFrom-Json
    if ($app) {
        $entraOk = $true
        $expectedRedirect = "https://$hostname/.auth/login/aad/callback"
        $hasRedirect = $app.web.redirectUris -contains $expectedRedirect

        Write-Host "Entra App Registration" -ForegroundColor Yellow
        Write-Host "  appId             : $($app.appId)"
        Write-Host "  displayName       : $($app.displayName)"
        Write-Host "  signInAudience    : $($app.signInAudience)"
        Write-Host "  idTokenIssuance   : $(if ($app.web.implicitGrantSettings.enableIdTokenIssuance) { 'enabled ok' } else { 'DISABLED !' })"
        Write-Host "  redirect URIs     :"
        foreach ($uri in $app.web.redirectUris) {
            $marker = if ($uri -eq $expectedRedirect) { ' <- matches SWA ok' } else { '' }
            Write-Host "      $uri$marker"
        }
        if (-not $hasRedirect) {
            Write-Host "  ! EXPECTED redirect URI not in list:" -ForegroundColor Red
            Write-Host "      $expectedRedirect" -ForegroundColor Red
        }
        Write-Host ""
    } else {
        Write-Host "Entra App Registration" -ForegroundColor Yellow
        Write-Host "  ! Could not resolve appId $aadId. Either deleted, or no permission to read." -ForegroundColor Red
        Write-Host ""
    }
}

# 4. Diagnose + recommend
Write-Host "=== Diagnosis ===" -ForegroundColor Cyan
$issues = @()

if ($sku -eq 'Free' -and $aadId) {
    $issues += @{
        severity = 'CRITICAL'
        what     = "SWA is on FREE tier but configured with a custom Entra app registration."
        why      = "Free tier ignores custom AAD_CLIENT_ID/SECRET -- it only supports SWA's pre-configured AAD provider. The redirect callback never validates correctly, causing the loopback you're seeing."
        fix      = "Upgrade to Standard tier (~`$9/mo):  .\Upgrade-SwaToStandard.ps1   -- or pass -Sku Standard to az staticwebapp update."
    }
}
if (-not $aadId -or -not $aadSecret) {
    $issues += @{
        severity = 'HIGH'
        what     = "AAD_CLIENT_ID or AAD_CLIENT_SECRET missing from SWA app settings."
        why      = "The Entra-gated config references these -- without them the auth handshake can't complete."
        fix      = "Run .\Setup-EntraAuth.ps1 -StaticWebAppName $Name -ResourceGroup $ResourceGroup"
    }
}
if ($entraOk -and $aadId -and -not $hasRedirect) {
    $issues += @{
        severity = 'HIGH'
        what     = "The Entra app registration is missing the SWA's redirect URI."
        why      = "Entra rejects the auth callback because it doesn't trust the return URL, looping the user back to login."
        fix      = "Run .\Setup-EntraAuth.ps1 -- it adds the redirect URI idempotently."
    }
}
if ($entraOk -and $aadId -and -not $app.web.implicitGrantSettings.enableIdTokenIssuance) {
    $issues += @{
        severity = 'HIGH'
        what     = "ID token issuance is disabled on the Entra app registration."
        why      = "SWA needs ID tokens for sign-in. Without them, every callback fails."
        fix      = "az ad app update --id $aadId --enable-id-token-issuance true"
    }
}

if (-not $issues) {
    Write-Host "ok No common loopback causes detected. Auth wiring looks healthy." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Try signing in via InPrivate / Incognito to rule out a stale cookie." -ForegroundColor Gray
} else {
    foreach ($i in $issues) {
        $color = if ($i.severity -eq 'CRITICAL') { 'Red' } else { 'Yellow' }
        Write-Host ""
        Write-Host "[$($i.severity)]" -ForegroundColor $color -NoNewline
        Write-Host " $($i.what)" -ForegroundColor White
        Write-Host "  Why: $($i.why)" -ForegroundColor Gray
        Write-Host "  Fix: $($i.fix)" -ForegroundColor Cyan
    }
}
Write-Host ""
