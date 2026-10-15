# lint:raw-invoke-backlog ADR 0014 open backlog - pre-existing drift, NOT an exemption.
# Calls the Dataverse Web API directly instead of the shared Invoke-DataverseApi, so it misses
# the invoker's hardening (notably -UseBasicParsing, without which Windows PowerShell 5.1 dies
# under -NonInteractive on a build agent). Convert per ADR 0014's open-backlog table, then
# DELETE this marker. Reported as WARN on every lint run until then.
<#
.SYNOPSIS
    Deploy Power Automate cloud flows to a Dataverse environment via the Web API.

.DESCRIPTION
    Creates workflow records in Dataverse, adds them to a solution, and optionally
    activates them. Supports querying and creating connection references in solutions.

.PARAMETER Operation
    The operation to perform:
    - DeployFlow: Create a workflow record and add to solution
    - UpdateFlow: Update an existing flow's definition (clientdata) by workflow ID
    - GetFlow: Read a workflow record's state and clientdata (by WorkflowId or FlowName); optionally writes clientdata to disk
    - ActivateFlow: Activate an existing flow by workflow ID
    - DeactivateFlow: Deactivate an existing flow by workflow ID
    - GetConnectionReference: Query connection reference logical names from a solution
    - CreateConnectionReference: Create a new Dataverse connection reference in a solution

.PARAMETER OutputPath
    Optional path to write the deployed clientdata JSON (used by GetFlow). The JSON is
    pretty-printed for diffing against the source-of-truth file on disk.

.PARAMETER ConnectionReferenceLogicalName
    Logical name for the connection reference (required for CreateConnectionReference).

.PARAMETER ConnectionReferenceDisplayName
    Display name for the connection reference (required for CreateConnectionReference).

.PARAMETER ConnectorId
    Connector API path (required for CreateConnectionReference).
    Default: /providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps

.PARAMETER FlowJsonPath
    Path to the flow JSON definition file (required for DeployFlow).

.PARAMETER FlowName
    Display name for the flow (required for DeployFlow).

.PARAMETER FlowDescription
    Optional description for the flow.

.PARAMETER SolutionUniqueName
    Solution unique name to add the flow to (required for DeployFlow).

.PARAMETER WorkflowId
    Workflow ID GUID (required for ActivateFlow/DeactivateFlow).

.PARAMETER EnvironmentUrl
    Dataverse environment URL (e.g., https://org.crm.dynamics.com).

.PARAMETER Activate
    Switch to activate the flow after deployment.

.NOTES
    Requires: PowerShell 5.1+, MSAL.PS module
    Auth: Uses shared Dataverse-Auth.ps1 for MSAL interactive authentication
    Pattern: Consistent with Invoke-DataverseMetadataOperation.ps1 and Invoke-DataverseDataOperation.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("DeployFlow", "UpdateFlow", "GetFlow", "DeleteFlow", "ActivateFlow", "DeactivateFlow", "GetConnectionReference", "CreateConnectionReference")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [string]$FlowJsonPath,

    [Parameter(Mandatory = $false)]
    [string]$FlowName,

    [Parameter(Mandatory = $false)]
    [string]$FlowDescription = "",

    [Parameter(Mandatory = $false)]
    [string]$SolutionUniqueName,

    [Parameter(Mandatory = $false)]
    [string]$WorkflowId,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionReferenceLogicalName,

    [Parameter(Mandatory = $false)]
    [string]$ConnectionReferenceDisplayName,

    [Parameter(Mandatory = $false)]
    [string]$ConnectorId = "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$EnvironmentUrl,

    [switch]$Activate
)

# --- Dot-source shared modules (sibling hso-shared-scripts library skill) ---
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"

# --- Authenticate ---
$baseUrl = $EnvironmentUrl.TrimEnd('/')
$apiUrl = "$baseUrl/api/data/v9.2"

$token = Get-DataverseToken -EnvironmentUrl $baseUrl
if (-not $token) {
    Write-Host "[ERROR] Failed to obtain authentication token." -ForegroundColor Red
    exit 1
}

# --- Definition validation ---

# Web API messages that exist ONLY as unbound functions/actions. Authored as a
# PerformBoundAction step they deploy fine but activation deterministically fails with
# InvalidOpenApiFlow / GetMetadataForBoundActionInput ("Bound action ... is not found in the
# Organization") - proven by Bug #298 (CalculateRollupField, WI-342 run). Extend as found.
$script:UnboundOnlyMessages = @('CalculateRollupField')

function Test-FlowClientData {
    <#
    .SYNOPSIS
        Rejects flow definitions that can never activate, before they are written to Dataverse.
    .DESCRIPTION
        Walks every action (including actions nested in scopes/conditions/loops) and fails on
        PerformBoundAction steps whose actionName is an unbound-only Web API message.
    #>
    param([string]$FlowJsonRaw)

    try { $flow = $FlowJsonRaw | ConvertFrom-Json } catch { return }

    $violations = New-Object System.Collections.Generic.List[string]

    function Walk-Actions {
        param($ActionsNode)
        if (-not $ActionsNode) { return }
        foreach ($prop in $ActionsNode.PSObject.Properties) {
            $action = $prop.Value
            $opId = $action.inputs.host.operationId
            if ($opId -like 'PerformBoundAction*') {
                $actionName = "$($action.inputs.parameters.actionName)"
                $bare = ($actionName -split '\.')[-1]
                if ($script:UnboundOnlyMessages -contains $bare) {
                    $violations.Add("step '$($prop.Name)': '$bare' authored as a bound action")
                }
            }
            # Containers (Scope/If/Foreach/Until/Switch cases) nest their own actions.
            if ($action.PSObject.Properties['actions']) { Walk-Actions -ActionsNode $action.actions }
            if ($action.PSObject.Properties['else'])    { Walk-Actions -ActionsNode $action.else.actions }
            if ($action.PSObject.Properties['cases'])   {
                foreach ($case in $action.cases.PSObject.Properties) { Walk-Actions -ActionsNode $case.Value.actions }
            }
        }
    }
    Walk-Actions -ActionsNode $flow.properties.definition.actions

    if ($violations.Count -gt 0) {
        Write-Host "[ERROR] Flow definition uses unbound-only Web API message(s) as bound-action steps:" -ForegroundColor Red
        $violations | ForEach-Object { Write-Host "        $_" -ForegroundColor Red }
        Write-Host "        These deploy but can NEVER activate (InvalidOpenApiFlow / GetMetadataForBoundActionInput)." -ForegroundColor Red
        Write-Host "        Alternatives: drop the step when a server-side rollup-refresh plugin already covers it," -ForegroundColor Yellow
        Write-Host "        or call the unbound message via the Dataverse connector's HTTP-request pattern." -ForegroundColor Yellow
        Write-Host "        See references/dataverse-connector-reference.md (Unbound-only messages)." -ForegroundColor Yellow
        exit 1
    }
}

# --- Operations ---

switch ($Operation) {

    "DeployFlow" {
        if (-not $FlowJsonPath -or -not $FlowName -or -not $SolutionUniqueName) {
            Write-Error "DeployFlow requires -FlowJsonPath, -FlowName, and -SolutionUniqueName"
            exit 1
        }

        if (-not (Test-Path $FlowJsonPath)) {
            Write-Error "Flow JSON file not found: $FlowJsonPath"
            exit 1
        }

        Write-Host "=== Deploy Power Automate Flow ===" -ForegroundColor Cyan
        Write-Host "Flow Name: $FlowName"
        Write-Host "Solution: $SolutionUniqueName"
        Write-Host "Environment: $baseUrl"
        Write-Host ""

        # Read flow JSON and validate
        $flowJson = Get-Content -Path $FlowJsonPath -Raw -Encoding UTF8
        try {
            $null = $flowJson | ConvertFrom-Json
        } catch {
            Write-Error "Invalid JSON in flow file: $FlowJsonPath"
            exit 1
        }
        Test-FlowClientData -FlowJsonRaw $flowJson

        # Step 1: Create workflow record with return=representation to get the ID back
        Write-Host "Step 1: Creating workflow record..." -ForegroundColor Yellow
        $createHeaders = Get-DataverseHeaders -Token $token -ReturnRepresentation $true

        # Build JSON body manually — ConvertTo-Json cannot handle the nested JSON string
        # in clientdata (it re-parses the string as an object at higher depths, causing hangs)
        $escapedName = $FlowName.Replace('\','\\').Replace('"','\"')
        $escapedClientData = $flowJson.Replace('\','\\').Replace('"','\"').Replace("`r`n",'\n').Replace("`n",'\n').Replace("`r",'\n')
        $escapedDescription = $FlowDescription.Replace('\','\\').Replace('"','\"')

        $bodyJson = "{""category"":5,""type"":1,""name"":""$escapedName"",""primaryentity"":""none"",""clientdata"":""$escapedClientData"""
        if ($FlowDescription) {
            $bodyJson += ",""description"":""$escapedDescription"""
        }
        $bodyJson += "}"
        try {
            $response = Invoke-RestMethod -Uri "$apiUrl/workflows" `
                -Headers $createHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($bodyJson)) `
                -ContentType "application/json; charset=utf-8"

            $workflowIdCreated = $response.workflowid
            if (-not $workflowIdCreated) {
                Write-Host "[ERROR] Workflow created but response did not contain workflowid." -ForegroundColor Red
                exit 1
            }
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to create workflow: $errDetail" -ForegroundColor Red
            exit 1
        }

        Write-Host "  [OK] Workflow created: $workflowIdCreated" -ForegroundColor Green

        # Step 2: Add to solution
        Write-Host "Step 2: Adding to solution '$SolutionUniqueName'..." -ForegroundColor Yellow
        $solutionHeaders = Get-DataverseHeaders -Token $token

        $addComponentBody = @{
            ComponentId               = $workflowIdCreated
            ComponentType             = 29  # Workflow
            SolutionUniqueName        = $SolutionUniqueName
            AddRequiredComponents     = $true
            DoNotIncludeSubcomponents = $false
        } | ConvertTo-Json -Depth 10 -Compress

        try {
            Invoke-RestMethod -Uri "$apiUrl/AddSolutionComponent" `
                -Headers $solutionHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($addComponentBody)) `
                -ContentType "application/json; charset=utf-8"
            Write-Host "  [OK] Added to solution" -ForegroundColor Green
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Warning "Failed to add to solution: $errDetail"
        }

        # Step 3: Activate if requested
        if ($Activate) {
            Write-Host "Step 3: Activating flow..." -ForegroundColor Yellow
            $patchHeaders = Get-DataverseHeaders -Token $token
            $patchHeaders["If-Match"] = "*"

            $activateBody = @{ statecode = 1 } | ConvertTo-Json -Compress
            try {
                Invoke-RestMethod -Uri "$apiUrl/workflows($workflowIdCreated)" `
                    -Headers $patchHeaders -Method Patch `
                    -Body ([System.Text.Encoding]::UTF8.GetBytes($activateBody)) `
                    -ContentType "application/json; charset=utf-8"
                Write-Host "  [OK] Flow activated" -ForegroundColor Green
            } catch {
                $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
                Write-Warning "Failed to activate flow: $errDetail"
            }
        } else {
            Write-Host "Step 3: Flow left in Draft state (use -Activate to auto-enable)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
        Write-Host "Workflow ID: $workflowIdCreated"
        Write-Host "State: $(if ($Activate) { 'Activated' } else { 'Draft' })"

        [PSCustomObject]@{
            Success    = $true
            WorkflowId = $workflowIdCreated
            FlowName   = $FlowName
            Solution   = $SolutionUniqueName
            State      = if ($Activate) { "Activated" } else { "Draft" }
        }
    }

    "UpdateFlow" {
        if (-not $WorkflowId -or -not $FlowJsonPath) {
            Write-Error "UpdateFlow requires -WorkflowId and -FlowJsonPath"
            exit 1
        }

        if (-not (Test-Path $FlowJsonPath)) {
            Write-Host "[ERROR] Flow JSON file not found: $FlowJsonPath" -ForegroundColor Red
            exit 1
        }

        $flowJson = Get-Content $FlowJsonPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($flowJson)) {
            Write-Host "[ERROR] Flow JSON file is empty: $FlowJsonPath" -ForegroundColor Red
            exit 1
        }
        Test-FlowClientData -FlowJsonRaw $flowJson

        Write-Host ""
        Write-Host "=== Update Power Automate Flow ===" -ForegroundColor Cyan
        Write-Host "Workflow ID: $WorkflowId"
        Write-Host "Flow JSON: $FlowJsonPath"
        Write-Host "Environment: $EnvironmentUrl"

        # Escape the flow JSON for embedding as a string value in the PATCH payload
        $escapedClientData = $flowJson.Replace('\','\\').Replace('"','\"').Replace("`r`n",'\n').Replace("`n",'\n').Replace("`r",'\n')

        # Build minimal PATCH body — only update clientdata
        $bodyJson = "{""clientdata"":""$escapedClientData""}"

        $patchHeaders = Get-DataverseHeaders -Token $token
        $patchHeaders["If-Match"] = "*"

        Write-Host "Updating workflow clientdata..." -ForegroundColor Yellow
        try {
            Invoke-RestMethod -Uri "$apiUrl/workflows($WorkflowId)" `
                -Headers $patchHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($bodyJson)) `
                -ContentType "application/json; charset=utf-8"
            Write-Host "  [OK] Flow definition updated" -ForegroundColor Green
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to update flow: $errDetail" -ForegroundColor Red
            exit 1
        }

        Write-Host ""
        Write-Host "=== Update Complete ===" -ForegroundColor Cyan
        Write-Host "Workflow ID: $WorkflowId"
        Write-Host "Note: If the flow was active, you may need to deactivate and reactivate for changes to take effect."

        [PSCustomObject]@{
            Success    = $true
            WorkflowId = $WorkflowId
            Operation  = "UpdateFlow"
        }
    }

    "GetFlow" {
        if (-not $WorkflowId -and -not $FlowName) {
            Write-Error "GetFlow requires either -WorkflowId or -FlowName"
            exit 1
        }

        Write-Host "=== Get Power Automate Flow ===" -ForegroundColor Cyan
        Write-Host "Environment: $baseUrl"

        $queryHeaders = Get-DataverseHeaders -Token $token -IncludeAnnotations $true
        $select = "workflowid,name,statecode,statuscode,category,primaryentity,modifiedon,clientdata,_ownerid_value"

        # Resolve workflow record
        if ($WorkflowId) {
            Write-Host "Workflow ID: $WorkflowId"
            try {
                $record = Invoke-RestMethod -Uri "$apiUrl/workflows($WorkflowId)?`$select=$select" `
                    -Headers $queryHeaders -Method Get
            } catch {
                $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
                Write-Host "[ERROR] Failed to read workflow: $errDetail" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "Flow Name: $FlowName"
            $escapedName = $FlowName.Replace("'","''")
            $filter = "name eq '$escapedName' and category eq 5"
            try {
                $resp = Invoke-RestMethod -Uri "$apiUrl/workflows?`$filter=$filter&`$select=$select" `
                    -Headers $queryHeaders -Method Get
            } catch {
                $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
                Write-Host "[ERROR] Failed to query workflows: $errDetail" -ForegroundColor Red
                exit 1
            }
            if (-not $resp.value -or $resp.value.Count -eq 0) {
                Write-Host "[ERROR] No flow found with name '$FlowName' (category 5 / Modern Flow)." -ForegroundColor Red
                exit 1
            }
            if ($resp.value.Count -gt 1) {
                Write-Host "[WARN] $($resp.value.Count) flows match name '$FlowName'. Returning the most recently modified." -ForegroundColor Yellow
                $record = $resp.value | Sort-Object modifiedon -Descending | Select-Object -First 1
            } else {
                $record = $resp.value[0]
            }
        }

        $stateLabel = switch ($record.statecode) { 0 { "Draft" } 1 { "Activated" } 2 { "Suspended" } default { "Unknown($($record.statecode))" } }

        Write-Host ""
        Write-Host "  Workflow ID:     $($record.workflowid)"
        Write-Host "  Name:            $($record.name)"
        Write-Host "  State:           $stateLabel (statecode=$($record.statecode), statuscode=$($record.statuscode))"
        Write-Host "  Category:        $($record.category)"
        Write-Host "  Primary entity:  $($record.primaryentity)"
        Write-Host "  Modified on:     $($record.modifiedon)"
        if ($record.'_ownerid_value@OData.Community.Display.V1.FormattedValue') {
            Write-Host "  Owner:           $($record.'_ownerid_value@OData.Community.Display.V1.FormattedValue')"
        }

        # Parse clientdata and extract connection references + trigger/action names
        $clientDataObj = $null
        $connectionRefs = @()
        $triggerNames = @()
        $actionNames = @()

        if ($record.clientdata) {
            try {
                $clientDataObj = $record.clientdata | ConvertFrom-Json
                if ($clientDataObj.properties.connectionReferences) {
                    foreach ($prop in $clientDataObj.properties.connectionReferences.PSObject.Properties) {
                        $crEntry = $prop.Value
                        $connectionRefs += [PSCustomObject]@{
                            Key                = $prop.Name
                            LogicalName        = $crEntry.connection.connectionReferenceLogicalName
                            ConnectorApiName   = $crEntry.api.name
                            RuntimeSource      = $crEntry.runtimeSource
                        }
                    }
                }
                if ($clientDataObj.properties.definition.triggers) {
                    $triggerNames = $clientDataObj.properties.definition.triggers.PSObject.Properties.Name
                }
                if ($clientDataObj.properties.definition.actions) {
                    $actionNames = $clientDataObj.properties.definition.actions.PSObject.Properties.Name
                }
            } catch {
                Write-Host "[WARN] Could not parse clientdata as JSON: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        Write-Host ""
        Write-Host "  Triggers:        $($triggerNames -join ', ')"
        Write-Host "  Actions:         $($actionNames -join ', ')"
        Write-Host ""
        if ($connectionRefs.Count -eq 0) {
            Write-Host "  Connection refs: (none)"
        } else {
            Write-Host "  Connection refs:"
            foreach ($cr in $connectionRefs) {
                Write-Host "    - $($cr.Key) -> $($cr.LogicalName) ($($cr.ConnectorApiName), $($cr.RuntimeSource))"
            }
        }

        # Optionally write clientdata to disk for diff
        if ($OutputPath -and $record.clientdata) {
            try {
                # Pretty-print for diffing
                $pretty = $clientDataObj | ConvertTo-Json -Depth 100
                Set-Content -Path $OutputPath -Value $pretty -Encoding UTF8
                Write-Host ""
                Write-Host "  [OK] clientdata written to: $OutputPath" -ForegroundColor Green
            } catch {
                Write-Host "[WARN] Could not write clientdata to '$OutputPath': $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        [PSCustomObject]@{
            Success            = $true
            WorkflowId         = $record.workflowid
            Name               = $record.name
            StateCode          = $record.statecode
            StatusCode         = $record.statuscode
            StateLabel         = $stateLabel
            Category           = $record.category
            PrimaryEntity      = $record.primaryentity
            ModifiedOn         = $record.modifiedon
            Triggers           = $triggerNames
            Actions            = $actionNames
            ConnectionRefs     = $connectionRefs
            ClientData         = $clientDataObj
            ClientDataRaw      = $record.clientdata
        }
    }

    "ActivateFlow" {
        if (-not $WorkflowId) {
            Write-Error "ActivateFlow requires -WorkflowId"
            exit 1
        }

        Write-Host "Activating flow $WorkflowId..." -ForegroundColor Yellow
        $patchHeaders = Get-DataverseHeaders -Token $token
        $patchHeaders["If-Match"] = "*"

        $activateBody = @{ statecode = 1; statuscode = 2 } | ConvertTo-Json -Compress
        try {
            Invoke-RestMethod -Uri "$apiUrl/workflows($WorkflowId)" `
                -Headers $patchHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($activateBody)) `
                -ContentType "application/json; charset=utf-8"
            Write-Host "[OK] Flow activated" -ForegroundColor Green
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to activate: $errDetail" -ForegroundColor Red
            exit 1
        }

        [PSCustomObject]@{ Success = $true; WorkflowId = $WorkflowId; State = "Activated" }
    }

    "DeleteFlow" {
        if (-not $WorkflowId) {
            Write-Error "DeleteFlow requires -WorkflowId"
            exit 1
        }

        Write-Host "Deleting flow $WorkflowId..." -ForegroundColor Yellow
        $deleteHeaders = Get-DataverseHeaders -Token $token
        try {
            Invoke-RestMethod -Uri "$apiUrl/workflows($WorkflowId)" `
                -Headers $deleteHeaders -Method Delete
            Write-Host "[OK] Flow deleted" -ForegroundColor Green
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to delete flow: $errDetail" -ForegroundColor Red
            Write-Host "Note: The flow must be deactivated (statecode=0) before it can be deleted." -ForegroundColor Yellow
            exit 1
        }

        [PSCustomObject]@{ Success = $true; WorkflowId = $WorkflowId; Operation = "DeleteFlow" }
    }

    "DeactivateFlow" {
        if (-not $WorkflowId) {
            Write-Error "DeactivateFlow requires -WorkflowId"
            exit 1
        }

        Write-Host "Deactivating flow $WorkflowId..." -ForegroundColor Yellow
        $patchHeaders = Get-DataverseHeaders -Token $token
        $patchHeaders["If-Match"] = "*"

        $deactivateBody = @{ statecode = 0 } | ConvertTo-Json -Compress
        try {
            Invoke-RestMethod -Uri "$apiUrl/workflows($WorkflowId)" `
                -Headers $patchHeaders -Method Patch `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($deactivateBody)) `
                -ContentType "application/json; charset=utf-8"
            Write-Host "[OK] Flow deactivated" -ForegroundColor Green
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to deactivate: $errDetail" -ForegroundColor Red
            exit 1
        }

        [PSCustomObject]@{ Success = $true; WorkflowId = $WorkflowId; State = "Draft" }
    }

    "GetConnectionReference" {
        if (-not $SolutionUniqueName) {
            Write-Error "GetConnectionReference requires -SolutionUniqueName"
            exit 1
        }

        Write-Host "Querying connection references in solution '$SolutionUniqueName'..." -ForegroundColor Yellow
        $queryHeaders = Get-DataverseHeaders -Token $token -IncludeAnnotations $true

        $fetchXml = @"
<fetch>
  <entity name="connectionreference">
    <attribute name="connectionreferencelogicalname" />
    <attribute name="connectionreferencedisplayname" />
    <attribute name="connectorid" />
    <link-entity name="solutioncomponent" from="objectid" to="connectionreferenceid" link-type="inner">
      <link-entity name="solution" from="solutionid" to="solutionid" link-type="inner">
        <filter>
          <condition attribute="uniquename" operator="eq" value="$SolutionUniqueName" />
        </filter>
      </link-entity>
    </link-entity>
  </entity>
</fetch>
"@
        $encodedFetch = [System.Uri]::EscapeDataString($fetchXml)
        try {
            $response = Invoke-RestMethod -Uri "$apiUrl/connectionreferences?fetchXml=$encodedFetch" `
                -Headers $queryHeaders -Method Get
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Query failed: $errDetail" -ForegroundColor Red
            exit 1
        }

        if ($response.value.Count -eq 0) {
            Write-Host "No connection references found in solution '$SolutionUniqueName'" -ForegroundColor Yellow
        } else {
            Write-Host "Found $($response.value.Count) connection reference(s):" -ForegroundColor Green
            foreach ($cr in $response.value) {
                Write-Host "  - $($cr.connectionreferencelogicalname) ($($cr.connectionreferencedisplayname)) -> $($cr.connectorid)" -ForegroundColor White
            }
        }

        $response.value | ForEach-Object {
            [PSCustomObject]@{
                LogicalName = $_.connectionreferencelogicalname
                DisplayName = $_.connectionreferencedisplayname
                ConnectorId = $_.connectorid
            }
        }
    }

    "CreateConnectionReference" {
        if (-not $ConnectionReferenceLogicalName -or -not $ConnectionReferenceDisplayName -or -not $SolutionUniqueName) {
            Write-Error "CreateConnectionReference requires -ConnectionReferenceLogicalName, -ConnectionReferenceDisplayName, and -SolutionUniqueName"
            exit 1
        }

        Write-Host "=== Create Connection Reference ===" -ForegroundColor Cyan
        Write-Host "Logical Name: $ConnectionReferenceLogicalName"
        Write-Host "Display Name: $ConnectionReferenceDisplayName"
        Write-Host "Connector: $ConnectorId"
        Write-Host "Solution: $SolutionUniqueName"
        Write-Host ""

        $createHeaders = Get-DataverseHeaders -Token $token -ReturnRepresentation $true -SolutionName $SolutionUniqueName

        $body = @{
            connectionreferencelogicalname = $ConnectionReferenceLogicalName
            connectionreferencedisplayname = $ConnectionReferenceDisplayName
            connectorid                    = $ConnectorId
        } | ConvertTo-Json -Depth 10 -Compress

        try {
            $response = Invoke-RestMethod -Uri "$apiUrl/connectionreferences" `
                -Headers $createHeaders -Method Post `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
                -ContentType "application/json; charset=utf-8"

            $createdId = $response.connectionreferenceid
            Write-Host "[OK] Connection reference created: $ConnectionReferenceLogicalName" -ForegroundColor Green
            Write-Host "  ID: $createdId"

            [PSCustomObject]@{
                Success     = $true
                LogicalName = $ConnectionReferenceLogicalName
                DisplayName = $ConnectionReferenceDisplayName
                ConnectorId = $ConnectorId
                Id          = $createdId
                Solution    = $SolutionUniqueName
            }
        } catch {
            $errDetail = Get-DataverseErrorDetail -ErrorRecord $_
            Write-Host "[ERROR] Failed to create connection reference: $errDetail" -ForegroundColor Red
            exit 1
        }
    }
}
