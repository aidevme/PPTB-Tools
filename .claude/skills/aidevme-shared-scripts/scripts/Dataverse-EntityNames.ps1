<#
.SYNOPSIS
Shared entity set name (pluralization) logic for Dataverse Web API.

.DESCRIPTION
Converts Dataverse table logical names to their OData entity set names.
The Web API requires pluralized names (e.g., "account" -> "accounts").

Dot-source this file when you need entity set name resolution:
    $sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
    . "$sharedDir\Dataverse-EntityNames.ps1"
#>

function Get-EntitySetName {
    <#
    .SYNOPSIS
    Converts a table logical name to its entity set name (pluralized form).

    .DESCRIPTION
    Applies English pluralization rules used by the Dataverse Web API:
    - Words ending in s, x, z, ch, sh -> add "es"
    - Words ending in y (not preceded by a vowel in standard English) -> replace with "ies"
    - Words ending in settings, series, species -> unchanged (already plural)
    - Everything else -> add "s"

    .PARAMETER TableName
    The logical name of the table (e.g., "account", "msdyn_workorder")

    .OUTPUTS
    The pluralized entity set name for use in Web API calls.

    .EXAMPLE
    Get-EntitySetName -TableName "account"        # returns "accounts"
    Get-EntitySetName -TableName "opportunity"     # returns "opportunities"
    Get-EntitySetName -TableName "msdyn_address"   # returns "msdyn_addresses"
    Get-EntitySetName -TableName "settings"        # returns "settings"
    #>
    param([Parameter(Mandatory)][string]$TableName)

    $entitySet = $TableName

    if ($entitySet -match '(settings|series|species)$') {
        # Already plural — no change
    }
    elseif ($entitySet -match 'y$') {
        $entitySet = $entitySet -replace 'y$', 'ies'
    }
    elseif ($entitySet -match '(s|x|z|ch|sh)$') {
        $entitySet = "${entitySet}es"
    }
    else {
        $entitySet = "${entitySet}s"
    }

    return $entitySet
}
