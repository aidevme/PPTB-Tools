# lint:raw-invoke-backlog ADR 0014 open backlog - pre-existing drift, NOT an exemption.
# Calls the Dataverse Web API directly instead of the shared Invoke-DataverseApi, so it misses
# the invoker's hardening (notably -UseBasicParsing, without which Windows PowerShell 5.1 dies
# under -NonInteractive on a build agent). Convert per ADR 0014's open-backlog table, then
# DELETE this marker. Reported as WARN on every lint run until then.
<#
.SYNOPSIS  Harvest 1:N relationships among in-scope tables for the technical pack + ERD.
.DESCRIPTION
  Pulls all OneToMany relationship metadata once, filters to relationships where both sides are in the
  harvested in-scope set (entities.json) OR the lookup/referencing attribute carries a client/ISV prefix.
  Writes relationships.json [{Schema,Referenced,Referencing,ReferencingAttribute,IsCustom}].
  Read-only. Uses hso-shared-scripts auth. No client data embedded.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$MetaDir,                 # folder with entities.json (defines scope); output written here too
    [Parameter(Mandatory)][string]$ClientPrefix,   # e.g. contoso - the engagement publisher prefix; no default, a wrong one silently scopes the whole review
    [string[]]$IsvPrefixes = @(),
    [switch]$Interactive
)
$ErrorActionPreference='Stop'
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"; . "$sharedDir\Dataverse-WebApi.ps1"
$api="$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2"
$token=Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive:$Interactive
if(-not $token){ throw "Auth failed for $EnvironmentUrl." }
$script:DvHeaders = Get-DataverseHeaders -Token $token -MaxPageSize 5000
function Hdr { $script:DvHeaders }
function Page($u){ $a=@(); while($u){ $r=Invoke-RestMethod -Uri $u -Headers (Hdr) -Method Get; if($r.value){$a+=$r.value}; $p=$r.PSObject.Properties['@odata.nextLink']; $u=if($p){$p.Value}else{$null} }; return $a }

$ents = Get-Content (Join-Path $MetaDir 'entities.json') -Raw | ConvertFrom-Json
$scope = [System.Collections.Generic.HashSet[string]]::new()
foreach($e in $ents){ [void]$scope.Add($e.LogicalName.ToLower()) }
$prefixes = @($ClientPrefix) + $IsvPrefixes | Where-Object { $_ } | ForEach-Object { $_.ToLower() + "_" }
Write-Host "in-scope tables: $($scope.Count); prefixes: $($prefixes -join ',')"

$rel = Page "$api/RelationshipDefinitions/Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata?`$select=SchemaName,ReferencedEntity,ReferencingEntity,ReferencingAttribute,IsCustomRelationship"
Write-Host "total 1:N relationships: $($rel.Count)"

$out=@()
foreach($r in $rel){
    $rd=$r.ReferencedEntity.ToLower(); $rg=$r.ReferencingEntity.ToLower(); $ra=$r.ReferencingAttribute.ToLower()
    $bothInScope = $scope.Contains($rd) -and $scope.Contains($rg)
    $prefixed = $prefixes | Where-Object { $ra.StartsWith($_) -or $rd.StartsWith($_) -or $rg.StartsWith($_) }
    if($bothInScope -and ($prefixed -or $r.IsCustomRelationship)){
        $out += [pscustomobject]@{ Schema=$r.SchemaName; Referenced=$rd; Referencing=$rg; ReferencingAttribute=$ra; IsCustom=[bool]$r.IsCustomRelationship }
    }
}
$out = $out | Sort-Object Referenced,Referencing,Schema -Unique
$out | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $MetaDir 'relationships.json') -Encoding UTF8
Write-Host "RELATIONSHIPS_DONE: $($out.Count) in-scope/custom relationships -> $(Join-Path $MetaDir 'relationships.json')"
