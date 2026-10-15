<#
.SYNOPSIS  Derive the standard system-review findings from harvested metadata JSON.
.DESCRIPTION
  Finding 1: searchable custom fields not in the "referenced" set (forms/views[/workflows/code], configurable).
  Finding 2: classic workflows (category 0) with a migrate-to-flow recommendation; flags dialogs.
  Finding 3: duplicate active main forms (managed vs unmanaged) + app-inclusion (true in-app duplicates).
  Segments every finding by layer using -ClientPrefix / -IsvPrefixes. Outputs CSV + JSON registers.
  Part of hso-analyze-system-review. No client data embedded.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MetaDir,
    [Parameter(Mandatory)][string]$OutDir,
    [string]$ClientPrefix,
    [string[]]$IsvPrefixes=@(),
    [string]$CodeTokensPath,
    [ValidateSet('forms','views','workflows','code')][string[]]$ReferencedSources=@('forms','views','workflows','code')
)
$ErrorActionPreference='Stop'; New-Item -ItemType Directory -Force -Path $OutDir|Out-Null
$entities=Get-Content "$MetaDir\entities.json" -Raw|ConvertFrom-Json
$attrs   =Get-Content "$MetaDir\attributes.json" -Raw|ConvertFrom-Json
$forms   =Get-Content "$MetaDir\forms.json" -Raw|ConvertFrom-Json
$views   =Get-Content "$MetaDir\views.json" -Raw|ConvertFrom-Json
$wf      =if(Test-Path "$MetaDir\workflows.json"){Get-Content "$MetaDir\workflows.json" -Raw|ConvertFrom-Json}else{@()}
$disp=@{}; foreach($e in $entities){$disp[$e.LogicalName]=$e.DisplayName}
function Layer($f){ if($ClientPrefix -and $f -like "$ClientPrefix`_*"){'Client custom'} elseif(($IsvPrefixes|?{$f -like "$_`_*"})){'ISV'} elseif($f -match '^(msdyn_|adx_|msfp_|msa_|mspp_)'){'Microsoft'} else {'OOTB/base'} }

# referenced universe
$ref=New-Object System.Collections.Generic.HashSet[string]
if($ReferencedSources -contains 'forms'){ foreach($x in $forms){ foreach($t in $x.DataFields){[void]$ref.Add([string]$t)}; foreach($t in $x.RefTokens){[void]$ref.Add([string]$t)} } }
if($ReferencedSources -contains 'views'){ foreach($x in $views){ foreach($t in $x.RefTokens){[void]$ref.Add([string]$t)} } }
if($ReferencedSources -contains 'workflows'){ foreach($x in $wf){ foreach($t in $x.RefTokens){[void]$ref.Add([string]$t)} } }
if(($ReferencedSources -contains 'code') -and $CodeTokensPath -and (Test-Path $CodeTokensPath)){ foreach($l in Get-Content $CodeTokensPath){ if($l.Trim()){[void]$ref.Add($l.Trim().ToLower())} } }
Write-Host "referenced tokens: $($ref.Count) (sources: $($ReferencedSources -join ','))"

# FINDING 1
$cand=$attrs|?{$_.IsCustom -and $_.SearchableAF -and [string]::IsNullOrEmpty([string]$_.AttributeOf) -and $_.LogicalName -notlike '*_base' -and $_.Type -notin @('Virtual')}
$f1=foreach($a in $cand){ if(-not $ref.Contains([string]$a.LogicalName.ToLower())){ [pscustomobject]@{Entity=$a.Entity;EntityDisplay=$disp[$a.Entity];Field=$a.LogicalName;FieldDisplay=$a.DisplayName;Type=$a.Type;Layer=(Layer $a.LogicalName);IsManaged=$a.IsManaged} } }
$f1=@($f1|Sort-Object Layer,Entity,Field)
$f1|Export-Csv "$OutDir\finding1_unused_searchable_fields.csv" -NoTypeInformation -Encoding UTF8
$f1|ConvertTo-Json -Depth 4|Set-Content "$OutDir\finding1_unused_searchable_fields.json" -Encoding UTF8
Write-Host "F1 unused searchable: $($f1.Count)"; $f1|Group-Object Layer|Sort-Object Count -Descending|%{Write-Host ("   {0,-14}: {1}" -f $_.Name,$_.Count)}

# FINDING 2
$modeN=@{'0'='Background (async)';'1'='Real-time (sync)'}
$classic=$wf|?{$_.Category -eq 0}
$f2=foreach($w in $classic){ $isIsv=($IsvPrefixes|?{$w.PrimaryEntity -like "$_`_*"})
  $rec= if($w.StateCode -ne 1){'Inactive — review for deletion'} elseif($w.Mode -eq 0){'Migrate to Power Automate (background)'} elseif($w.OnDemand){'Migrate to Power Automate (on-demand/instant flow)'} else{'Review — real-time; flow vs business rule vs plugin'}
  [pscustomobject]@{Name=$w.Name;PrimaryEntity=$w.PrimaryEntity;Active=($w.StateCode -eq 1);Mode=$modeN["$($w.Mode)"];OnDemand=$w.OnDemand;DefSize=$w.DefLength;Recommendation=$rec} }
$f2=@($f2|Sort-Object @{e='Active';Descending=$true},Name)
$f2|Export-Csv "$OutDir\finding2_classic_workflows.csv" -NoTypeInformation -Encoding UTF8
$f2|ConvertTo-Json -Depth 4|Set-Content "$OutDir\finding2_classic_workflows.json" -Encoding UTF8
$dialogs=@($wf|?{$_.Category -eq 1}).Count
Write-Host "F2 classic workflows: $($classic.Count) (active $((@($classic|?{$_.StateCode -eq 1})).Count)); deprecated dialogs: $dialogs"

# FINDING 3
$mainActive=$forms|?{$_.Type -eq 2 -and $_.ActivationState -eq 1}
$dups=$mainActive|Group-Object Entity|?{$_.Count -gt 1}
$f3=foreach($g in $dups){ $inApp=@($g.Group|?{$_.InApp}); foreach($frm in ($g.Group|Sort-Object @{e='IsDefault';Descending=$true},Name)){
  [pscustomobject]@{Entity=$g.Name;EntityDisplay=$disp[$g.Name];ActiveMainForms=$g.Count;InAppForms=$inApp.Count;FormName=$frm.Name;IsDefault=$frm.IsDefault;IsManaged=$frm.IsManaged;InApp=$frm.InApp;FieldCount=$frm.FieldCount} } }
$f3=@($f3|Sort-Object @{e='InAppForms';Descending=$true},@{e='ActiveMainForms';Descending=$true},Entity,FormName)
$f3|Export-Csv "$OutDir\finding3_duplicate_forms.csv" -NoTypeInformation -Encoding UTF8
$f3|ConvertTo-Json -Depth 4|Set-Content "$OutDir\finding3_duplicate_forms.json" -Encoding UTF8
$inAppDup=@($dups|?{ @($_.Group|?{$_.InApp}).Count -gt 1 }).Count
Write-Host "F3 tables w/ >1 active main form: $($dups.Count); of those, >1 form IN-APP (true selector clutter): $inAppDup"
Write-Host "FINDINGS_DONE -> $OutDir"
