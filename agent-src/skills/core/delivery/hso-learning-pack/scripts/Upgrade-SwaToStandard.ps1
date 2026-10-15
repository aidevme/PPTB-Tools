# Upgrade-SwaToStandard.ps1
# Upgrades the SWA from Free -> Standard so custom Entra auth actually works.
# Cost: ~$9/month per SWA.
#
# Run with no params (uses .deploy-config.json) or pass -Name + -ResourceGroup.
#requires -Version 5.1

param(
    [string]$Name,
    [string]$ResourceGroup,
    [switch]$YesIAcceptCost
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '.deploy-config.json'
if ((-not $Name -or -not $ResourceGroup) -and (Test-Path $configPath)) {
    $cached = Get-Content $configPath -Raw | ConvertFrom-Json
    if (-not $Name) { $Name = $cached.Name }
    if (-not $ResourceGroup) { $ResourceGroup = $cached.ResourceGroup }
}
if (-not $Name -or -not $ResourceGroup) {
    throw "Pass -Name and -ResourceGroup, or run after Deploy-LearningPack.ps1."
}

Write-Host ""
Write-Host "Static Web App: $Name (RG $ResourceGroup)" -ForegroundColor Cyan
$swa = az staticwebapp show --name $Name --resource-group $ResourceGroup --output json | ConvertFrom-Json
if (-not $swa) { throw "SWA $Name not found." }

Write-Host "Current SKU: $($swa.sku.name)" -ForegroundColor Yellow
if ($swa.sku.name -eq 'Standard') {
    Write-Host "Already on Standard. No action needed." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "This will change the billing SKU to Standard." -ForegroundColor Yellow
Write-Host "  Cost: ~`$9 USD per month per SWA." -ForegroundColor Yellow
Write-Host "  Standard unlocks: custom Entra auth, private endpoints, named environments, SLA." -ForegroundColor Gray
Write-Host ""

if (-not $YesIAcceptCost) {
    $reply = Read-Host "Proceed? Type 'yes' to confirm"
    if ($reply -ne 'yes') {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "==> Upgrading SKU to Standard..." -ForegroundColor Cyan
az staticwebapp update `
    --name $Name `
    --resource-group $ResourceGroup `
    --sku Standard `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "az staticwebapp update failed (exit $LASTEXITCODE)."
}

# Verify
$swaAfter = az staticwebapp show --name $Name --resource-group $ResourceGroup --output json | ConvertFrom-Json
Write-Host "ok New SKU: $($swaAfter.sku.name)" -ForegroundColor Green
Write-Host ""
Write-Host "Custom Entra auth is now supported. Sign in via:" -ForegroundColor Cyan
Write-Host "  https://$($swaAfter.defaultHostname)" -ForegroundColor Cyan
Write-Host ""
Write-Host "If you still see a loopback after this, run:" -ForegroundColor Gray
Write-Host "  .\Diagnose-SwaAuth.ps1" -ForegroundColor Gray
Write-Host ""
