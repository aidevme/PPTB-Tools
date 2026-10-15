<#
.SYNOPSIS
    Safe pac CLI round-trip for authoring Power Pages design-studio site content (standard or enhanced data model).

.DESCRIPTION
    Wraps the supported `pac pages` command group for the download -> edit -> upload authoring loop:
      - ListSites    : list Power Pages sites in the environment (Website IDs + data model)
      - DetectModel  : report a target site's data model (Standard | Enhanced) so callers pass the right --modelVersion
      - Download     : download site content to a working folder (--modelVersion auto-detected unless overridden)
      - Upload       : upload edited content back (--modelVersion auto-detected unless overridden; delta on same env)

    Page creation and component edits are FILE operations on the downloaded folder and are performed by
    the caller (mirror an existing component's files) -- there is no `pac pages create-page`. This script
    owns only the safe pac orchestration and the data-model guardrail.

    This skill supports BOTH the standard and enhanced data models. It DETECTS the site's data model and
    passes the MATCHING --modelVersion (1 = standard, 2 = enhanced) on every download/upload, because the
    CLI defaults to --modelVersion 1 and silently targeting the wrong model's tables is the most common
    Power Pages automation failure. Pass -ModelVersion to override detection when it can't be determined.

.PARAMETER Operation
    ListSites | DetectModel | Download | Upload

.PARAMETER EnvironmentUrl
    Dataverse / Power Pages environment URL (e.g. https://myorg.crm.dynamics.com). Used to scope ListSites.
    Auth itself is handled by the PAC auth profile (`pac auth create --environment <url>`).

.PARAMETER WebsiteId
    GUID of the target Power Pages site. Required for DetectModel and Download.

.PARAMETER Path
    Working folder for Download / Upload (e.g. .\PowerPages\<SiteName>).

.PARAMETER ModelVersion
    Optional override for the data model version ('1' = standard, '2' = enhanced). If omitted, Download and
    Upload auto-detect the model from `pac pages list -v`. Supply it only when detection can't determine the
    model (e.g. a parser miss) or to force a specific version deliberately.

.PARAMETER DeploymentProfile
    Optional deployment profile name passed to Upload (--deploymentProfile).

.PARAMETER ForceUploadAll
    Switch. Forces a full upload instead of a delta (drift / partial-failure recovery).

.PARAMETER PacExe
    Full path to pac.exe. If omitted, the script resolves `pac` from PATH. Path is in CLAUDE.local.md.

.EXAMPLE
    .\Invoke-PowerPagesAuthoring.ps1 -Operation ListSites -EnvironmentUrl "https://myorg.crm.dynamics.com"

.EXAMPLE
    .\Invoke-PowerPagesAuthoring.ps1 -Operation DetectModel -WebsiteId "00000000-0000-0000-0000-000000000000"

.EXAMPLE
    .\Invoke-PowerPagesAuthoring.ps1 -Operation Download -WebsiteId "<guid>" -Path ".\PowerPages\ContosoSite"

.EXAMPLE
    .\Invoke-PowerPagesAuthoring.ps1 -Operation Upload -Path ".\PowerPages\ContosoSite" -DeploymentProfile dev

.NOTES
    Requires: PAC CLI (>= 1.22.4 for `pac pages list -v` model reporting; Power Pages GA since 1.9.8).
    Authenticate first: pac auth create --environment <EnvironmentUrl>.

    VALIDATION NOTE: the `pac pages list` text format is parsed heuristically in Get-SiteDataModel.
    Validate the parser against real `pac pages list -v` output on first use and adjust the regex if needed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ListSites", "DetectModel", "Download", "Upload")]
    [string]$Operation,

    [string]$EnvironmentUrl,
    [string]$WebsiteId,
    [string]$Path,
    [ValidateSet("1", "2")]
    [string]$ModelVersion,
    [string]$DeploymentProfile,
    [switch]$ForceUploadAll,
    [string]$PacExe
)

$ErrorActionPreference = "Stop"

function Resolve-Pac {
    param([string]$Explicit)
    if ($Explicit) {
        if (-not (Test-Path $Explicit)) { throw "PacExe path not found: $Explicit" }
        return $Explicit
    }
    $cmd = Get-Command pac -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "pac CLI not found on PATH. Pass -PacExe with the path from CLAUDE.local.md, or add pac to PATH."
}

function Invoke-Pac {
    param([string]$Pac, [string[]]$PacArgs)
    Write-Host "→ pac $($PacArgs -join ' ')" -ForegroundColor Cyan
    $output = & $Pac @PacArgs 2>&1
    $output | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "pac exited with code $LASTEXITCODE for: pac $($PacArgs -join ' ')"
    }
    return $output
}

function Get-SiteDataModel {
    # Returns 'Enhanced' | 'Standard' | 'Unknown' for the given WebsiteId by parsing `pac pages list -v`.
    param([string]$Pac, [string]$Id)
    $lines = & $Pac pages list -v 2>&1
    if ($LASTEXITCODE -ne 0) { throw "pac pages list -v failed (exit $LASTEXITCODE). Are you authenticated? Run: pac auth create --environment <url>" }

    $row = $lines | Where-Object { $_ -match [regex]::Escape($Id) }
    if (-not $row) {
        throw "Website ID '$Id' not found in this environment. Run -Operation ListSites to see available sites."
    }
    $rowText = ($row -join " ")
    if ($rowText -match '(?i)enhanced') { return 'Enhanced' }
    if ($rowText -match '(?i)standard') { return 'Standard' }
    return 'Unknown'
}

function Resolve-ModelVersion {
    # Returns "1" (standard) or "2" (enhanced). Honors an explicit -ModelVersion override; otherwise detects.
    param([string]$Pac, [string]$Id, [string]$Override)
    if ($Override) {
        Write-Host "Using -ModelVersion override: $Override ($(if ($Override -eq '2') {'enhanced'} else {'standard'}))." -ForegroundColor Yellow
        return $Override
    }
    $model = Get-SiteDataModel -Pac $Pac -Id $Id
    switch ($model) {
        'Enhanced' { Write-Host "Detected ENHANCED data model -> --modelVersion 2." -ForegroundColor Green; return "2" }
        'Standard' { Write-Host "Detected STANDARD data model -> --modelVersion 1." -ForegroundColor Green; return "1" }
        default    { throw "Could not determine the data model for $Id from `pac pages list -v`. Verify it in PPAC (Resources > Power Pages sites > Site details) and re-run with -ModelVersion 1 or -ModelVersion 2." }
    }
}

# ---- main ------------------------------------------------------------------
$pac = Resolve-Pac -Explicit $PacExe

switch ($Operation) {

    "ListSites" {
        $pacArgs = @("pages", "list", "-v")
        if ($EnvironmentUrl) { $pacArgs += @("--environment", $EnvironmentUrl) }
        Invoke-Pac -Pac $pac -PacArgs $pacArgs | Out-Null
    }

    "DetectModel" {
        if (-not $WebsiteId) { throw "DetectModel requires -WebsiteId." }
        $model = Get-SiteDataModel -Pac $pac -Id $WebsiteId
        switch ($model) {
            'Enhanced' { Write-Host "Site $WebsiteId is on the ENHANCED data model (use --modelVersion 2). CLI round-trip is the write path." -ForegroundColor Green; exit 0 }
            'Standard' { Write-Host "Site $WebsiteId is on the STANDARD data model (use --modelVersion 1). CLI round-trip works; record-level adx_* Web API writes are also viable." -ForegroundColor Green; exit 0 }
            default    { Write-Warning "Could not determine the data model from `pac pages list -v` for $WebsiteId. Verify manually in PPAC (Resources > Power Pages sites > Site details), then pass -ModelVersion 1 or 2 to Download/Upload."; exit 3 }
        }
    }

    "Download" {
        if (-not $WebsiteId) { throw "Download requires -WebsiteId." }
        if (-not $Path)      { throw "Download requires -Path." }
        # Detect (or honor override) so the working folder matches the site's model.
        $mv = Resolve-ModelVersion -Pac $pac -Id $WebsiteId -Override $ModelVersion
        $pacArgs = @("pages", "download", "--path", $Path, "--webSiteId", $WebsiteId, "--modelVersion", $mv, "--overwrite")
        if ($EnvironmentUrl) { $pacArgs += @("--environment", $EnvironmentUrl) }
        Invoke-Pac -Pac $pac -PacArgs $pacArgs | Out-Null
        Write-Host "Downloaded to $Path (--modelVersion $mv). Gitignore the per-environment manifest; commit the delete-tracking manifest.yml." -ForegroundColor Green
    }

    "Upload" {
        if (-not $Path) { throw "Upload requires -Path." }
        if (-not (Test-Path $Path)) { throw "Upload path not found: $Path" }
        # Upload must use the SAME model version the folder was downloaded with. Detect from WebsiteId,
        # or require -ModelVersion when no WebsiteId is supplied (so we never fall back to the CLI default of 1).
        if ($ModelVersion)    { $mv = $ModelVersion }
        elseif ($WebsiteId)   { $mv = Resolve-ModelVersion -Pac $pac -Id $WebsiteId -Override $null }
        else { throw "Upload needs the data model version. Pass -ModelVersion (1=standard, 2=enhanced), or -WebsiteId to auto-detect. The CLI default of 1 must never be relied on." }
        $pacArgs = @("pages", "upload", "--path", $Path, "--modelVersion", $mv)
        if ($DeploymentProfile) { $pacArgs += @("--deploymentProfile", $DeploymentProfile) }
        if ($ForceUploadAll)    { $pacArgs += @("--forceUploadAll") }
        if ($EnvironmentUrl)    { $pacArgs += @("--environment", $EnvironmentUrl) }
        Invoke-Pac -Pac $pac -PacArgs $pacArgs | Out-Null
        Write-Host "Upload complete (--modelVersion $mv). If a change isn't visible, suspect caching first (see ALM SOP `today` cache-buster), not a failed upload." -ForegroundColor Green
    }
}
