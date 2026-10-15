# lint:raw-invoke-backlog ADR 0014 open backlog - pre-existing drift, NOT an exemption.
# Calls the Dataverse Web API directly instead of the shared Invoke-DataverseApi, so it misses
# the invoker's hardening (notably -UseBasicParsing, without which Windows PowerShell 5.1 dies
# under -NonInteractive on a build agent). Convert per ADR 0014's open-backlog table, then
# DELETE this marker. Reported as WARN on every lint run until then.
<#
.SYNOPSIS  Harvest live Dataverse (CE) metadata for an as-is system review.
.DESCRIPTION
  Read-only. Resolves the in-scope table set (the named app's component set if -AppName, else the in-scope
  solutions' entity components), then writes JSON for: entities, attributes (searchable flags), forms
  (+field refs, type, activation, managed, default, app-inclusion), views (+field refs), workflows/flows
  (+definition refs), the solution/ISV catalog, and a security/org snapshot. Uses hso-shared-scripts auth.
  No client data or credentials are embedded. See the System Review SOP for methodology.
.NOTES  Part of hso-analyze-system-review. Author attribution: read from CLAUDE.local.md by the caller.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [string]$AppName,                                  # if set, scope to this model-driven app's components
    [string[]]$InScopeSolutions,                       # else restrict to these solution unique names
    [string]$ClientPrefix,                             # e.g. the client publisher prefix (for layer tagging)
    [string[]]$IsvPrefixes = @(),        # ISV publisher prefixes (override per client)
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$Interactive
)
$ErrorActionPreference='Stop'
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"; . "$sharedDir\Dataverse-WebApi.ps1"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$api = "$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2"
$token = Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive:$Interactive
if(-not $token){ throw "Auth failed for $EnvironmentUrl (run hso-dataverse-auth-azcli first)." }
$script:DvHeaders = Get-DataverseHeaders -Token $token -MaxPageSize 5000   # build once (note: 'H' is the Get-History alias — never name a helper H)
function Hdr { $script:DvHeaders }
function Page($u){ $a=@(); while($u){ $r=Invoke-RestMethod -Uri $u -Headers (Hdr) -Method Get; if($r.value){$a+=$r.value}; $p=$r.PSObject.Properties['@odata.nextLink']; $u=if($p){$p.Value}else{$null} }; return $a }
$enc={param($s)[Uri]::EscapeDataString($s)}
function Tok($t){
  if(-not $t){ return @() }
  $prefixes = @(@($ClientPrefix) + $IsvPrefixes | Where-Object { $_ })
  $alts = @($prefixes | ForEach-Object { [regex]::Escape($_) + '_' }) + @('msdyn_','adx_','msfp_')
  $pat = '(?i)(?:' + ($alts -join '|') + ')[a-z0-9_]+'
  return @([regex]::Matches($t.ToLower(), $pat) | ForEach-Object { $_.Value } | Sort-Object -Unique)
}

# ── resolve in-scope tables + (optional) app form components ──────────────────
$appFormIds=@()
if($AppName){
  $app=(Page "$api/appmodules?`$select=appmoduleid,name&`$filter=name eq '$(& $enc $AppName)'")
  if(-not $app){ throw "App '$AppName' not found." }
  $aid=$app[0].appmoduleid
  $comps=@((Invoke-RestMethod -Uri "$api/RetrieveAppComponents(AppModuleId=$aid)" -Headers (Hdr)).value)
  $entMeta=@($comps|?{$_.componenttype -eq 1}|Select-Object -ExpandProperty objectid)
  $appFormIds=@($comps|?{$_.componenttype -eq 60}|Select-Object -ExpandProperty objectid)
  $allEnt=Page "$api/EntityDefinitions?`$select=MetadataId,LogicalName,DisplayName,IsCustomEntity,IsManaged,OwnershipType"
  $byId=@{}; foreach($e in $allEnt){$byId[$e.MetadataId]=$e}
  $entities=@(); foreach($m in $entMeta){ if($byId.ContainsKey($m)){ $e=$byId[$m]; $entities+=[pscustomobject]@{LogicalName=$e.LogicalName;DisplayName=$e.DisplayName.UserLocalizedLabel.Label;IsCustomEntity=$e.IsCustomEntity;IsManaged=$e.IsManaged;OwnershipType=$e.OwnershipType;Source="app:$AppName"} } }
} else {
  if(-not $InScopeSolutions){ # discover: visible, non-default solutions
    $InScopeSolutions=@((Page "$api/solutions?`$select=uniquename&`$filter=isvisible eq true and uniquename ne 'Default' and uniquename ne 'Active'")|Select-Object -ExpandProperty uniquename)
  }
  $sf=($InScopeSolutions|%{"uniquename eq '$_'"}) -join ' or '
  $sols=Page "$api/solutions?`$select=solutionid,uniquename&`$filter=$(& $enc $sf)"
  $metaIds=@{}
  foreach($s in $sols){ foreach($c in (Page "$api/solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $($s.solutionid) and componenttype eq 1")){ $metaIds[$c.objectid]=$true } }
  $allEnt=Page "$api/EntityDefinitions?`$select=MetadataId,LogicalName,DisplayName,IsCustomEntity,IsManaged,OwnershipType"
  $byId=@{}; foreach($e in $allEnt){$byId[$e.MetadataId]=$e}
  $entities=@(); foreach($m in $metaIds.Keys){ if($byId.ContainsKey($m)){ $e=$byId[$m]; $entities+=[pscustomobject]@{LogicalName=$e.LogicalName;DisplayName=$e.DisplayName.UserLocalizedLabel.Label;IsCustomEntity=$e.IsCustomEntity;IsManaged=$e.IsManaged;OwnershipType=$e.OwnershipType;Source="solutions"} } }
}
$entities=@($entities|Sort-Object LogicalName -Unique)
$names=@($entities|Select-Object -ExpandProperty LogicalName)
Write-Host "in-scope tables: $($names.Count)"
$entities | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $OutDir 'entities.json') -Encoding UTF8
@($appFormIds) | ConvertTo-Json | Set-Content (Join-Path $OutDir 'app_form_components.json') -Encoding UTF8

# ── attributes ───────────────────────────────────────────────────────────────
$attrs=@()
foreach($n in $names){ try{ foreach($a in (Page "$api/EntityDefinitions(LogicalName='$n')/Attributes?`$select=LogicalName,DisplayName,AttributeType,IsCustomAttribute,IsManaged,IsValidForAdvancedFind,IsValidForForm,IsSearchable,AttributeOf")){
  $attrs+=[pscustomobject]@{Entity=$n;LogicalName=$a.LogicalName;DisplayName=$a.DisplayName.UserLocalizedLabel.Label;Type=$a.AttributeType;IsCustom=$a.IsCustomAttribute;IsManaged=$a.IsManaged;SearchableAF=[bool]$a.IsValidForAdvancedFind.Value;ValidForForm=[bool]$a.IsValidForForm.Value;RelevanceSearch=$(if($a.PSObject.Properties['IsSearchable']){[bool]$a.IsSearchable}else{$false});AttributeOf=$a.AttributeOf} } }catch{ Write-Warning "attrs $n : $($_.Exception.Message)" } }
Write-Host "attributes: $($attrs.Count)"; $attrs|ConvertTo-Json -Depth 4|Set-Content (Join-Path $OutDir 'attributes.json') -Encoding UTF8

# ── forms + views ────────────────────────────────────────────────────────────
$forms=@(); $views=@(); $b=25
for($i=0;$i -lt $names.Count;$i+=$b){ $sl=$names[$i..([Math]::Min($i+$b-1,$names.Count-1))]
  try{ foreach($r in (Page "$api/systemforms?`$select=formid,name,type,objecttypecode,formactivationstate,ismanaged,isdefault,formxml&`$filter=$(& $enc (($sl|%{"objecttypecode eq '$_'"}) -join ' or '))")){
    $fx=[string]$r.formxml
    $df=@([regex]::Matches($fx,'(?i)datafieldname="([^"]+)"')|%{$_.Groups[1].Value.ToLower()}|Sort-Object -Unique)
    $libs=@([regex]::Matches($fx,'(?i)<Library[^>]*\bname="([^"]+)"')|%{$_.Groups[1].Value}|Sort-Object -Unique)   # JS web resources wired to the form
    $funcs=@([regex]::Matches($fx,'(?i)functionName="([^"]+)"')|%{$_.Groups[1].Value}|Sort-Object -Unique)        # event handler functions
    $evts=@([regex]::Matches($fx,'(?i)<event[^>]*\bname="([^"]+)"')|%{$_.Groups[1].Value}|Sort-Object -Unique)    # onload/onsave/onchange triggers
    $forms+=[pscustomobject]@{Entity=$r.objecttypecode;FormId=$r.formid;Name=$r.name;Type=$r.type;ActivationState=$r.formactivationstate;IsManaged=$r.ismanaged;IsDefault=$r.isdefault;InApp=($appFormIds -contains $r.formid);FieldCount=$df.Count;DataFields=$df;Libraries=$libs;Functions=$funcs;Events=$evts;RefTokens=(Tok $fx)} } }catch{ Write-Warning "forms $i : $($_.Exception.Message)" }
  try{ foreach($v in (Page "$api/savedqueries?`$select=savedqueryid,name,querytype,returnedtypecode,isdefault,ismanaged,fetchxml,layoutxml&`$filter=$(& $enc (($sl|%{"returnedtypecode eq '$_'"}) -join ' or '))")){
    $vt=@(); foreach($m in [regex]::Matches("$($v.fetchxml) $($v.layoutxml)",'(?i)(?:attribute|cell)\s+name="([^"]+)"')){ $vt+=$m.Groups[1].Value.ToLower() }
    $views+=[pscustomobject]@{Entity=$v.returnedtypecode;ViewId=$v.savedqueryid;Name=$v.name;QueryType=$v.querytype;IsDefault=$v.isdefault;IsManaged=$v.ismanaged;RefTokens=@($vt|Sort-Object -Unique)} } }catch{ Write-Warning "views $i : $($_.Exception.Message)" }
}
Write-Host "forms: $($forms.Count); views: $($views.Count)"
$forms|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutDir 'forms.json') -Encoding UTF8
$views|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutDir 'views.json') -Encoding UTF8

# ── workflows / flows (by SOLUTION membership — captures flows/BR/actions, not just table-bound) ──
$visSols = Page "$api/solutions?`$select=solutionid,uniquename&`$filter=isvisible eq true and uniquename ne 'Default' and uniquename ne 'Active'"
$wfIdSet = @{}
foreach($s in $visSols){ try{ foreach($c in (Page "$api/solutioncomponents?`$select=objectid&`$filter=_solutionid_value eq $($s.solutionid) and componenttype eq 29")){ $wfIdSet[$c.objectid]=$true } }catch{} }
$wfIds = @($wfIdSet.Keys); $wf=@()
$wsel = "workflowid,name,category,mode,type,scope,statecode,primaryentity,ondemand,triggeroncreate,triggerondelete,triggeronupdateattributelist,description,clientdata,xaml"
for($i=0;$i -lt $wfIds.Count;$i+=20){ $chunk=$wfIds[$i..([Math]::Min($i+19,$wfIds.Count-1))]
  $f="type eq 1 and ($(($chunk|%{"workflowid eq $_"}) -join ' or '))"
  try{ foreach($w in (Page "$api/workflows?`$select=$wsel&`$filter=$(& $enc $f)")){
    $wf+=[pscustomobject]@{WorkflowId=$w.workflowid;Name=$w.name;Category=$w.category;Mode=$w.mode;Scope=$w.scope;StateCode=$w.statecode;PrimaryEntity=$w.primaryentity;OnDemand=$w.ondemand;TriggerCreate=$w.triggeroncreate;TriggerDelete=$w.triggerondelete;TriggerUpdateAttrs=$w.triggeronupdateattributelist;Description=$w.description;DefLength="$($w.xaml)$($w.clientdata)".Length;RefTokens=(Tok "$($w.xaml)$($w.clientdata)")} } }catch{ Write-Warning "wf chunk $i : $($_.Exception.Message)" }
}
Write-Host "workflows/flows (solution components): $($wf.Count)"; $wf|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutDir 'workflows.json') -Encoding UTF8

# ── ISV / solution catalog ───────────────────────────────────────────────────
$cat=Page "$api/solutions?`$select=uniquename,friendlyname,version,ismanaged,isvisible&`$expand=publisherid(`$select=friendlyname,customizationprefix)&`$filter=isvisible eq true"
$cat2=$cat|%{[pscustomobject]@{Unique=$_.uniquename;Friendly=$_.friendlyname;Version=$_.version;Managed=$_.ismanaged;Publisher=$_.publisherid.friendlyname;Prefix=$_.publisherid.customizationprefix}}
$cat2|ConvertTo-Json -Depth 4|Set-Content (Join-Path $OutDir 'solution_catalog.json') -Encoding UTF8

# ── security / org snapshot ──────────────────────────────────────────────────
function CntCol($logical,$set,$col,$filterXml){ $fil=if($filterXml){"<filter type='and'>$filterXml</filter>"}else{""}; $fx="<fetch aggregate='true'><entity name='$logical'><attribute name='$col' alias='c' aggregate='countcolumn'/>$fil</entity></fetch>"; try{[int](Invoke-RestMethod -Uri "$api/$set`?fetchXml=$(& $enc $fx)" -Headers (Hdr)).value[0].c}catch{-1} }
$bus=Page "$api/businessunits?`$select=name,_parentbusinessunitid_value"
$teams=Page "$api/teams?`$select=name,teamtype"
$roles=Page "$api/roles?`$select=name,ismanaged"
$fsp=Page "$api/fieldsecurityprofiles?`$select=name"
$sec=[pscustomobject]@{
  BusinessUnits=$bus.Count; RootBUs=@($bus|?{-not $_._parentbusinessunitid_value}).Count
  Teams=$teams.Count; TeamsByType=($teams|Group-Object teamtype|%{@{type=$_.Name;count=$_.Count}})
  RolesDistinct=@($roles|Select-Object -ExpandProperty name -Unique).Count; CustomRoles=@($roles|?{-not $_.ismanaged}|Select-Object -ExpandProperty name -Unique)
  FieldSecurityProfiles=@($fsp|Select-Object -ExpandProperty name)
  UsersEnabled=(CntCol 'systemuser' 'systemusers' 'systemuserid' "<condition attribute='isdisabled' operator='eq' value='false'/>")
}
$sec|ConvertTo-Json -Depth 5|Set-Content (Join-Path $OutDir 'security_org.json') -Encoding UTF8

# ── web resources (custom/unmanaged) ─────────────────────────────────────────
$wrType=@{'1'='HTML';'2'='CSS';'3'='JScript';'4'='XML';'5'='PNG';'6'='JPG';'7'='GIF';'8'='Silverlight';'9'='XSL';'10'='ICO';'11'='SVG';'12'='RESX'}
function NormKey($s){ if(-not $s){ return '' }; $n=($s.ToString().ToLower() -replace '\$webresource:','' -replace '[^a-z0-9]',''); if($n.EndsWith('js')){ $n=$n.Substring(0,$n.Length-2) }; $n }  # normalize + drop trailing 'js' for matching
$formLibs = @{}
foreach($f in $forms){ foreach($l in $f.Libraries){ $formLibs[(NormKey $l)] = $true } }   # web resources wired to a form
# custom web resources by PREFIX (the custom layer is often deployed MANAGED, so ismanaged is unreliable)
$wrPrefixes = @(@($ClientPrefix) + $IsvPrefixes | Where-Object { $_ })
$wrFilter = ($wrPrefixes | %{ "startswith(name,'$($_)_')" }) -join ' or '
$wr = Page "$api/webresourceset?`$select=name,displayname,webresourcetype,ismanaged&`$filter=$(& $enc $wrFilter)"
$wr2 = $wr | %{ [pscustomobject]@{ Name=$_.name; DisplayName=$_.displayname; Type=$wrType["$($_.webresourcetype)"]; IsManaged=$_.ismanaged; WiredToForm=[bool]$formLibs[(NormKey $_.name)] } }
Write-Host "web resources (custom by prefix): $($wr2.Count)  (JScript: $((@($wr2|?{$_.Type -eq 'JScript'})).Count))"
$wr2 | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'webresources.json') -Encoding UTF8

# ── model-driven apps ────────────────────────────────────────────────────────
$apps = Page "$api/appmodules?`$select=appmoduleid,name,uniquename,ismanaged,description"
$apps2 = $apps | %{ [pscustomobject]@{ Name=$_.name; Unique=$_.uniquename; IsManaged=$_.ismanaged; Description=$_.description } }
Write-Host "apps: $($apps2.Count)"
$apps2 | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'apps.json') -Encoding UTF8

# ── dashboards + charts ──────────────────────────────────────────────────────
$dash = Page "$api/systemforms?`$select=name,objecttypecode,ismanaged&`$filter=type eq 0"
$dash2 = $dash | %{ [pscustomobject]@{ Name=$_.name; Entity=$_.objecttypecode; IsManaged=$_.ismanaged } }
$charts = Page "$api/savedqueryvisualizations?`$select=name,primaryentitytypecode,ismanaged"
$charts2 = $charts | %{ [pscustomobject]@{ Name=$_.name; Entity=$_.primaryentitytypecode; IsManaged=$_.ismanaged } }
Write-Host "dashboards: $($dash2.Count); charts: $($charts2.Count)"
$dash2  | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'dashboards.json') -Encoding UTF8
$charts2| ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'charts.json') -Encoding UTF8

Write-Host "HARVEST_DONE -> $OutDir"
