# lint:raw-invoke-backlog ADR 0014 open backlog - pre-existing drift, NOT an exemption.
# Calls the Dataverse Web API directly instead of the shared Invoke-DataverseApi, so it misses
# the invoker's hardening (notably -UseBasicParsing, without which Windows PowerShell 5.1 dies
# under -NonInteractive on a build agent). Convert per ADR 0014's open-backlog table, then
# DELETE this marker. Reported as WARN on every lint run until then.
<#
.SYNOPSIS  % populated of data-bound fields on key forms (FetchXML aggregate counts).
.DESCRIPTION
  For each (table -> form name) in -Map: read the form's FormXML for data-bound fields, then per field
  compute the % of records where it is populated, using FetchXML 'countcolumn' aggregates (count non-null).
  Windowing: tables with history older than 3 years are scoped to the last 3 years (createdon >= today-3y)
  and the window is noted (FetchXML aggregates cap at 50k rows; the window keeps tables under that).
  Uses hso-shared-scripts auth. No client data embedded.
.PARAMETER Map  Hashtable table -> main-form display name, e.g. @{ opportunity='Sales'; account='Main' }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][hashtable]$Map,
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$ActiveOnly,
    [switch]$Interactive
)
$ErrorActionPreference='Stop'
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"; . "$sharedDir\Dataverse-WebApi.ps1"
New-Item -ItemType Directory -Force -Path $OutDir|Out-Null
$api="$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2"
$token=Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive:$Interactive
if(-not $token){ throw "Auth failed for $EnvironmentUrl." }
$script:DvHeaders = Get-DataverseHeaders -Token $token -MaxPageSize 5000   # build once ('H' is the Get-History alias — never name a helper H)
function Hdr { $script:DvHeaders }
$enc={param($s)[Uri]::EscapeDataString($s)}
$cutoff=(Get-Date).AddYears(-3).ToString('yyyy-MM-dd')

function Get-EntMeta($logical){ $d=Invoke-RestMethod -Uri "$api/EntityDefinitions(LogicalName='$logical')?`$select=EntitySetName,PrimaryIdAttribute" -Headers (Hdr); $at=@{}; (Invoke-RestMethod -Uri "$api/EntityDefinitions(LogicalName='$logical')/Attributes?`$select=LogicalName,AttributeType" -Headers (Hdr)).value|%{$at[$_.LogicalName.ToLower()]=$_.AttributeType}; @{Set=$d.EntitySetName;Pk=$d.PrimaryIdAttribute;Attrs=$at} }
function CntAgg($set,$logical,$col,$filterXml){ $fil=if($filterXml){"<filter type='and'>$filterXml</filter>"}else{""}; $fx="<fetch aggregate='true'><entity name='$logical'><attribute name='$col' alias='c' aggregate='countcolumn'/>$fil</entity></fetch>"; try{[int](Invoke-RestMethod -Uri "$api/$set`?fetchXml=$(& $enc $fx)" -Headers (Hdr)).value[0].c}catch{-1} }
function AnyOlder($set,$logical){ try{ ((Invoke-RestMethod -Uri "$api/$set`?`$select=$($logical)id&`$top=1&`$filter=createdon lt ${cutoff}T00:00:00Z" -Headers (Hdr)).value.Count -gt 0) }catch{ $false } }

$allRows=@(); $summary=@()
foreach($tbl in $Map.Keys){ $formName=$Map[$tbl]; Write-Host "=== $tbl :: '$formName' ==="
  $meta=Get-EntMeta $tbl; $set=$meta.Set
  $activeCond=if($ActiveOnly){"<condition attribute='statecode' operator='eq' value='0'/>"}else{""}
  if(AnyOlder $set $tbl){ $window="Last 3 years (createdon >= $cutoff)"; $winCond="<condition attribute='createdon' operator='ge' value='$cutoff'/>" } else { $window="All records"; $winCond="" }
  $scope="$activeCond$winCond"; $total=CntAgg $set $tbl $meta.Pk $scope
  Write-Host "   scope='$window' records=$total"
  if($total -lt 0){ Write-Warning "   count failed (>50k in-window?) — skipping"; $summary+=[pscustomobject]@{Table=$tbl;Form=$formName;Scope="$window (skipped)";Records=$total;FieldsOnForm=0;Under5pct=0;Pct5to50=0}; continue }
  $fxml=(Invoke-RestMethod -Uri "$api/systemforms?`$select=name,formxml&`$filter=objecttypecode eq '$tbl' and type eq 2 and name eq '$($formName.Replace("'","''"))'" -Headers (Hdr)).value
  if(-not $fxml){ Write-Warning "   form '$formName' not found"; continue }
  $fields=@([regex]::Matches([string]$fxml[0].formxml,'(?i)datafieldname="([^"]+)"')|%{$_.Groups[1].Value.ToLower()}|Sort-Object -Unique)
  $pop=@(); foreach($f in $fields){ if(-not $meta.Attrs.ContainsKey($f)){continue}; $p=CntAgg $set $tbl $f $scope; $pct=if($total -gt 0 -and $p -ge 0){[math]::Round(100.0*$p/$total,1)}else{-1}; $pop+=[pscustomobject]@{Table=$tbl;Form=$formName;Field=$f;Type=$meta.Attrs[$f];Populated=$p;Total=$total;PctPopulated=$pct;Scope=$window} }
  $allRows+=$pop
  $lo=@($pop|?{$_.PctPopulated -ge 0 -and $_.PctPopulated -lt 5}).Count; $mid=@($pop|?{$_.PctPopulated -ge 5 -and $_.PctPopulated -lt 50}).Count
  $summary+=[pscustomobject]@{Table=$tbl;Form=$formName;Scope=$window;Records=$total;FieldsOnForm=$fields.Count;Under5pct=$lo;Pct5to50=$mid}
  Write-Host "   fields <5%: $lo ; 5-50%: $mid"
}
$allRows|Sort-Object Table,PctPopulated|Export-Csv "$OutDir\form_field_population.csv" -NoTypeInformation -Encoding UTF8
$allRows|ConvertTo-Json -Depth 4|Set-Content "$OutDir\form_field_population.json" -Encoding UTF8
$summary|Export-Csv "$OutDir\form_field_population_summary.csv" -NoTypeInformation -Encoding UTF8
Write-Host "`n=== SUMMARY ==="; $summary|Format-Table -AutoSize
Write-Host "POP_DONE -> $OutDir"
