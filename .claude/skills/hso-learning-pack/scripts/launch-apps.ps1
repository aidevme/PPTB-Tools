# launch-apps.ps1
# Opens the deployed Unite apps (or the OneDigital source environment) in the user's default browser.
# Single entry point for sales demos, exec walkthroughs, and screenshot capture.
#
# Usage:
#   .\launch-apps.ps1                 # Launches hsouscloud (default)
#   .\launch-apps.ps1 -Env OneDigital # Launches OneDigital Dev environment
#   .\launch-apps.ps1 -Env Local      # Launches localhost (assumes dotnet run is up)
#   .\launch-apps.ps1 -App CashHub    # Only opens CashHub
#requires -Version 5.1

param(
    [ValidateSet('hsouscloud', 'OneDigital', 'Local')]
    [string]$Env = 'hsouscloud',

    [ValidateSet('Both', 'CashHub', 'CompHub', 'Portal')]
    [string]$App = 'Both'
)

$ErrorActionPreference = 'Stop'

$envs = @{
    'hsouscloud' = @{
        CashHub  = 'https://app-onedigital-cashhub-dev.azurewebsites.net'
        CompHub  = 'https://app-onedigital-comphub-dev.azurewebsites.net'
        Portal   = $null  # not yet deployed to hsouscloud per SPEC-productization Phase 1
    }
    'OneDigital' = @{
        CashHub  = 'https://app-dev-cash-hub-01.azurewebsites.net'
        CompHub  = 'https://app-dev-comp-hub-01.azurewebsites.net'
        Portal   = 'https://app-dev-producer-portal-01.azurewebsites.net'
    }
    'Local'      = @{
        CashHub  = 'https://localhost:7100'
        CompHub  = 'https://localhost:7200'
        Portal   = 'https://localhost:7300'
    }
}

$targets = $envs[$Env]

function Open-Url($name, $url) {
    if (-not $url) {
        Write-Host "  $name not configured for $Env -- skipping" -ForegroundColor Yellow
        return
    }
    Write-Host "  Opening $name : $url" -ForegroundColor Cyan
    Start-Process $url
}

Write-Host ""
Write-Host "ERP Unite -- launching $Env environment" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor DarkGray
Write-Host ""

switch ($App) {
    'Both'    { Open-Url 'CashHub' $targets.CashHub; Open-Url 'CompHub' $targets.CompHub }
    'CashHub' { Open-Url 'CashHub' $targets.CashHub }
    'CompHub' { Open-Url 'CompHub' $targets.CompHub }
    'Portal'  { Open-Url 'Producer Portal' $targets.Portal }
}

Write-Host ""
Write-Host "Done. Sign in with your OneDigital / HSO Entra account." -ForegroundColor Green
