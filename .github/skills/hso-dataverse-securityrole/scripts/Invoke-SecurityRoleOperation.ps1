<#
.SYNOPSIS
    Performs Dataverse security role operations using the Web API.

.DESCRIPTION
    This script creates and manages Dataverse security roles and privilege assignments:
    - CreateRole: Create a new security role
    - RetrieveRole: Get a role by name with its privileges
    - AddPrivileges: Add privileges to a role
    - ReplacePrivileges: Replace all privileges on a role
    - RemovePrivilege: Remove a privilege from a role
    - LookupPrivileges: Query available privileges by table or name
    - DeleteRole: Delete a security role

.PARAMETER Operation
    The operation to perform.

.PARAMETER EnvironmentUrl
    The Dataverse environment URL (e.g., https://myorg.crm.dynamics.com)

.EXAMPLE
    .\Invoke-SecurityRoleOperation.ps1 -Operation CreateRole `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -RoleName "My Custom Role"

.EXAMPLE
    .\Invoke-SecurityRoleOperation.ps1 -Operation AddPrivileges `
        -EnvironmentUrl "https://myorg.crm.dynamics.com" `
        -RoleName "My Custom Role" `
        -PrivilegesJson '[{"name":"prvReadAccount","depth":"Global"}]'

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module (installed automatically if missing)
    Author: Ivan Kurtev
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("CreateRole", "RetrieveRole", "AddPrivileges", "ReplacePrivileges", "RemovePrivilege", "LookupPrivileges", "DeleteRole")]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentUrl,


    # Role parameters
    [string]$RoleName,
    [string]$RoleDescription,
    [string]$RoleId,

    # Solution association
    [string]$SolutionName,

    # Privilege parameters
    [string]$PrivilegesJson,    # JSON array: [{"name":"prvReadAccount","depth":"Global"}, ...]
    [string]$PrivilegeName,     # Single privilege name (for RemovePrivilege or LookupPrivileges)
    [string]$TableName          # Table name for LookupPrivileges
)

#region Validation


#endregion

#region Shared Module Imports
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"
#endregion

#region Helper Functions

function Get-RootBusinessUnitId {
    <#
    .SYNOPSIS
        Retrieves the root business unit ID for the organization.
    #>
    Write-Host "  Retrieving root business unit..." -ForegroundColor Gray
    $result = Invoke-DataverseApi -Method "GET" `
        -Endpoint "businessunits?`$filter=parentbusinessunitid eq null&`$select=businessunitid,name&`$top=1"
    if ($result.value -and $result.value.Count -gt 0) {
        return $result.value[0].businessunitid
    }
    throw "Could not retrieve root business unit."
}

function Find-RoleByName {
    <#
    .SYNOPSIS
        Finds a security role by name, resolving to the ROOT role in a multi-BU environment.
    .DESCRIPTION
        In a multi-business-unit org the platform replicates every role into each BU: a
        `name eq '<x>'` query returns N copies (one per BU) and grabbing [0] can land on a
        BU-child copy instead of the editable root template. The root role is the one whose
        `_parentroleid_value` is null (BU copies carry a parentroleid pointing back at it);
        privilege edits belong on the root and cascade to the copies. We therefore filter on
        `parentroleid eq null` first. If no root match exists (the role lives only in a child
        BU), we fall back to a name-only lookup and warn — three engagement scripts hand-rolled
        this resolution before it lived here.
    #>
    param([Parameter(Mandatory)][string]$Name)

    $select = "roleid,name,description,_businessunitid_value,_parentroleid_value"
    $rootFilter = "name eq '$Name' and parentroleid eq null"
    $result = Invoke-DataverseApi -Method "GET" `
        -Endpoint "roles?`$filter=$rootFilter&`$select=$select"
    if ($result.value -and $result.value.Count -gt 0) {
        return $result.value[0]
    }

    # Fallback: no root-BU copy — resolve by name only (single-BU orgs, or a role that exists only in a child BU).
    $result = Invoke-DataverseApi -Method "GET" `
        -Endpoint "roles?`$filter=name eq '$Name'&`$select=$select"
    if ($result.value -and $result.value.Count -gt 0) {
        if ($result.value.Count -gt 1) {
            Write-Host "  [WARN] '$Name' matched $($result.value.Count) roles but none is a root role (parentroleid null); using the first. Verify you are editing the intended business unit's copy." -ForegroundColor Yellow
        }
        return $result.value[0]
    }
    return $null
}

function Resolve-RoleId {
    <#
    .SYNOPSIS
        Resolves a role ID from either RoleId parameter or by looking up RoleName.
    #>
    if ($script:RoleId) {
        return $script:RoleId
    }
    if (-not $script:RoleName) {
        throw "Either -RoleName or -RoleId must be provided."
    }
    $role = Find-RoleByName -Name $script:RoleName
    if (-not $role) {
        throw "Security role '$($script:RoleName)' not found."
    }
    return $role.roleid
}

function Resolve-PrivilegeIds {
    <#
    .SYNOPSIS
        Takes a JSON array of {name, depth} and resolves each privilege name to its ID.
        Returns an array of RolePrivilege ComplexType objects ready for the Web API.
    #>
    param(
        [Parameter(Mandatory)][string]$Json,
        [Parameter(Mandatory)][string]$BusinessUnitId
    )

    $privileges = $Json | ConvertFrom-Json

    $resolvedPrivileges = @()
    foreach ($priv in $privileges) {
        $privName = $priv.name
        $privDepth = $priv.depth

        # Validate depth
        if ($privDepth -notin @("Basic", "Local", "Deep", "Global")) {
            throw "Invalid depth '$privDepth' for privilege '$privName'. Must be: Basic, Local, Deep, Global"
        }

        # Look up privilege ID
        Write-Host "  Resolving privilege: $privName..." -ForegroundColor Gray
        $result = Invoke-DataverseApi -Method "GET" `
            -Endpoint "privileges?`$filter=name eq '$privName'&`$select=privilegeid,name"
        if (-not $result.value -or $result.value.Count -eq 0) {
            throw "Privilege '$privName' not found in Dataverse."
        }

        $resolvedPrivileges += @{
            "Depth"          = $privDepth
            "PrivilegeId"    = $result.value[0].privilegeid
            "BusinessUnitId" = $BusinessUnitId
            "PrivilegeName"  = $privName
        }
    }

    return $resolvedPrivileges
}

#endregion

#region Main Execution

# Authenticate
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Security Role Operation: $Operation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

switch ($Operation) {

    "CreateRole" {
        if (-not $RoleName) { throw "CreateRole requires -RoleName" }

        Write-Host "  Creating security role: $RoleName" -ForegroundColor White

        # Check if role already exists
        $existing = Find-RoleByName -Name $RoleName
        if ($existing) {
            Write-Host ""
            Write-Host "  [EXISTS] Security role '$RoleName' already exists (ID: $($existing.roleid))" -ForegroundColor Yellow
            Write-Host ""
            exit 0
        }

        # Get root business unit
        $buId = Get-RootBusinessUnitId

        # Build request body
        $body = @{
            "name"                       = $RoleName
            "businessunitid@odata.bind"  = "businessunits($buId)"
        }
        if ($RoleDescription) {
            $body["description"] = $RoleDescription
        }

        # Build headers
        $headers = Get-DataverseHeaders -Token $token -ReturnRepresentation $true
        if ($SolutionName) {
            $headers['MSCRM.SolutionUniqueName'] = $SolutionName
        }

        $result = Invoke-DataverseApi -Method "POST" -Endpoint "roles" `
            -Body $body -Headers $headers -ReturnRepresentation $true

        Write-Host ""
        Write-Host "  [OK] Security role created successfully" -ForegroundColor Green
        Write-Host "  Name: $RoleName" -ForegroundColor White
        Write-Host "  Role ID: $($result.roleid)" -ForegroundColor White
        if ($SolutionName) {
            Write-Host "  Solution: $SolutionName" -ForegroundColor White
        }
        Write-Host ""
    }

    "RetrieveRole" {
        if (-not $RoleName -and -not $RoleId) { throw "RetrieveRole requires -RoleName or -RoleId" }

        if ($RoleId) {
            Write-Host "  Retrieving role by ID: $RoleId" -ForegroundColor White
            $result = Invoke-DataverseApi -Method "GET" `
                -Endpoint "roles($RoleId)?`$select=roleid,name,description&`$expand=roleprivileges_association(`$select=name,privilegeid)" `
                -IncludeAnnotations $true
        }
        else {
            Write-Host "  Retrieving role: $RoleName" -ForegroundColor White
            $role = Find-RoleByName -Name $RoleName
            if (-not $role) {
                Write-Host ""
                Write-Host "  [NOT FOUND] Security role '$RoleName' not found" -ForegroundColor Red
                Write-Host ""
                exit 1
            }

            $result = Invoke-DataverseApi -Method "GET" `
                -Endpoint "roles($($role.roleid))?`$select=roleid,name,description&`$expand=roleprivileges_association(`$select=name,privilegeid)" `
                -IncludeAnnotations $true
        }

        Write-Host ""
        Write-Host "  [OK] Security Role Details" -ForegroundColor Green
        Write-Host "  Name: $($result.name)" -ForegroundColor White
        Write-Host "  Role ID: $($result.roleid)" -ForegroundColor White
        if ($result.description) {
            Write-Host "  Description: $($result.description)" -ForegroundColor White
        }

        $privs = $result.roleprivileges_association
        Write-Host ""
        Write-Host "  Assigned Privileges ($($privs.Count)):" -ForegroundColor Cyan

        if ($privs.Count -gt 0) {
            # Group by action prefix for readability
            $grouped = $privs | Sort-Object name | Group-Object { ($_.name -replace '^(prv[A-Z][a-z]+(?:To)?).*', '$1') }
            foreach ($group in $grouped | Sort-Object Name) {
                Write-Host "    $($group.Name): $($group.Count) privileges" -ForegroundColor Gray
                foreach ($p in $group.Group | Sort-Object name) {
                    Write-Host "      $($p.name)  ($($p.privilegeid))" -ForegroundColor White
                }
            }
        }
        else {
            Write-Host "    (no privileges assigned)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    "AddPrivileges" {
        if (-not $PrivilegesJson) { throw "AddPrivileges requires -PrivilegesJson" }

        $roleId = Resolve-RoleId
        $buId = Get-RootBusinessUnitId
        $resolvedPrivileges = Resolve-PrivilegeIds -Json $PrivilegesJson -BusinessUnitId $buId

        Write-Host "  Adding $($resolvedPrivileges.Count) privilege(s) to role..." -ForegroundColor White

        $body = @{
            "Privileges" = @($resolvedPrivileges)
        }

        Invoke-DataverseApi -Method "POST" `
            -Endpoint "roles($roleId)/Microsoft.Dynamics.CRM.AddPrivilegesRole" `
            -Body $body | Out-Null

        Write-Host ""
        Write-Host "  [OK] Privileges added successfully" -ForegroundColor Green
        foreach ($p in $resolvedPrivileges) {
            Write-Host "    + $($p.PrivilegeName) ($($p.Depth))" -ForegroundColor White
        }
        Write-Host ""
    }

    "ReplacePrivileges" {
        if (-not $PrivilegesJson) { throw "ReplacePrivileges requires -PrivilegesJson" }

        $roleId = Resolve-RoleId
        $buId = Get-RootBusinessUnitId
        $resolvedPrivileges = Resolve-PrivilegeIds -Json $PrivilegesJson -BusinessUnitId $buId

        Write-Host "  Replacing ALL privileges on role with $($resolvedPrivileges.Count) privilege(s)..." -ForegroundColor Yellow

        $body = @{
            "Privileges" = @($resolvedPrivileges)
        }

        Invoke-DataverseApi -Method "POST" `
            -Endpoint "roles($roleId)/Microsoft.Dynamics.CRM.ReplacePrivilegesRole" `
            -Body $body | Out-Null

        Write-Host ""
        Write-Host "  [OK] Privileges replaced successfully" -ForegroundColor Green
        foreach ($p in $resolvedPrivileges) {
            Write-Host "    = $($p.PrivilegeName) ($($p.Depth))" -ForegroundColor White
        }
        Write-Host ""
    }

    "RemovePrivilege" {
        if (-not $PrivilegeName) { throw "RemovePrivilege requires -PrivilegeName" }

        $roleId = Resolve-RoleId

        # Look up privilege ID
        Write-Host "  Looking up privilege: $PrivilegeName" -ForegroundColor Gray
        $result = Invoke-DataverseApi -Method "GET" `
            -Endpoint "privileges?`$filter=name eq '$PrivilegeName'&`$select=privilegeid,name"
        if (-not $result.value -or $result.value.Count -eq 0) {
            throw "Privilege '$PrivilegeName' not found."
        }
        $privilegeId = $result.value[0].privilegeid

        Write-Host "  Removing privilege '$PrivilegeName' from role..." -ForegroundColor White

        $body = @{
            "PrivilegeId" = $privilegeId
        }

        Invoke-DataverseApi -Method "POST" `
            -Endpoint "roles($roleId)/Microsoft.Dynamics.CRM.RemovePrivilegeRole" `
            -Body $body | Out-Null

        Write-Host ""
        Write-Host "  [OK] Privilege '$PrivilegeName' removed successfully" -ForegroundColor Green
        Write-Host ""
    }

    "LookupPrivileges" {
        if (-not $TableName -and -not $PrivilegeName) {
            throw "LookupPrivileges requires -TableName or -PrivilegeName"
        }

        if ($TableName) {
            Write-Host "  Looking up privileges for table: $TableName" -ForegroundColor White
            # Standard CRUD privilege names for a table
            $actions = @("Create", "Read", "Write", "Delete", "Append", "AppendTo", "Assign", "Share")
            $filterParts = @()
            foreach ($action in $actions) {
                $filterParts += "name eq 'prv$action$TableName'"
            }
            $filter = $filterParts -join " or "
            $result = Invoke-DataverseApi -Method "GET" `
                -Endpoint "privileges?`$filter=$filter&`$select=privilegeid,name,accessright&`$orderby=name"
        }
        else {
            Write-Host "  Looking up privileges matching: $PrivilegeName" -ForegroundColor White
            $result = Invoke-DataverseApi -Method "GET" `
                -Endpoint "privileges?`$filter=contains(name,'$PrivilegeName')&`$select=privilegeid,name,accessright&`$orderby=name&`$top=50"
        }

        Write-Host ""
        if ($result.value -and $result.value.Count -gt 0) {
            Write-Host "  [OK] Found $($result.value.Count) privilege(s):" -ForegroundColor Green
            Write-Host ""
            Write-Host "  $("Name".PadRight(55)) Privilege ID" -ForegroundColor Cyan
            Write-Host "  $("-" * 55) $("-" * 36)" -ForegroundColor Gray
            foreach ($p in $result.value) {
                Write-Host "  $($p.name.PadRight(55)) $($p.privilegeid)" -ForegroundColor White
            }
        }
        else {
            Write-Host "  [NOT FOUND] No privileges found matching the criteria" -ForegroundColor Yellow
            if ($TableName) {
                Write-Host "  Hint: Try the table's logical name (e.g., 'account', 'hso_estimate')" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    "DeleteRole" {
        $roleId = Resolve-RoleId

        Write-Host "  Deleting security role (ID: $roleId)..." -ForegroundColor Yellow

        Invoke-DataverseApi -Method "DELETE" -Endpoint "roles($roleId)" | Out-Null

        Write-Host ""
        Write-Host "  [OK] Security role deleted successfully" -ForegroundColor Green
        Write-Host ""
    }
}

#endregion
