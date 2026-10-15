<#
.SYNOPSIS
    Extract deployment history from Azure DevOps YAML pipelines.

.DESCRIPTION
    Queries Azure DevOps REST APIs to extract deployment history from a 3-pipeline
    structure (Export, Build, Release). Auto-discovers environments from release pipeline
    stage names and solution selections from template parameters.

    Correlates deployments with solution versions from git history.

    Outputs a structured JSON file with all deployment records and version mappings.

    Uses shared ADO-Auth module for authentication (MSAL.PS interactive + PAT fallback),
    consistent with hso-ado-work-items.

.PARAMETER OrgUrl
    Azure DevOps organization URL (e.g., https://dev.azure.com/MyOrg).

.PARAMETER Project
    Azure DevOps project name.

.PARAMETER ExportPipeline
    Name of the export pipeline (exports solutions from Dev).

.PARAMETER BuildPipeline
    Name of the build pipeline (packs solutions into artifacts).

.PARAMETER ReleasePipeline
    Name of the release pipeline (deploys to target environments).

.PARAMETER SolutionParamMap
    Hashtable mapping template parameter names to solution names.
    Example: @{ deployConfiguration = 'MyConfiguration' }

.PARAMETER SolutionXmlPaths
    Array of solution XML paths relative to the repo root.
    Used to extract version numbers from git history.

.PARAMETER RepoRoot
    Path to the git repository root. Defaults to current directory.

.PARAMETER MaxReleaseRuns
    Maximum number of release runs to retrieve. Defaults to 200.

.PARAMETER OutputPath
    Path to write the output JSON file.

.PARAMETER Pat
    Personal Access Token for PAT-based authentication.

.EXAMPLE
    .\Get-DeploymentHistory.ps1 -OrgUrl "https://dev.azure.com/myorg" -Project "myproject" `
        -ExportPipeline "ExportSolutions" -BuildPipeline "BuildSolutions" `
        -ReleasePipeline "ReleaseSolutions" `
        -SolutionParamMap @{ deploySolution = 'MySolution' } `
        -SolutionXmlPaths @('Solutions/MySolution/Other/Solution.xml') `
        -OutputPath "agent\System\deployment_data.json"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$OrgUrl,

    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$ExportPipeline,

    [Parameter(Mandatory = $true)]
    [string]$BuildPipeline,

    [Parameter(Mandatory = $true)]
    [string]$ReleasePipeline,

    [Parameter(Mandatory = $true)]
    [hashtable]$SolutionParamMap,

    [Parameter(Mandatory = $true)]
    [string[]]$SolutionXmlPaths,

    [string]$RepoRoot = (Get-Location).Path,

    [int]$MaxReleaseRuns = 200,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Pat
)

$ErrorActionPreference = 'Stop'

# --- Import Shared Modules ---
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"   # for Install-MsalModuleIfMissing
. "$sharedDir\ADO-Auth.ps1"

# --- Authenticate ---
$auth = Get-AdoToken -OrgUrl $OrgUrl -Pat $Pat
if (-not $auth) {
    Write-Host "[ERROR] Authentication failed." -ForegroundColor Red
    exit 1
}

# Build headers using shared module
if ($auth.AuthType -eq 'Bearer') {
    $headers = Get-AdoHeaders -Token $auth.Token
} else {
    $headers = Get-AdoHeaders -Pat $auth.Pat
}

$Org = ($OrgUrl.TrimEnd('/') -split '/')[-1]

# --- Resolve Project ID ---
Write-Host "Resolving project '$Project'..." -ForegroundColor Cyan
$projUri = "$($OrgUrl.TrimEnd('/'))/_apis/projects?api-version=7.1"
$projResponse = Invoke-RestMethod -Uri $projUri -Headers $headers -Method Get
$targetProject = $projResponse.value | Where-Object { $_.name -eq $Project }
if (-not $targetProject) {
    Write-Error "Project '$Project' not found in organization '$Org'."
    exit 1
}
$projectId = $targetProject.id
$baseUrl = "$($OrgUrl.TrimEnd('/'))/$projectId"
Write-Host "  Project ID: $projectId" -ForegroundColor Green

# --- Resolve Pipeline Definition IDs by Name ---
Write-Host "Resolving pipeline definitions..." -ForegroundColor Cyan
$defUri = "${baseUrl}/_apis/build/definitions?api-version=7.1"
$defResponse = Invoke-RestMethod -Uri $defUri -Headers $headers -Method Get

$pipelineMap = @{}
foreach ($pName in @($ExportPipeline, $BuildPipeline, $ReleasePipeline)) {
    $match = $defResponse.value | Where-Object { $_.name -eq $pName }
    if (-not $match) {
        Write-Error "Pipeline '$pName' not found. Available: $(($defResponse.value | ForEach-Object { $_.name }) -join ', ')"
        exit 1
    }
    $pipelineMap[$pName] = $match.id
    Write-Host "  $pName -> Definition ID $($match.id)" -ForegroundColor Green
}

$releaseDefId = $pipelineMap[$ReleasePipeline]

# --- Get Release Pipeline Runs ---
Write-Host "Fetching release pipeline runs (up to $MaxReleaseRuns)..." -ForegroundColor Cyan
$relBuildsUri = "${baseUrl}/_apis/build/builds?definitions=${releaseDefId}&`$top=${MaxReleaseRuns}&api-version=7.1"
$relBuilds = Invoke-RestMethod -Uri $relBuildsUri -Headers $headers -Method Get
Write-Host "  Found $($relBuilds.value.Count) release runs" -ForegroundColor Green

# --- Process Each Release Run ---
Write-Host "Processing release run timelines..." -ForegroundColor Cyan
$deploymentRecords = @()

foreach ($build in $relBuilds.value) {
    $buildId = $build.id
    $buildNumber = $build.buildNumber
    $params = $build.templateParameters

    # Determine which solutions were selected via template parameters
    $selectedSolutions = @()
    foreach ($paramName in $SolutionParamMap.Keys) {
        $paramValue = $params.$paramName
        if ($paramValue -eq 'True' -or $paramValue -eq 'true') {
            $selectedSolutions += $SolutionParamMap[$paramName]
        }
    }

    $importMode = $params.importMode

    # Get timeline to discover stages and their results
    $timelineUri = "${baseUrl}/_apis/build/builds/${buildId}/timeline?api-version=7.1"
    try {
        $timeline = Invoke-RestMethod -Uri $timelineUri -Headers $headers -Method Get
    }
    catch {
        Write-Host "  WARNING: Could not get timeline for build $buildNumber (ID: ${buildId})" -ForegroundColor Yellow
        continue
    }

    # Auto-discover deployment stages (type = 'Stage', name contains 'Deploy')
    $stages = $timeline.records | Where-Object { $_.type -eq 'Stage' -and $_.name -match 'Deploy' }

    foreach ($stage in $stages) {
        # Extract environment name from stage name (e.g., "Deploy to QA" -> "QA")
        $environment = $stage.name
        if ($environment -match 'Deploy\s+to\s+(.+)') {
            $environment = $Matches[1].Trim()
        }

        $record = [PSCustomObject]@{
            BuildNumber = $buildNumber
            BuildId     = $buildId
            Environment = $environment
            StageName   = $stage.name
            Result      = if ($stage.result) { $stage.result } else { $stage.state }
            StartTime   = $stage.startTime
            FinishTime  = $stage.finishTime
            Solutions   = ($selectedSolutions -join ', ')
            ImportMode  = $importMode
        }
        $deploymentRecords += $record
    }
}

Write-Host "  Extracted $($deploymentRecords.Count) deployment stage records" -ForegroundColor Green

# --- Extract Solution Versions from Git History ---
Write-Host "Extracting solution versions from git history..." -ForegroundColor Cyan
$versionMap = @{}

foreach ($solFile in $SolutionXmlPaths) {
    $solName = ($solFile -split '/')[1]  # e.g., "MyConfiguration"
    $commits = git -C $RepoRoot log --oneline --format="%h|%ai|%s" -- $solFile 2>&1

    foreach ($line in $commits) {
        if (-not $line -or $line -is [System.Management.Automation.ErrorRecord]) { continue }
        $parts = $line -split '\|', 3
        if ($parts.Count -lt 3) { continue }

        $hash = $parts[0]
        $date = $parts[1]
        $msg = $parts[2]

        # Extract build number from commit message
        $buildMatch = [regex]::Match($msg, 'build (\d{8}\.\d+)')
        if (-not $buildMatch.Success) { continue }
        $exportBuild = $buildMatch.Groups[1].Value

        # Get version from Solution.xml at this commit
        try {
            $xmlContent = git -C $RepoRoot show "${hash}:${solFile}" 2>&1
            $versionMatch = [regex]::Match($xmlContent, '<Version>([\d\.]+)</Version>')
            if ($versionMatch.Success) {
                $version = $versionMatch.Groups[1].Value
            }
            else { $version = 'Unknown' }
        }
        catch { $version = 'Error' }

        if (-not $versionMap.ContainsKey($exportBuild)) {
            $versionMap[$exportBuild] = @{
                Date       = $date
                CommitHash = $hash
                Solutions  = @{}
            }
        }
        $versionMap[$exportBuild].Solutions[$solName] = $version
    }
}

# Build a sorted list of export versions for lookup
$exportVersions = @()
foreach ($key in $versionMap.Keys) {
    # Use the first solution's version as representative (they're synchronized)
    $firstSol = ($versionMap[$key].Solutions.Values | Select-Object -First 1)
    $exportVersions += [PSCustomObject]@{
        ExportBuild = $key
        Version     = $firstSol
        Date        = $versionMap[$key].Date
    }
}
$exportVersions = $exportVersions | Sort-Object { [datetime]$_.Date } -Descending

Write-Host "  Found $($exportVersions.Count) solution export versions" -ForegroundColor Green

# --- Build Final Output ---
$output = [PSCustomObject]@{
    GeneratedAt       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    Organization      = $Org
    Project           = $Project
    Pipelines         = [PSCustomObject]@{
        Export  = [PSCustomObject]@{ Name = $ExportPipeline; Id = $pipelineMap[$ExportPipeline] }
        Build   = [PSCustomObject]@{ Name = $BuildPipeline; Id = $pipelineMap[$BuildPipeline] }
        Release = [PSCustomObject]@{ Name = $ReleasePipeline; Id = $pipelineMap[$ReleasePipeline] }
    }
    SolutionVersions  = $exportVersions
    DeploymentRecords = $deploymentRecords
}

$output | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "`nOutput written to: $OutputPath" -ForegroundColor Green
Write-Host "  $($deploymentRecords.Count) deployment records, $($exportVersions.Count) version entries" -ForegroundColor Green
