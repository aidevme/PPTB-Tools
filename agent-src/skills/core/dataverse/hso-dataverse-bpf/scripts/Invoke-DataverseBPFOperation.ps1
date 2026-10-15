<#
.SYNOPSIS
Query, instantiate, and drive Dataverse Business Process Flows (BPFs) via the Web API.

.DESCRIPTION
Operations:
  QueryBPF           - Resolve a BPF (workflow category=4) by id or name; decode state; report instance entity.
  QueryStages        - List a BPF's stages in TRUE order (derived from clientdata nextStageId chain).
  GetClientData      - Pull workflow.clientdata, save to a file, print the stage chain.
  ListInstances      - List BPF instances for a primary record.
  CreateInstance     - Create a BPF instance row for a record (attach the BPF, set start stage).
  SetStage           - Advance/retard an instance to a target stage (rebuilds traversedpath).
  AddToApp           - Add the BPF to a model-driven app (REQUIRED for the bar to render).
  QueryAppInclusion  - Report which apps include the BPF.

Authentication uses the shared Dataverse-Auth.ps1 (interactive WebView, auto-falls-back to
device-code when the WebView renders blank; pass -DeviceCode to force device-code).

.NOTES
See ../references/bpf-internals.md for the data model, the clientdata format, and the gotchas.

Limitations / supported-contract caveats:
- Structural BPF edits (add/reorder/rename stages) are NOT supported here - use the BPF designer.
- Stage ordering is parsed from clientdata's nextStageId chain and assumes a SINGLE LINEAR path.
  BRANCHED BPFs (conditional stages) are not handled - use the RetrieveActivePath /
  RetrieveProcessInstances messages for those. clientdata is an undocumented, read-only blob.
- SetStage writes activestageid + a full traversedpath (the data-migration pattern). Microsoft's
  documented contract is to move only to the NEXT or PREVIOUS stage; multi-stage jumps are not an
  officially supported scenario, though the data-migration pattern generally works for linear flows.
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet('QueryBPF','QueryStages','GetClientData','ListInstances','CreateInstance','SetStage','AddToApp','QueryAppInclusion')]
    [string]$Operation,

    [Parameter(Mandatory)][string]$EnvironmentUrl,

    # BPF identity (supply one)
    [string]$BpfId,
    [string]$BpfName,

    # Record / instance targeting
    [string]$RecordId,        # primary-entity record id (e.g. the incident/case id)
    [string]$InstanceId,      # BPF instance row id (optional alternative to RecordId for SetStage)
    [string]$StageId,         # target / start stage id

    # App wiring
    [string]$AppUniqueName,

    # Output
    [string]$OutFile,         # GetClientData: where to save the clientdata json

    # Auth
    [switch]$Interactive,
    [switch]$DeviceCode
)

$ErrorActionPreference = 'Stop'
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"
. "$sharedDir\Dataverse-WebApi.ps1"

# ----------------------------------------------------------------------------
# Auth
# ----------------------------------------------------------------------------
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive -DeviceCode:$DeviceCode
if (-not $token) { Write-Host "[ERROR] Authentication failed." -ForegroundColor Red; exit 1 }

function Api {
    param([string]$Method, [string]$Endpoint, [object]$Body, [switch]$Annotations)
    Invoke-DataverseApi -EnvironmentUrl $EnvironmentUrl -Token $token -Method $Method `
        -Endpoint $Endpoint -Body $Body -IncludeAnnotations:$Annotations
}

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

function Resolve-Bpf {
    <# Returns the workflow record (category=4) by id or name. #>
    if ($BpfId) {
        $id = $BpfId -replace '[{}]', ''
        return Api GET "workflows($id)?`$select=workflowid,name,uniquename,primaryentity,category,statecode,statuscode,clientdata"
    }
    if ($BpfName) {
        $safe = $BpfName.Replace("'", "''")
        $res = (Api GET "workflows?`$filter=name eq '$safe' and category eq 4&`$select=workflowid,name,uniquename,primaryentity,category,statecode,statuscode,clientdata").value
        if (-not $res -or $res.Count -eq 0) { throw "No BPF (category=4) named '$BpfName' found." }
        if ($res.Count -gt 1) { Write-Host "[WARN] Multiple BPFs named '$BpfName' - using the first." -ForegroundColor Yellow }
        return $res[0]
    }
    throw "Supply -BpfId or -BpfName."
}

function Decode-WorkflowState {
    param([int]$StateCode, [int]$StatusCode)
    # workflow entity: statecode 0=Draft, 1=Activated ; statuscode 1=Draft, 2=Activated
    if ($StateCode -eq 1 -and $StatusCode -eq 2) { return "Activated" }
    if ($StateCode -eq 0) { return "Draft (NOT activated - cannot create instances)" }
    return "statecode=$StateCode statuscode=$StatusCode"
}

function Get-StageChain {
    <#
      Parse clientdata JSON and return stages in TRUE left-to-right order.
      Each entry: @{ StageId; Name; Category; DataField; NextStageId }
      Order is derived from the nextStageId chain, NOT processstage query order.
    #>
    param([string]$ClientData)
    if (-not $ClientData) { return @() }
    $json = $ClientData | ConvertFrom-Json

    # Recursively collect every StageStep object.
    $stages = New-Object System.Collections.Generic.List[object]
    function Walk($node) {
        if ($null -eq $node) { return }
        if ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
            foreach ($item in $node) { Walk $item }
            return
        }
        if ($node.PSObject -and $node.PSObject.Properties['__class']) {
            if ([string]$node.__class -like 'StageStep*') {
                # Find the bound data field (first nested ControlStep.dataFieldName)
                $dataField = $null
                function FindField($n) {
                    if ($null -eq $n) { return $null }
                    if ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) {
                        foreach ($i in $n) { $f = FindField $i; if ($f) { return $f } }
                        return $null
                    }
                    if ($n.PSObject -and $n.PSObject.Properties['dataFieldName'] -and $n.dataFieldName) { return $n.dataFieldName }
                    if ($n.PSObject -and $n.PSObject.Properties['steps'] -and $n.steps.PSObject.Properties['list']) { return (FindField $n.steps.list) }
                    return $null
                }
                $dataField = $null
                if ($node.PSObject.Properties['steps'] -and $node.steps -and $node.steps.PSObject.Properties['list']) {
                    $dataField = FindField $node.steps.list   # pass the StepStep array, not the wrapper object
                }
                $stages.Add([pscustomobject]@{
                    StageId     = ([string]$node.stageId)
                    Name        = ([string]$node.description)
                    Category    = ([string]$node.stageCategory)
                    DataField   = $dataField
                    NextStageId = ([string]$node.nextStageId)
                })
            }
        }
        # Descend into steps.list
        if ($node.PSObject -and $node.PSObject.Properties['steps'] -and $node.steps.PSObject.Properties['list']) {
            Walk $node.steps.list
        }
    }
    Walk $json

    if ($stages.Count -eq 0) { return @() }

    # Order via nextStageId chain: head = stage that no other stage points to.
    $byId = @{}; foreach ($s in $stages) { $byId[$s.StageId] = $s }
    $pointed = @{}; foreach ($s in $stages) { if ($s.NextStageId) { $pointed[$s.NextStageId] = $true } }
    $head = $stages | Where-Object { -not $pointed.ContainsKey($_.StageId) } | Select-Object -First 1
    if (-not $head) { return $stages }  # cyclic / malformed - return as-found

    $ordered = New-Object System.Collections.Generic.List[object]
    $cur = $head; $guard = 0
    while ($cur -and $guard -lt 100) {
        $ordered.Add($cur)
        if ($cur.NextStageId -and $byId.ContainsKey($cur.NextStageId)) { $cur = $byId[$cur.NextStageId] } else { break }
        $guard++
    }
    return $ordered
}

function Get-InstanceEntityMeta {
    <# Returns @{ EntitySet; PrimaryId; LookupField; PrimaryEntity; PrimaryEntitySet } for a BPF. #>
    param($Bpf)
    $instLogical = $Bpf.uniquename
    $meta = Api GET "EntityDefinitions(LogicalName='$instLogical')?`$select=EntitySetName,PrimaryIdAttribute"
    $primary = $Bpf.primaryentity
    $primMeta = Api GET "EntityDefinitions(LogicalName='$primary')?`$select=EntitySetName"
    return @{
        EntitySet       = $meta.EntitySetName
        PrimaryId       = $meta.PrimaryIdAttribute
        LookupField     = "bpf_${primary}id"     # convention: bpf_<primaryentity>id
        PrimaryEntity   = $primary
        PrimaryEntitySet= $primMeta.EntitySetName
    }
}

# ----------------------------------------------------------------------------
# Operations
# ----------------------------------------------------------------------------

switch ($Operation) {

    'QueryBPF' {
        $bpf = Resolve-Bpf
        Write-Host "=== BPF ===" -ForegroundColor Cyan
        Write-Host "  Name             : $($bpf.name)"
        Write-Host "  Workflow Id      : $($bpf.workflowid)"
        Write-Host "  Instance entity  : $($bpf.uniquename)   (uniquename IS the instance entity logical name)"
        Write-Host "  Primary entity   : $($bpf.primaryentity)"
        Write-Host "  State            : $(Decode-WorkflowState -StateCode $bpf.statecode -StatusCode $bpf.statuscode)"
        Write-Host "  Lookup to record : bpf_$($bpf.primaryentity)id"
    }

    'QueryStages' {
        $bpf = Resolve-Bpf
        $chain = Get-StageChain -ClientData $bpf.clientdata
        Write-Host "=== Stages for '$($bpf.name)' (TRUE order from clientdata) ===" -ForegroundColor Cyan
        $i = 1
        foreach ($s in $chain) {
            $field = if ($s.DataField) { $s.DataField } else { '(no data step)' }
            Write-Host ("  {0}. {1,-22} {2}  field={3}" -f $i, $s.Name, $s.StageId, $field)
            $i++
        }
        Write-Host "Stage count: $($chain.Count)"
        Write-Host "Start stage: $($chain[0].StageId) ($($chain[0].Name))"
    }

    'GetClientData' {
        $bpf = Resolve-Bpf
        $path = if ($OutFile) { $OutFile } else { Join-Path (Get-Location) "bpf_$($bpf.uniquename)_clientdata.json" }
        $bpf.clientdata | Out-File -FilePath $path -Encoding utf8
        Write-Host "[OK] clientdata saved ($($bpf.clientdata.Length) chars) -> $path" -ForegroundColor Green
        $chain = Get-StageChain -ClientData $bpf.clientdata
        Write-Host "Stage chain:"
        ($chain | ForEach-Object { $_.Name }) -join '  ->  ' | Write-Host
    }

    'ListInstances' {
        if (-not $RecordId) { throw "ListInstances requires -RecordId (the primary record id)." }
        $bpf = Resolve-Bpf
        $m = Get-InstanceEntityMeta -Bpf $bpf
        $rid = $RecordId -replace '[{}]', ''
        $insts = (Api GET "$($m.EntitySet)?`$select=$($m.PrimaryId),statecode,_activestageid_value,_processid_value&`$filter=_$($m.LookupField)_value eq $rid" -Annotations).value
        Write-Host "=== BPF instances for record $rid ===" -ForegroundColor Cyan
        if (-not $insts -or $insts.Count -eq 0) { Write-Host "  (none)"; break }
        foreach ($x in $insts) {
            Write-Host ("  Instance {0}  state={1}  stage={2}" -f $x.$($m.PrimaryId), $x.statecode, $x.'_activestageid_value@OData.Community.Display.V1.FormattedValue')
        }
    }

    'CreateInstance' {
        if (-not $RecordId) { throw "CreateInstance requires -RecordId (the primary record id)." }
        $bpf = Resolve-Bpf
        if (-not ($bpf.statecode -eq 1 -and $bpf.statuscode -eq 2)) {
            throw "BPF '$($bpf.name)' is not Activated (state=$(Decode-WorkflowState -StateCode $bpf.statecode -StatusCode $bpf.statuscode)). Activate it before creating instances."
        }
        $m = Get-InstanceEntityMeta -Bpf $bpf
        $chain = Get-StageChain -ClientData $bpf.clientdata
        $startStage = if ($StageId) { ($StageId -replace '[{}]','') } else { $chain[0].StageId }
        $rid = $RecordId -replace '[{}]', ''

        # Guard against duplicate active instances.
        $existing = (Api GET "$($m.EntitySet)?`$select=$($m.PrimaryId)&`$filter=_$($m.LookupField)_value eq $rid and statecode eq 0").value
        if ($existing -and $existing.Count -gt 0) {
            Write-Host "[WARN] An active instance already exists for this record ($($existing[0].$($m.PrimaryId))). Skipping create." -ForegroundColor Yellow
            break
        }

        $wid = $bpf.workflowid -replace '[{}]', ''
        $body = [ordered]@{
            # Raw Web API: lookups MUST be set via @odata.bind navigation properties.
            # The bare-GUID form (processid/activestageid as plain uuid strings) is a
            # Power Automate *connector* quirk ONLY - it does NOT work against the raw Web API.
            # See references/bpf-internals.md Gotcha 5.
            "processid@odata.bind"         = "/workflows($wid)"
            "activestageid@odata.bind"     = "/processstages($startStage)"
            "$($m.LookupField)@odata.bind" = "/$($m.PrimaryEntitySet)($rid)"
        }
        $created = Invoke-DataverseApi -EnvironmentUrl $EnvironmentUrl -Token $token -Method POST `
            -Endpoint $m.EntitySet -Body $body -ReturnRepresentation $true
        Write-Host "[OK] BPF instance created: $($created.$($m.PrimaryId))" -ForegroundColor Green
        Write-Host "  active stage = $startStage ; traversedpath auto-initialised by the platform."
        Write-Host "  NOTE: do NOT 'fix' a blank bar by PATCHing processid/stageid on the primary record - those"
        Write-Host "        legacy columns are deprecated/unsupported and the write is dropped. (The ONE supported"
        Write-Host "        exception is setting processid at create-time on the record to choose/skip the BPF.)"
    }

    'SetStage' {
        if (-not $StageId) { throw "SetStage requires -StageId (the target stage id)." }
        $bpf = Resolve-Bpf
        $m = Get-InstanceEntityMeta -Bpf $bpf
        $target = $StageId -replace '[{}]', ''

        # Resolve the instance id.
        $instId = $InstanceId -replace '[{}]', ''
        if (-not $instId) {
            if (-not $RecordId) { throw "SetStage requires -InstanceId or -RecordId." }
            $rid = $RecordId -replace '[{}]', ''
            $found = (Api GET "$($m.EntitySet)?`$select=$($m.PrimaryId)&`$filter=_$($m.LookupField)_value eq $rid and statecode eq 0").value
            if (-not $found -or $found.Count -eq 0) { throw "No active BPF instance found for record $rid." }
            $instId = $found[0].$($m.PrimaryId)
        }

        # Build traversedpath = start..target (in clientdata order).
        $chain = Get-StageChain -ClientData $bpf.clientdata
        $path = New-Object System.Collections.Generic.List[string]
        foreach ($s in $chain) { $path.Add($s.StageId); if ($s.StageId -eq $target) { break } }
        if ($path[-1] -ne $target) { throw "Target stage $target is not part of BPF '$($bpf.name)'." }
        $traversed = ($path -join ',')

        $body = [ordered]@{
            'activestageid@odata.bind' = "/processstages($target)"
            'traversedpath'            = $traversed
        }
        Invoke-DataverseApi -EnvironmentUrl $EnvironmentUrl -Token $token -Method PATCH `
            -Endpoint "$($m.EntitySet)($instId)" -Body $body | Out-Null
        Write-Host "[OK] Instance $instId moved to stage $target" -ForegroundColor Green
        Write-Host "  traversedpath = $traversed"
    }

    'AddToApp' {
        if (-not $AppUniqueName) { throw "AddToApp requires -AppUniqueName." }
        $bpf = Resolve-Bpf
        $safe = $AppUniqueName.Replace("'", "''")
        $app = (Api GET "appmodules?`$filter=uniquename eq '$safe'&`$select=appmoduleid,name").value
        if (-not $app -or $app.Count -eq 0) { throw "App '$AppUniqueName' not found." }
        $appId = $app[0].appmoduleid
        $body = @{
            AppId      = $appId
            Components = @( @{ '@odata.type' = 'Microsoft.Dynamics.CRM.workflow'; 'workflowid' = ($bpf.workflowid -replace '[{}]','') } )
        }
        Invoke-DataverseApi -EnvironmentUrl $EnvironmentUrl -Token $token -Method POST -Endpoint 'AddAppComponents' -Body $body | Out-Null
        Write-Host "[OK] Added BPF '$($bpf.name)' to app '$($app[0].name)'." -ForegroundColor Green
        Write-Host "  Publish the app (or PublishXml) and reload the form - the process bar should now render."
    }

    'QueryAppInclusion' {
        $bpf = Resolve-Bpf
        $wid = $bpf.workflowid -replace '[{}]', ''
        # componenttype 29 = Business Process Flow; objectid = the workflow (BPF) id.
        # The parent-app lookup on appmodulecomponent is 'appmoduleidunique', which references
        # appmodule.appmoduleidunique (an ALTERNATE KEY), NOT the appmoduleid primary key. So resolve
        # the app by FILTERING on appmoduleidunique - GET appmodules(<that value>) would 404.
        $rows = (Api GET "appmodulecomponents?`$filter=objectid eq $wid and componenttype eq 29&`$select=_appmoduleidunique_value").value
        Write-Host "=== Apps including BPF '$($bpf.name)' ===" -ForegroundColor Cyan
        if (-not $rows -or $rows.Count -eq 0) {
            Write-Host "  NOT IN ANY APP - one likely reason a process bar renders blank." -ForegroundColor Yellow
            Write-Host "  Fix with AddToApp (then publish/reload). Also check the BPF's security roles." -ForegroundColor Yellow
            break
        }
        foreach ($r in $rows) {
            $appUnique = $r.'_appmoduleidunique_value'
            $app = (Api GET "appmodules?`$filter=appmoduleidunique eq $appUnique&`$select=name,uniquename").value
            if ($app -and $app.Count -gt 0) {
                Write-Host "  In app: $($app[0].name) ($($app[0].uniquename))"
            } else {
                Write-Host "  In app (unique id $appUnique - name not resolved)"
            }
        }
    }
}
