# Reset-Deployment.ps1
# Nuclear option: delete the existing SWA (and optionally the Entra app reg) and
# redeploy fresh with EasyAuth (Free tier + Microsoft built-in Entra provider).
#
# Defaults: pulls -Name and -ResourceGroup from .deploy-config.json.
#
# Examples:
#   .\Reset-Deployment.ps1                              # interactive confirm + redeploy
#   .\Reset-Deployment.ps1 -DeleteAppReg                # also delete the Entra app reg
#   .\Reset-Deployment.ps1 -Force                       # skip confirmation
#   .\Reset-Deployment.ps1 -Name foo -ResourceGroup rg # explicit
#
# After this finishes:
#   1. Open https://<new-hostname>/ in an InPrivate window
#   2. Sign in with any Entra account
#   3. No loopback
#requires -Version 5.1

param(
    [string]$Name,
    [string]$ResourceGroup,
    # Default: "<SWA name> Auth" -- matches Setup-EntraAuth.ps1's derived default.
    [string]$AppDisplayName,
    [ValidateSet('EasyAuth', 'Custom', 'None')]
    [string]$AuthMode = 'Custom',
    [switch]$DeleteAppReg,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '.deploy-config.json'
if ((-not $Name -or -not $ResourceGroup) -and (Test-Path $configPath)) {
    $cached = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $Name)          { $Name          = $cached.Name }
    if (-not $ResourceGroup) { $ResourceGroup = $cached.ResourceGroup }
}
if (-not $Name -or -not $ResourceGroup) {
    throw "Pass -Name and -ResourceGroup, or run after a previous Deploy-LearningPack.ps1."
}

# Derive a sensible app display name from the SWA name if the caller didn't
# supply one -- matches Setup-EntraAuth.ps1's derivation.
if (-not $AppDisplayName) {
    $AppDisplayName = "$Name Auth"
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Learning Pack -- Reset Deployment" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Target SWA  : $Name" -ForegroundColor Gray
Write-Host " ResourceGrp : $ResourceGroup" -ForegroundColor Gray
Write-Host " AuthMode    : $AuthMode" -ForegroundColor Gray
Write-Host " Delete app  : $($DeleteAppReg.IsPresent)" -ForegroundColor Gray
Write-Host ""
$modeDesc = switch ($AuthMode) {
    'Custom'   { 'Custom Entra (Standard SKU, ~$9/mo, tenant-restricted, no consent loop)' }
    'EasyAuth' { 'EasyAuth (Free SKU, built-in Microsoft provider, any Entra account)'      }
    'None'     { 'None (public, no auth gate)'                                              }
}
Write-Host " Plan:"                                  -ForegroundColor Yellow
$step = 1
Write-Host "   $step. Delete Static Web App  : $Name"   -ForegroundColor Yellow
$step++
if ($DeleteAppReg) {
    Write-Host "   $step. Delete Entra app reg   : '$AppDisplayName'" -ForegroundColor Yellow
    $step++
}
Write-Host "   $step. Clear cached deploy config"                  -ForegroundColor Yellow
$step++
Write-Host "   $step. Redeploy: $modeDesc"           -ForegroundColor Yellow
if ($AuthMode -eq 'Custom') {
    $step++
    Write-Host "   $step. Run Setup-EntraAuth.ps1 (creates fresh app reg + secret + appsettings)" -ForegroundColor Yellow
}
Write-Host ""

if (-not $Force) {
    $reply = Read-Host "Proceed? Type 'yes' to confirm"
    if ($reply -ne 'yes') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

# --- Step 1: delete the SWA ---
$existing = az staticwebapp show --name $Name --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
if ($existing) {
    Write-Host ""
    Write-Host "==> Deleting Static Web App '$Name'..." -ForegroundColor Cyan
    az staticwebapp delete --name $Name --resource-group $ResourceGroup --yes --output none
    if ($LASTEXITCODE -ne 0) { throw "Delete failed (exit $LASTEXITCODE)." }
    Write-Host "  ok deleted" -ForegroundColor Green

    # SWA names need a brief beat before reuse
    Write-Host "  waiting 8s for name to free up ..." -ForegroundColor Gray
    Start-Sleep -Seconds 8
} else {
    Write-Host ""
    Write-Host "==> Static Web App '$Name' not present (nothing to delete)." -ForegroundColor Gray
}

# --- Step 2 (optional): delete the Entra app reg ---
if ($DeleteAppReg) {
    Write-Host ""
    Write-Host "==> Looking for Entra app reg '$AppDisplayName'..." -ForegroundColor Cyan
    $apps = az ad app list --display-name $AppDisplayName --output json | ConvertFrom-Json
    if ($apps -and $apps.Count -ge 1) {
        foreach ($a in $apps) {
            Write-Host "  Deleting app reg appId=$($a.appId)" -ForegroundColor Gray
            az ad app delete --id $a.appId --output none
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ok deleted $($a.appId)" -ForegroundColor Green
            } else {
                Write-Host "  ! delete failed for $($a.appId) -- continuing" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  none found -- nothing to delete." -ForegroundColor Gray
    }
}

# --- Step 3: clear cached config ---
Write-Host ""
if (Test-Path $configPath) {
    Remove-Item $configPath -Force
    Write-Host "==> Cleared cached deploy config." -ForegroundColor Cyan
} else {
    Write-Host "==> No cached deploy config to clear." -ForegroundColor Gray
}

# --- Step 4: redeploy ---
Write-Host ""
Write-Host "==> Redeploying with AuthMode=$AuthMode ..." -ForegroundColor Cyan
Write-Host ""

& (Join-Path $PSScriptRoot 'Deploy-LearningPack.ps1') `
    -Target StaticWebApp `
    -Name $Name `
    -ResourceGroup $ResourceGroup `
    -AuthMode $AuthMode

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Deploy step failed. Inspect output above." -ForegroundColor Red
    exit 1
}

# --- Step 5 (Custom mode only): run Setup-EntraAuth ---
if ($AuthMode -eq 'Custom') {
    Write-Host ""
    Write-Host "==> Setting up Entra app registration + appsettings..." -ForegroundColor Cyan
    Write-Host ""

    & (Join-Path $PSScriptRoot 'Setup-EntraAuth.ps1') `
        -StaticWebAppName $Name `
        -ResourceGroup    $ResourceGroup `
        -AppDisplayName   $AppDisplayName

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Setup-EntraAuth failed. Inspect output above." -ForegroundColor Red
        exit 1
    }

    # Final hint for admin consent (the script printed the URL too, but echo it again)
    $swa = az staticwebapp show --name $Name --resource-group $ResourceGroup --output json | ConvertFrom-Json
    $appId = (az staticwebapp appsettings list --name $Name --resource-group $ResourceGroup --output json |
              ConvertFrom-Json).properties.AAD_CLIENT_ID
    $account = az account show --output json | ConvertFrom-Json
    if ($appId -and $account) {
        $consentUrl = "https://login.microsoftonline.com/$($account.tenantId)/adminconsent?client_id=$appId"
        Write-Host ""
        Write-Host "----------------------------------------------" -ForegroundColor Yellow
        Write-Host " IF YOU HIT A CONSENT PROMPT ON SIGN-IN:"        -ForegroundColor Yellow
        Write-Host "----------------------------------------------" -ForegroundColor Yellow
        Write-Host " A tenant admin (or you, if you have the role) can grant tenant-wide consent" -ForegroundColor Yellow
        Write-Host " once by visiting this URL -- eliminates the loop for every future user:"      -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   $consentUrl" -ForegroundColor Cyan
        Write-Host ""
    }
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " ok Reset + redeploy complete." -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open the URL above in an InPrivate / Incognito window."
if ($AuthMode -eq 'Custom') {
    Write-Host "  2. Sign in with an HSO Entra account (or whatever tenant you targeted)."
    Write-Host "  3. If a consent screen appears, accept it (or visit the admin-consent URL once)."
} elseif ($AuthMode -eq 'EasyAuth') {
    Write-Host "  2. Sign in with any Entra account."
} else {
    Write-Host "  2. No sign-in required -- public access."
}
Write-Host ""
