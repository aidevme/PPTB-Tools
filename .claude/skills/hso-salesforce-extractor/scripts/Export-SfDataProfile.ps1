<#
.SYNOPSIS
    Profiles a Salesforce org's data — org-wide row counts plus sampled fill rates and
    cardinality — into data_profile.json. Aggregates only; no record data is written to disk.

.DESCRIPTION
    Read-only. Two passes:
      1. Row counts via the REST recordCount endpoint (approximate, cheap), chunked.
         Objects the endpoint does not cover get count = null; -CountFallback re-counts
         those with per-object SELECT COUNT() queries (slow — one API call each).
      2. For each object with rows, samples up to -SampleSize records (FIELDS(ALL),
         hard platform cap 200) and computes per-field fill rate and distinct-value count.

    PII discipline: sampled records are held in memory only. Nothing record-level is ever
    written to disk — data_profile.json contains aggregates exclusively.

.PARAMETER OrgAlias
    sf CLI alias of the authenticated org.

.PARAMETER SchemaJsonPath
    schema.json produced by Export-SfSchema.ps1 — supplies the object list.

.PARAMETER OutputDir
    Directory for data_profile.json.

.PARAMETER SampleSize
    Rows to sample per object for fill-rate/cardinality (max 200 — FIELDS(ALL) platform limit).

.PARAMETER Objects
    Restrict profiling to these object API names (default: every queryable object in schema.json).

.PARAMETER CountFallback
    For objects the recordCount endpoint omits, run SELECT COUNT() per object.

.PARAMETER ApiVersion
    REST API version for the recordCount endpoint. Default 62.0.

.EXAMPLE
    powershell -File Export-SfDataProfile.ps1 -OrgAlias client-prod `
        -SchemaJsonPath out/schema.json -OutputDir out
#>
Param(
    [Parameter(Mandatory = $true)] [string]$OrgAlias,
    [Parameter(Mandatory = $true)] [string]$SchemaJsonPath,
    [Parameter(Mandatory = $true)] [string]$OutputDir,
    [int]$SampleSize = 200,
    [string[]]$Objects = @(),
    [switch]$CountFallback,
    [string]$ApiVersion = '62.0'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
    throw "sf CLI not found on PATH. Install Salesforce CLI v2: https://developer.salesforce.com/tools/salesforcecli"
}
if (-not (Test-Path $SchemaJsonPath)) { throw "Schema file not found: $SchemaJsonPath (run Export-SfSchema.ps1 first)" }
if ($SampleSize -gt 200) {
    Write-Host "SampleSize capped at 200 (FIELDS(ALL) platform limit)."
    $SampleSize = 200
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$schema = Get-Content $SchemaJsonPath -Raw | ConvertFrom-Json

$targets = @($schema.objects | Where-Object { $_.queryable -ne $false })
if ($Objects.Count -gt 0) { $targets = @($targets | Where-Object { $Objects -contains $_.name }) }
Write-Host "Profiling $($targets.Count) objects in org '$OrgAlias'..."

$errors = [System.Collections.Generic.List[object]]::new()
$counts = @{}

# --- Pass 1: row counts via recordCount endpoint, chunked ---------------------------------
$chunkSize = 20
for ($c = 0; $c -lt $targets.Count; $c += $chunkSize) {
    $chunk = @($targets[$c..([Math]::Min($c + $chunkSize - 1, $targets.Count - 1))].name)
    $url = "/services/data/v$ApiVersion/limits/recordCount?sObjects=$($chunk -join ',')"
    try {
        $resp = sf api request rest $url --target-org $OrgAlias | ConvertFrom-Json
        foreach ($entry in @($resp.sObjects)) { $counts[$entry.name] = $entry.count }
    }
    catch {
        $errors.Add([pscustomobject]@{ stage = 'recordCount'; objects = ($chunk -join ','); error = $_.Exception.Message })
    }
}

if ($CountFallback) {
    foreach ($t in $targets | Where-Object { -not $counts.ContainsKey($_.name) }) {
        try {
            $q = sf data query --query "SELECT COUNT() FROM $($t.name)" --target-org $OrgAlias --json | ConvertFrom-Json
            if ($q.status -eq 0) { $counts[$t.name] = $q.result.totalSize }
        }
        catch {
            $errors.Add([pscustomobject]@{ stage = 'countFallback'; objects = $t.name; error = $_.Exception.Message })
        }
    }
}

# --- Pass 2: sampled fill rate / cardinality (in-memory only) -----------------------------
$profiles = [System.Collections.Generic.List[object]]::new()
$i = 0
foreach ($t in $targets) {
    $i++
    $rowCount = if ($counts.ContainsKey($t.name)) { $counts[$t.name] } else { $null }
    $fieldStats = $null
    $sampled = 0

    if ($null -ne $rowCount -and $rowCount -gt 0) {
        if ($i % 25 -eq 0) { Write-Host "  [$i/$($targets.Count)] $($t.name)" }
        $records = $null
        foreach ($soql in @(
                "SELECT FIELDS(ALL) FROM $($t.name) ORDER BY CreatedDate DESC LIMIT $SampleSize",
                "SELECT FIELDS(ALL) FROM $($t.name) LIMIT $SampleSize")) {
            try {
                $q = sf data query --query $soql --target-org $OrgAlias --json | ConvertFrom-Json
                if ($q.status -eq 0) { $records = @($q.result.records); break }
            }
            catch { }
        }

        if ($null -eq $records) {
            $errors.Add([pscustomobject]@{ stage = 'sample'; objects = $t.name; error = 'FIELDS(ALL) sample failed with and without ORDER BY' })
        }
        else {
            $sampled = $records.Count
            $fieldStats = [System.Collections.Generic.List[object]]::new()
            foreach ($fld in $t.fields) {
                $nonNull = 0
                $distinct = [System.Collections.Generic.HashSet[string]]::new()
                foreach ($rec in $records) {
                    $v = $rec.($fld.name)
                    if ($null -ne $v -and "$v" -ne '') {
                        $nonNull++
                        # Compound values (address/geolocation) arrive as objects — serialize for hashing
                        $key = if ($v -is [pscustomobject]) { ($v | ConvertTo-Json -Compress -Depth 4) } else { "$v" }
                        [void]$distinct.Add($key)
                    }
                }
                $fieldStats.Add([pscustomobject]@{
                    name               = $fld.name
                    fill_rate          = if ($sampled -gt 0) { [Math]::Round($nonNull / $sampled, 3) } else { $null }
                    distinct_in_sample = $distinct.Count
                })
            }
            $records = $null   # release sample — nothing record-level leaves memory
        }
    }

    $profiles.Add([pscustomobject]@{
        name        = $t.name
        row_count   = $rowCount
        sample_size = $sampled
        fields      = $fieldStats
    })
}

$profile = [pscustomobject]@{
    org          = $OrgAlias
    profiled_at  = (Get-Date -Format 'o')
    sample_limit = $SampleSize
    note         = 'Aggregates only. Fill rate and cardinality are computed from a recent-records sample, not a full scan; row_count is the approximate recordCount value.'
    objects      = $profiles
    errors       = $errors
}
$profilePath = Join-Path $OutputDir 'data_profile.json'
$profile | ConvertTo-Json -Depth 8 | Set-Content -Path $profilePath -Encoding utf8

Write-Host ""
Write-Host "Done. $($profiles.Count) objects -> $profilePath"
if ($errors.Count -gt 0) { Write-Host "$($errors.Count) profiling errors - see errors[] in data_profile.json." }
