<#
.SYNOPSIS
    Performs Dataverse Custom API operations using the Web API.

.DESCRIPTION
    This script creates and manages Custom APIs, request parameters, and response properties:
    - CreateCustomAPI: Deep insert - creates API + parameters + properties in one call
    - UpdateCustomAPI: Update mutable fields (displayname, description, isprivate, plugin binding)
    - QueryCustomAPI: Query a Custom API with expanded parameters/properties/plugin type
    - QueryPluginType: Find a plugin type by class name
    - DeleteCustomAPI: Delete a Custom API (cascades to parameters/properties)
    - AddRequestParameter: Add a request parameter to an existing Custom API
    - AddResponseProperty: Add a response property to an existing Custom API
    - DeleteRequestParameter: Remove a request parameter
    - DeleteResponseProperty: Remove a response property

    IMPORTANT: This script modifies your Dataverse environment. It requires
    interactive authentication to ensure you are aware of the changes
    being made to your environment.

.PARAMETER Operation
    The operation to perform.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
    Author: HSO Custom API Skill
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "CreateCustomAPI", "UpdateCustomAPI", "QueryCustomAPI",
        "QueryPluginType", "DeleteCustomAPI",
        "AddRequestParameter", "AddResponseProperty",
        "DeleteRequestParameter", "DeleteResponseProperty"
    )]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    [Parameter(Mandatory = $false)]
    [string]$SolutionName,

    # Custom API fields
    [string]$APIUniqueName,
    [string]$APIDisplayName,
    [string]$APIDescription,
    [int]$BindingType = 0,
    [string]$BoundEntityLogicalName,
    [switch]$IsFunction,
    [switch]$IsPrivate,
    [int]$AllowedCustomProcessingStepType = 0,
    [string]$PluginTypeName,

    # Deep insert: JSON arrays for request parameters and response properties
    # Format: '[{"UniqueName":"Target","DisplayName":"Target","Description":"desc","Type":5,"IsOptional":false,"LogicalEntityName":"account"}]'
    [string]$RequestParametersJson,
    [string]$ResponsePropertiesJson,

    # Individual parameter/property fields (for Add operations)
    [string]$ParamUniqueName,
    [string]$ParamDisplayName,
    [string]$ParamDescription,
    [int]$ParamType = -1,
    [bool]$ParamIsOptional = $false,
    [string]$ParamLogicalEntityName,

    # For delete operations (by GUID)
    [string]$ParameterId,
    [string]$PropertyId
)

#region Validation
#endregion

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\aidevme-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
#endregion

#region Helper Functions
# Invoke-DataverseApi is provided by aidevme-shared-scripts/scripts/Dataverse-WebApi.ps1 (dot-sourced above).
# The former local copy hard-coded Prefer: return=representation on every call; the write
# call sites below pass -ReturnRepresentation $true explicitly to preserve that contract.

# Type code lookup
$script:TypeCodeNames = @{
    0  = "Boolean"
    1  = "DateTime"
    2  = "Decimal"
    3  = "Entity"
    4  = "EntityCollection"
    5  = "EntityReference"
    6  = "Float"
    7  = "Integer"
    8  = "Money"
    9  = "Picklist"
    10 = "String"
    11 = "StringArray"
    12 = "Guid"
}

$script:BindingTypeNames = @{
    0 = "Global"
    1 = "Entity"
    2 = "EntityCollection"
}

$script:ProcessingStepTypeNames = @{
    0 = "None"
    1 = "Async Only"
    2 = "Sync and Async"
}
#endregion

#region Operation Functions

function Find-PluginType {
    param([string]$PluginTypeName)
    Write-Host "`nSearching for plugin type: $PluginTypeName" -ForegroundColor Cyan

    # Try exact match on typename first
    $encoded = [System.Uri]::EscapeDataString($PluginTypeName)
    $endpoint = "plugintypes?`$filter=typename eq '$encoded'&`$select=plugintypeid,typename,name,assemblyname,version"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if ($response.value -and $response.value.Count -gt 0) {
        $pt = $response.value[0]
        Write-Host "[OK] Found plugin type:" -ForegroundColor Green
        Write-Host "  TypeName:   $($pt.typename)" -ForegroundColor White
        Write-Host "  Name:       $($pt.name)" -ForegroundColor Gray
        Write-Host "  Assembly:   $($pt.assemblyname)" -ForegroundColor Gray
        Write-Host "  Version:    $($pt.version)" -ForegroundColor Gray
        Write-Host "  ID:         $($pt.plugintypeid)" -ForegroundColor Gray
        return $pt
    }

    # Fallback: search by name contains
    Write-Host "  No exact typename match, searching by name..." -ForegroundColor Yellow
    $endpoint = "plugintypes?`$filter=contains(name,'$encoded')&`$select=plugintypeid,typename,name,assemblyname,version&`$top=10"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if ($response.value -and $response.value.Count -gt 0) {
        Write-Host "  Found $($response.value.Count) match(es):" -ForegroundColor Green
        foreach ($pt in $response.value) {
            Write-Host "  - $($pt.typename) [$($pt.assemblyname) v$($pt.version)]" -ForegroundColor White
            Write-Host "    ID: $($pt.plugintypeid)" -ForegroundColor Gray
        }
        # Return the first match
        return $response.value[0]
    }

    Write-Host "[ERROR] Plugin type '$PluginTypeName' not found. Deploy the plugin assembly first." -ForegroundColor Red
    return $null
}

function Get-CustomAPI {
    param([string]$UniqueName)
    Write-Host "`nQuerying Custom API: $UniqueName" -ForegroundColor Cyan

    $encoded = [System.Uri]::EscapeDataString($UniqueName)
    $endpoint = "customapis?`$filter=uniquename eq '$encoded'" +
        "&`$select=customapiid,uniquename,name,displayname,description,bindingtype,boundentitylogicalname,isfunction,isprivate,allowedcustomprocessingsteptype" +
        "&`$expand=CustomAPIRequestParameters(`$select=customapirequestparameterid,uniquename,name,displayname,description,type,isoptional,logicalentityname)" +
        ",CustomAPIResponseProperties(`$select=customapiresponsepropertyid,uniquename,name,displayname,description,type,logicalentityname)" +
        ",PluginTypeId(`$select=plugintypeid,typename,name,assemblyname)"

    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if (-not $response.value -or $response.value.Count -eq 0) {
        Write-Host "  Custom API '$UniqueName' not found" -ForegroundColor Yellow
        return $null
    }

    $api = $response.value[0]
    $bindingName = if ($script:BindingTypeNames.ContainsKey([int]$api.bindingtype)) { $script:BindingTypeNames[[int]$api.bindingtype] } else { "Unknown" }
    $procName = if ($script:ProcessingStepTypeNames.ContainsKey([int]$api.allowedcustomprocessingsteptype)) { $script:ProcessingStepTypeNames[[int]$api.allowedcustomprocessingsteptype] } else { "Unknown" }

    Write-Host ""
    Write-Host "  Custom API: $($api.uniquename)" -ForegroundColor White
    Write-Host "  Display Name:    $($api.displayname)" -ForegroundColor Gray
    Write-Host "  Description:     $($api.description)" -ForegroundColor Gray
    Write-Host "  Binding Type:    $bindingName ($($api.bindingtype))" -ForegroundColor Gray
    if ($api.boundentitylogicalname) {
        Write-Host "  Bound Entity:    $($api.boundentitylogicalname)" -ForegroundColor Gray
    }
    Write-Host "  Is Function:     $($api.isfunction)" -ForegroundColor Gray
    Write-Host "  Is Private:      $($api.isprivate)" -ForegroundColor Gray
    Write-Host "  Processing Type: $procName ($($api.allowedcustomprocessingsteptype))" -ForegroundColor Gray
    Write-Host "  ID:              $($api.customapiid)" -ForegroundColor Gray

    # Plugin type
    if ($api.PluginTypeId) {
        Write-Host ""
        Write-Host "  Plugin Type:" -ForegroundColor Cyan
        Write-Host "    TypeName:  $($api.PluginTypeId.typename)" -ForegroundColor Gray
        Write-Host "    Assembly:  $($api.PluginTypeId.assemblyname)" -ForegroundColor Gray
        Write-Host "    ID:        $($api.PluginTypeId.plugintypeid)" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "  Plugin Type:     (none)" -ForegroundColor Yellow
    }

    # Request parameters
    $reqParams = $api.CustomAPIRequestParameters
    if ($reqParams -and $reqParams.Count -gt 0) {
        Write-Host ""
        Write-Host "  Request Parameters ($($reqParams.Count)):" -ForegroundColor Cyan
        foreach ($p in $reqParams) {
            $typeName = if ($script:TypeCodeNames.ContainsKey([int]$p.type)) { $script:TypeCodeNames[[int]$p.type] } else { "Unknown($($p.type))" }
            $optional = if ($p.isoptional) { "optional" } else { "required" }
            $entity = if ($p.logicalentityname) { " -> $($p.logicalentityname)" } else { "" }
            Write-Host "    - $($p.uniquename) ($typeName, $optional)$entity" -ForegroundColor White
            Write-Host "      ID: $($p.customapirequestparameterid)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host ""
        Write-Host "  Request Parameters: (none)" -ForegroundColor Gray
    }

    # Response properties
    $respProps = $api.CustomAPIResponseProperties
    if ($respProps -and $respProps.Count -gt 0) {
        Write-Host ""
        Write-Host "  Response Properties ($($respProps.Count)):" -ForegroundColor Cyan
        foreach ($p in $respProps) {
            $typeName = if ($script:TypeCodeNames.ContainsKey([int]$p.type)) { $script:TypeCodeNames[[int]$p.type] } else { "Unknown($($p.type))" }
            $entity = if ($p.logicalentityname) { " -> $($p.logicalentityname)" } else { "" }
            Write-Host "    - $($p.uniquename) ($typeName)$entity" -ForegroundColor White
            Write-Host "      ID: $($p.customapiresponsepropertyid)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host ""
        Write-Host "  Response Properties: (none)" -ForegroundColor Gray
    }

    return $api
}

function New-CustomAPI {
    param(
        [string]$APIUniqueName,
        [string]$APIDisplayName,
        [string]$APIDescription,
        [int]$BindingType,
        [string]$BoundEntityLogicalName,
        [bool]$IsFunction,
        [bool]$IsPrivate,
        [int]$AllowedCustomProcessingStepType,
        [string]$PluginTypeName,
        [string]$RequestParametersJson,
        [string]$ResponsePropertiesJson,
        [string]$SolutionName
    )
    Write-Host "`nCreating Custom API: $APIUniqueName" -ForegroundColor Cyan

    # Build the payload
    $payload = [ordered]@{
        "uniquename"                       = $APIUniqueName
        "name"                             = $APIUniqueName
        "displayname"                      = if ($APIDisplayName) { $APIDisplayName } else { $APIUniqueName }
        "description"                      = if ($APIDescription) { $APIDescription } else { "" }
        "bindingtype"                      = $BindingType
        "isfunction"                       = $IsFunction
        "isprivate"                        = $IsPrivate
        "allowedcustomprocessingsteptype"   = $AllowedCustomProcessingStepType
    }

    if ($BoundEntityLogicalName -and $BindingType -ne 0) {
        $payload["boundentitylogicalname"] = $BoundEntityLogicalName
    }

    # Resolve plugin type
    if ($PluginTypeName) {
        $pluginType = Find-PluginType -PluginTypeName $PluginTypeName
        if (-not $pluginType) {
            throw "Cannot create Custom API: plugin type '$PluginTypeName' not found. Deploy plugin assembly first."
        }
        $payload["PluginTypeId@odata.bind"] = "plugintypes($($pluginType.plugintypeid))"
        Write-Host "  Linking to plugin: $($pluginType.typename)" -ForegroundColor Gray
    }

    # Parse and add request parameters (deep insert)
    if ($RequestParametersJson) {
        $reqParams = $RequestParametersJson | ConvertFrom-Json
        $paramArray = @()
        foreach ($p in $reqParams) {
            $paramObj = [ordered]@{
                "uniquename"  = $p.UniqueName
                "name"        = "$APIUniqueName.$($p.UniqueName)"
                "displayname" = if ($p.DisplayName) { $p.DisplayName } else { $p.UniqueName }
                "description" = if ($p.Description) { $p.Description } else { "" }
                "type"        = [int]$p.Type
                "isoptional"  = [bool]$p.IsOptional
            }
            if ($p.LogicalEntityName) {
                $paramObj["logicalentityname"] = $p.LogicalEntityName
            }
            $paramArray += $paramObj
        }
        $payload["CustomAPIRequestParameters"] = $paramArray
        Write-Host "  Including $($paramArray.Count) request parameter(s)" -ForegroundColor Gray
    }

    # Parse and add response properties (deep insert)
    if ($ResponsePropertiesJson) {
        $respProps = $ResponsePropertiesJson | ConvertFrom-Json
        $propArray = @()
        foreach ($p in $respProps) {
            $propObj = [ordered]@{
                "uniquename"  = $p.UniqueName
                "name"        = "$APIUniqueName.$($p.UniqueName)"
                "displayname" = if ($p.DisplayName) { $p.DisplayName } else { $p.UniqueName }
                "description" = if ($p.Description) { $p.Description } else { "" }
                "type"        = [int]$p.Type
            }
            if ($p.LogicalEntityName) {
                $propObj["logicalentityname"] = $p.LogicalEntityName
            }
            $propArray += $propObj
        }
        $payload["CustomAPIResponseProperties"] = $propArray
        Write-Host "  Including $($propArray.Count) response property(ies)" -ForegroundColor Gray
    }

    # Create via deep insert
    Write-Host "  Sending deep insert request..." -ForegroundColor Gray
    $result = Invoke-DataverseApi -Method "POST" -Endpoint "customapis" -Body $payload -SolutionName $SolutionName -ReturnRepresentation $true

    $apiId = $result.customapiid
    Write-Host ""
    Write-Host "[OK] Custom API created successfully" -ForegroundColor Green
    Write-Host "  ID: $apiId" -ForegroundColor Gray
    Write-Host "  Unique Name: $APIUniqueName" -ForegroundColor Gray

    # Verify
    Write-Host ""
    Write-Host "Verifying..." -ForegroundColor Cyan
    Get-CustomAPI -UniqueName $APIUniqueName | Out-Null

    return $apiId
}

function Update-CustomAPI {
    param(
        [string]$APIUniqueName,
        [string]$APIDisplayName,
        [string]$APIDescription,
        [string]$IsPrivate,
        [string]$PluginTypeName,
        [string]$SolutionName
    )
    Write-Host "`nUpdating Custom API: $APIUniqueName" -ForegroundColor Cyan

    # Find existing API
    $encoded = [System.Uri]::EscapeDataString($APIUniqueName)
    $endpoint = "customapis?`$filter=uniquename eq '$encoded'&`$select=customapiid,uniquename,displayname,description,isprivate"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if (-not $response.value -or $response.value.Count -eq 0) {
        throw "Custom API '$APIUniqueName' not found"
    }

    $apiId = $response.value[0].customapiid
    $updatePayload = @{}
    $changes = @()

    if ($APIDisplayName) {
        $updatePayload["displayname"] = $APIDisplayName
        $changes += "displayname -> '$APIDisplayName'"
    }
    if ($APIDescription) {
        $updatePayload["description"] = $APIDescription
        $changes += "description -> '$APIDescription'"
    }
    if ($IsPrivate -ne $null -and $IsPrivate -ne "") {
        $boolVal = [System.Convert]::ToBoolean($IsPrivate)
        $updatePayload["isprivate"] = $boolVal
        $changes += "isprivate -> $boolVal"
    }

    # Re-link plugin type
    if ($PluginTypeName) {
        $pluginType = Find-PluginType -PluginTypeName $PluginTypeName
        if (-not $pluginType) {
            throw "Cannot update Custom API: plugin type '$PluginTypeName' not found"
        }
        $updatePayload["PluginTypeId@odata.bind"] = "plugintypes($($pluginType.plugintypeid))"
        $changes += "plugintype -> '$($pluginType.typename)'"
    }

    if ($updatePayload.Count -eq 0) {
        Write-Host "  No changes specified" -ForegroundColor Yellow
        return
    }

    Write-Host "  Changes:" -ForegroundColor Gray
    foreach ($c in $changes) { Write-Host "    - $c" -ForegroundColor Gray }

    Invoke-DataverseApi -Method "PATCH" -Endpoint "customapis($apiId)" -Body $updatePayload -SolutionName $SolutionName -ReturnRepresentation $true
    Write-Host "[OK] Custom API updated successfully" -ForegroundColor Green
}

function Remove-CustomAPI {
    param([string]$APIUniqueName)
    Write-Host "`nDeleting Custom API: $APIUniqueName" -ForegroundColor Cyan

    # Find existing API
    $encoded = [System.Uri]::EscapeDataString($APIUniqueName)
    $endpoint = "customapis?`$filter=uniquename eq '$encoded'&`$select=customapiid"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if (-not $response.value -or $response.value.Count -eq 0) {
        throw "Custom API '$APIUniqueName' not found"
    }

    $apiId = $response.value[0].customapiid
    Write-Host "  Found API with ID: $apiId" -ForegroundColor Gray
    Write-Host "  Deleting (cascades to parameters and properties)..." -ForegroundColor Gray

    Invoke-DataverseApi -Method "DELETE" -Endpoint "customapis($apiId)"
    Write-Host "[OK] Custom API '$APIUniqueName' deleted successfully" -ForegroundColor Green
}

function Add-RequestParameter {
    param(
        [string]$APIUniqueName,
        [string]$ParamUniqueName,
        [string]$ParamDisplayName,
        [string]$ParamDescription,
        [int]$ParamType,
        [bool]$ParamIsOptional,
        [string]$ParamLogicalEntityName,
        [string]$SolutionName
    )
    Write-Host "`nAdding request parameter '$ParamUniqueName' to Custom API '$APIUniqueName'" -ForegroundColor Cyan

    # Find the Custom API
    $encoded = [System.Uri]::EscapeDataString($APIUniqueName)
    $endpoint = "customapis?`$filter=uniquename eq '$encoded'&`$select=customapiid"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if (-not $response.value -or $response.value.Count -eq 0) {
        throw "Custom API '$APIUniqueName' not found"
    }

    $apiId = $response.value[0].customapiid
    $typeName = if ($script:TypeCodeNames.ContainsKey($ParamType)) { $script:TypeCodeNames[$ParamType] } else { "Unknown" }

    $payload = [ordered]@{
        "uniquename"                  = $ParamUniqueName
        "name"                        = "$APIUniqueName.$ParamUniqueName"
        "displayname"                 = if ($ParamDisplayName) { $ParamDisplayName } else { $ParamUniqueName }
        "description"                 = if ($ParamDescription) { $ParamDescription } else { "" }
        "type"                        = $ParamType
        "isoptional"                  = $ParamIsOptional
        "CustomAPIId@odata.bind"      = "customapis($apiId)"
    }
    if ($ParamLogicalEntityName) {
        $payload["logicalentityname"] = $ParamLogicalEntityName
    }

    $result = Invoke-DataverseApi -Method "POST" -Endpoint "customapirequestparameters" -Body $payload -SolutionName $SolutionName -ReturnRepresentation $true
    Write-Host "[OK] Request parameter '$ParamUniqueName' ($typeName) added successfully" -ForegroundColor Green
    Write-Host "  ID: $($result.customapirequestparameterid)" -ForegroundColor Gray
}

function Add-ResponseProperty {
    param(
        [string]$APIUniqueName,
        [string]$ParamUniqueName,
        [string]$ParamDisplayName,
        [string]$ParamDescription,
        [int]$ParamType,
        [string]$ParamLogicalEntityName,
        [string]$SolutionName
    )
    Write-Host "`nAdding response property '$ParamUniqueName' to Custom API '$APIUniqueName'" -ForegroundColor Cyan

    # Find the Custom API
    $encoded = [System.Uri]::EscapeDataString($APIUniqueName)
    $endpoint = "customapis?`$filter=uniquename eq '$encoded'&`$select=customapiid"
    $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

    if (-not $response.value -or $response.value.Count -eq 0) {
        throw "Custom API '$APIUniqueName' not found"
    }

    $apiId = $response.value[0].customapiid
    $typeName = if ($script:TypeCodeNames.ContainsKey($ParamType)) { $script:TypeCodeNames[$ParamType] } else { "Unknown" }

    $payload = [ordered]@{
        "uniquename"                  = $ParamUniqueName
        "name"                        = "$APIUniqueName.$ParamUniqueName"
        "displayname"                 = if ($ParamDisplayName) { $ParamDisplayName } else { $ParamUniqueName }
        "description"                 = if ($ParamDescription) { $ParamDescription } else { "" }
        "type"                        = $ParamType
        "CustomAPIId@odata.bind"      = "customapis($apiId)"
    }
    if ($ParamLogicalEntityName) {
        $payload["logicalentityname"] = $ParamLogicalEntityName
    }

    $result = Invoke-DataverseApi -Method "POST" -Endpoint "customapiresponseproperties" -Body $payload -SolutionName $SolutionName -ReturnRepresentation $true
    Write-Host "[OK] Response property '$ParamUniqueName' ($typeName) added successfully" -ForegroundColor Green
    Write-Host "  ID: $($result.customapiresponsepropertyid)" -ForegroundColor Gray
}

function Remove-RequestParameter {
    param([string]$ParameterId, [string]$APIUniqueName, [string]$ParamUniqueName)
    Write-Host "`nDeleting request parameter..." -ForegroundColor Cyan

    # Resolve by name if no ID provided
    if (-not $ParameterId -and $APIUniqueName -and $ParamUniqueName) {
        $encodedApi = [System.Uri]::EscapeDataString($APIUniqueName)
        $encodedParam = [System.Uri]::EscapeDataString($ParamUniqueName)
        $endpoint = "customapirequestparameters?`$filter=uniquename eq '$encodedParam'" +
            "&`$expand=CustomAPIId(`$filter=uniquename eq '$encodedApi';`$select=uniquename)" +
            "&`$select=customapirequestparameterid,uniquename"
        $response = Invoke-DataverseApi -Method "GET" -Endpoint $endpoint

        # Filter to match the correct API
        $match = $response.value | Where-Object { $_.CustomAPIId -and $_.CustomAPIId.uniquename -eq $APIUniqueName }
        if (-not $match) {
            # Fallback: find API ID first, then query parameters
            $apiEndpoint = "customapis?`$filter=uniquename eq '$encodedApi'&`$select=customapiid"
            $apiResponse = Invoke-DataverseApi -Method "GET" -Endpoint $apiEndpoint
            if (-not $apiResponse.value -or $apiResponse.value.Count -eq 0) {
                throw "Custom API '$APIUniqueName' not found"
            }
            $apiId = $apiResponse.value[0].customapiid
            $paramEndpoint = "customapirequestparameters?`$filter=uniquename eq '$encodedParam' and _customapiid_value eq '$apiId'&`$select=customapirequestparameterid"
            $paramResponse = Invoke-DataverseApi -Method "GET" -Endpoint $paramEndpoint
            if (-not $paramResponse.value -or $paramResponse.value.Count -eq 0) {
                throw "Request parameter '$ParamUniqueName' not found on Custom API '$APIUniqueName'"
            }
            $ParameterId = $paramResponse.value[0].customapirequestparameterid
        } else {
            $ParameterId = $match.customapirequestparameterid
        }
    }

    if (-not $ParameterId) { throw "ParameterId required, or provide APIUniqueName and ParamUniqueName" }

    $cleanId = $ParameterId -replace '[{}]', ''
    Invoke-DataverseApi -Method "DELETE" -Endpoint "customapirequestparameters($cleanId)"
    Write-Host "[OK] Request parameter deleted successfully" -ForegroundColor Green
}

function Remove-ResponseProperty {
    param([string]$PropertyId, [string]$APIUniqueName, [string]$ParamUniqueName)
    Write-Host "`nDeleting response property..." -ForegroundColor Cyan

    # Resolve by name if no ID provided
    if (-not $PropertyId -and $APIUniqueName -and $ParamUniqueName) {
        $encodedApi = [System.Uri]::EscapeDataString($APIUniqueName)
        $encodedParam = [System.Uri]::EscapeDataString($ParamUniqueName)

        $apiEndpoint = "customapis?`$filter=uniquename eq '$encodedApi'&`$select=customapiid"
        $apiResponse = Invoke-DataverseApi -Method "GET" -Endpoint $apiEndpoint
        if (-not $apiResponse.value -or $apiResponse.value.Count -eq 0) {
            throw "Custom API '$APIUniqueName' not found"
        }
        $apiId = $apiResponse.value[0].customapiid
        $propEndpoint = "customapiresponseproperties?`$filter=uniquename eq '$encodedParam' and _customapiid_value eq '$apiId'&`$select=customapiresponsepropertyid"
        $propResponse = Invoke-DataverseApi -Method "GET" -Endpoint $propEndpoint
        if (-not $propResponse.value -or $propResponse.value.Count -eq 0) {
            throw "Response property '$ParamUniqueName' not found on Custom API '$APIUniqueName'"
        }
        $PropertyId = $propResponse.value[0].customapiresponsepropertyid
    }

    if (-not $PropertyId) { throw "PropertyId required, or provide APIUniqueName and ParamUniqueName" }

    $cleanId = $PropertyId -replace '[{}]', ''
    Invoke-DataverseApi -Method "DELETE" -Endpoint "customapiresponseproperties($cleanId)"
    Write-Host "[OK] Response property deleted successfully" -ForegroundColor Green
}

#endregion

#region Main Execution
$envUrl = $EnvironmentUrl.TrimEnd('/')
$token = Get-DataverseToken -EnvironmentUrl $envUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}
$script:AuthToken = $token
$script:EnvironmentUrl = $envUrl

switch ($Operation) {
    "CreateCustomAPI" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        New-CustomAPI -APIUniqueName $APIUniqueName -APIDisplayName $APIDisplayName -APIDescription $APIDescription `
            -BindingType $BindingType -BoundEntityLogicalName $BoundEntityLogicalName `
            -IsFunction $IsFunction.IsPresent -IsPrivate $IsPrivate.IsPresent `
            -AllowedCustomProcessingStepType $AllowedCustomProcessingStepType `
            -PluginTypeName $PluginTypeName `
            -RequestParametersJson $RequestParametersJson -ResponsePropertiesJson $ResponsePropertiesJson `
            -SolutionName $SolutionName
    }
    "UpdateCustomAPI" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        Update-CustomAPI -APIUniqueName $APIUniqueName -APIDisplayName $APIDisplayName -APIDescription $APIDescription `
            -IsPrivate $IsPrivate -PluginTypeName $PluginTypeName -SolutionName $SolutionName
    }
    "QueryCustomAPI" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        Get-CustomAPI -UniqueName $APIUniqueName
    }
    "QueryPluginType" {
        if (-not $PluginTypeName) { throw "PluginTypeName required" }
        Find-PluginType -PluginTypeName $PluginTypeName
    }
    "DeleteCustomAPI" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        Remove-CustomAPI -APIUniqueName $APIUniqueName
    }
    "AddRequestParameter" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        if (-not $ParamUniqueName) { throw "ParamUniqueName required" }
        if ($ParamType -eq -1) { throw "ParamType required (0=Boolean, 5=EntityReference, 7=Integer, 10=String, 12=Guid, etc.)" }
        Add-RequestParameter -APIUniqueName $APIUniqueName -ParamUniqueName $ParamUniqueName `
            -ParamDisplayName $ParamDisplayName -ParamDescription $ParamDescription `
            -ParamType $ParamType -ParamIsOptional $ParamIsOptional `
            -ParamLogicalEntityName $ParamLogicalEntityName -SolutionName $SolutionName
    }
    "AddResponseProperty" {
        if (-not $APIUniqueName) { throw "APIUniqueName required" }
        if (-not $ParamUniqueName) { throw "ParamUniqueName required" }
        if ($ParamType -eq -1) { throw "ParamType required (0=Boolean, 5=EntityReference, 7=Integer, 10=String, 12=Guid, etc.)" }
        Add-ResponseProperty -APIUniqueName $APIUniqueName -ParamUniqueName $ParamUniqueName `
            -ParamDisplayName $ParamDisplayName -ParamDescription $ParamDescription `
            -ParamType $ParamType -ParamLogicalEntityName $ParamLogicalEntityName -SolutionName $SolutionName
    }
    "DeleteRequestParameter" {
        Remove-RequestParameter -ParameterId $ParameterId -APIUniqueName $APIUniqueName -ParamUniqueName $ParamUniqueName
    }
    "DeleteResponseProperty" {
        Remove-ResponseProperty -PropertyId $PropertyId -APIUniqueName $APIUniqueName -ParamUniqueName $ParamUniqueName
    }
    default { throw "Unknown operation: $Operation" }
}

Write-Host "`nOperation completed." -ForegroundColor Cyan
#endregion
