<#
.SYNOPSIS
    Sweeps a Salesforce org's sObject schema via the sf CLI describe surface into a
    consolidated schema.json plus per-object raw describes.

.DESCRIPTION
    Read-only. Calls `sf sobject list` then `sf sobject describe` per object, saving each raw
    describe to RawDescribes/<Object>.json and condensing all of them into schema.json
    (objects, fields with types and picklists, relationships, record types).

    System-noise objects (__Share, __History, __Feed, __Tag, __ChangeEvent) are skipped unless
    -IncludeSystemNoise. Managed-package objects (namespace__Object__c) are skipped unless
    -IncludeManaged, but their namespaces are always recorded in the summary.

.PARAMETER OrgAlias
    sf CLI alias of the authenticated org (sf org login web --alias <alias>).

.PARAMETER OutputDir
    Directory for schema.json, _extract_summary.json and RawDescribes/.

.PARAMETER ObjectScope
    all (default) | custom | standard — passed to `sf sobject list --sobject`.

.PARAMETER SkipObjects
    Object API names to skip explicitly.

.PARAMETER Resume
    Reuse existing RawDescribes/<Object>.json instead of re-describing — for resuming an
    interrupted sweep or an API-limit backoff.

.EXAMPLE
    powershell -File Export-SfSchema.ps1 -OrgAlias client-prod -OutputDir agent/work/analysis/Salesforce_Extracted/client-prod
#>
Param(
    [Parameter(Mandatory = $true)] [string]$OrgAlias,
    [Parameter(Mandatory = $true)] [string]$OutputDir,
    [ValidateSet('all', 'custom', 'standard')] [string]$ObjectScope = 'all',
    [string[]]$SkipObjects = @(),
    [switch]$IncludeManaged,
    [switch]$IncludeSystemNoise,
    [switch]$Resume
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
    throw "sf CLI not found on PATH. Install Salesforce CLI v2: https://developer.salesforce.com/tools/salesforcecli"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$rawDir = Join-Path $OutputDir 'RawDescribes'
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

Write-Host "Listing sObjects (scope: $ObjectScope) in org '$OrgAlias'..."
$listRaw = sf sobject list --sobject $ObjectScope --target-org $OrgAlias --json
$listJson = $listRaw | ConvertFrom-Json
if ($listJson.status -ne 0) { throw "sf sobject list failed: $listRaw" }
$allNames = @($listJson.result)
Write-Host "  $($allNames.Count) objects listed."

$noiseSuffixes = @('__Share', '__History', '__Feed', '__Tag', '__ChangeEvent')
# namespace__Object__c|__mdt|__e = managed-package object (two separators)
$managedPattern = '^[A-Za-z0-9]+__[A-Za-z0-9_]+__(c|mdt|e)$'

$skippedNoise = [System.Collections.Generic.List[string]]::new()
$skippedManaged = [System.Collections.Generic.List[string]]::new()
$targets = [System.Collections.Generic.List[string]]::new()

foreach ($name in $allNames) {
    if ($SkipObjects -contains $name) { continue }
    if (-not $IncludeSystemNoise -and ($noiseSuffixes | Where-Object { $name.EndsWith($_) })) {
        $skippedNoise.Add($name); continue
    }
    if (-not $IncludeManaged -and $name -match $managedPattern) {
        $skippedManaged.Add($name); continue
    }
    $targets.Add($name)
}

$managedNamespaces = @($skippedManaged | ForEach-Object { ($_ -split '__')[0] } | Sort-Object -Unique)
Write-Host "  Describing $($targets.Count) objects (skipped: $($skippedNoise.Count) noise, $($skippedManaged.Count) managed across $($managedNamespaces.Count) namespaces)."

$objects = [System.Collections.Generic.List[object]]::new()
$relationships = [System.Collections.Generic.List[object]]::new()
$errors = [System.Collections.Generic.List[object]]::new()
$i = 0

foreach ($name in $targets) {
    $i++
    if ($i % 25 -eq 0) { Write-Host "  [$i/$($targets.Count)] $name" }

    $rawPath = Join-Path $rawDir "$name.json"
    $r = $null
    try {
        if ($Resume -and (Test-Path $rawPath)) {
            $r = Get-Content $rawPath -Raw | ConvertFrom-Json
        }
        else {
            $descRaw = sf sobject describe --sobject $name --target-org $OrgAlias --json
            $descJson = $descRaw | ConvertFrom-Json
            if ($descJson.status -ne 0) { throw "describe returned status $($descJson.status)" }
            $r = $descJson.result
            $r | ConvertTo-Json -Depth 20 | Set-Content -Path $rawPath -Encoding utf8
        }
    }
    catch {
        $errors.Add([pscustomobject]@{ object = $name; error = $_.Exception.Message })
        continue
    }

    $fields = foreach ($f in $r.fields) {
        [pscustomobject]@{
            name             = $f.name
            label            = $f.label
            type             = $f.type
            length           = $f.length
            precision        = $f.precision
            scale            = $f.scale
            custom           = $f.custom
            nillable         = $f.nillable
            unique           = $f.unique
            externalId       = $f.externalId
            calculated       = $f.calculated
            referenceTo      = $f.referenceTo
            relationshipName = $f.relationshipName
            picklistValues   = if ($f.picklistValues) { @($f.picklistValues | Where-Object { $_.active } | ForEach-Object { $_.value }) } else { $null }
        }
    }

    foreach ($f in @($r.fields | Where-Object { $_.type -eq 'reference' -and $_.referenceTo })) {
        foreach ($target in $f.referenceTo) {
            $relationships.Add([pscustomobject]@{
                from_object       = $r.name
                field             = $f.name
                to_object         = $target
                relationship_name = $f.relationshipName
                type              = if ($f.cascadeDelete) { 'master-detail' } else { 'lookup' }
            })
        }
    }

    $recordTypes = @($r.recordTypeInfos | Where-Object { -not $_.master } | ForEach-Object {
        [pscustomobject]@{ name = $_.name; developerName = $_.developerName; available = $_.available }
    })

    $objects.Add([pscustomobject]@{
        name         = $r.name
        label        = $r.label
        custom       = $r.custom
        keyPrefix    = $r.keyPrefix
        queryable    = $r.queryable
        field_count  = @($r.fields).Count
        fields       = $fields
        record_types = $recordTypes
    })
}

$schema = [pscustomobject]@{
    org           = $OrgAlias
    extracted_at  = (Get-Date -Format 'o')
    source        = 'live-org'
    object_scope  = $ObjectScope
    object_count  = $objects.Count
    objects       = $objects
    relationships = $relationships
    skipped       = [pscustomobject]@{
        system_noise       = $skippedNoise
        managed_package    = $skippedManaged
        managed_namespaces = $managedNamespaces
        requested          = $SkipObjects
    }
    errors        = $errors
}

$schemaPath = Join-Path $OutputDir 'schema.json'
$schema | ConvertTo-Json -Depth 12 | Set-Content -Path $schemaPath -Encoding utf8

$summary = [pscustomobject]@{
    org                = $OrgAlias
    extracted_at       = $schema.extracted_at
    objects_listed     = $allNames.Count
    objects_described  = $objects.Count
    skipped_noise      = $skippedNoise.Count
    skipped_managed    = $skippedManaged.Count
    managed_namespaces = $managedNamespaces
    errors             = $errors
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $OutputDir '_extract_summary.json') -Encoding utf8

Write-Host ""
Write-Host "Done. $($objects.Count) objects -> $schemaPath"
if ($errors.Count -gt 0) { Write-Host "$($errors.Count) objects failed - see errors[] in _extract_summary.json (re-run with -Resume to retry only failures)." }
