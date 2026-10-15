# lint:raw-invoke-backlog ADR 0014 open backlog - pre-existing drift, NOT an exemption.
# Calls the Dataverse Web API directly instead of the shared Invoke-DataverseApi, so it misses
# the invoker's hardening (notably -UseBasicParsing, without which Windows PowerShell 5.1 dies
# under -NonInteractive on a build agent). Convert per ADR 0014's open-backlog table, then
# DELETE this marker. Reported as WARN on every lint run until then.
<#
.SYNOPSIS  Harvest a security-role privilege matrix (client/custom roles) for the technical pack.
.DESCRIPTION
  For roles whose name contains -RoleNameContains (usually the client prefix, e.g. "Contoso"), lists each
  table-level privilege and its depth (User/BU/Parent-Child/Org) by joining roleprivileges -> privileges
  (privilege names encode access + entity). Writes security_roles.json (long form: Role/Entity/Access/Depth)
  and security_roles_summary.json (per-role counts incl. org-level write/delete = over-privilege signal).
  Read-only. Uses hso-shared-scripts auth. No client data embedded.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EnvironmentUrl,
    [Parameter(Mandatory)][string]$RoleNameContains,   # usually the engagement publisher prefix, e.g. Contoso
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$Interactive
)
$ErrorActionPreference='Stop'
$sharedDir = Join-Path $PSScriptRoot "..\..\hso-shared-scripts\scripts"
. "$sharedDir\Dataverse-Auth.ps1"; . "$sharedDir\Dataverse-WebApi.ps1"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$api="$($EnvironmentUrl.TrimEnd('/'))/api/data/v9.2"
$token=Get-DataverseToken -EnvironmentUrl $EnvironmentUrl -Interactive:$Interactive
if(-not $token){ throw "Auth failed for $EnvironmentUrl." }
$script:DvHeaders = Get-DataverseHeaders -Token $token -MaxPageSize 5000
function Hdr { $script:DvHeaders }
function Page($u){ $a=@(); while($u){ $r=Invoke-RestMethod -Uri $u -Headers (Hdr) -Method Get; if($r.value){$a+=$r.value}; $p=$r.PSObject.Properties['@odata.nextLink']; $u=if($p){$p.Value}else{$null} }; return $a }
$enc={param($s)[Uri]::EscapeDataString($s)}
$depth=@{'1'='User';'2'='BU';'4'='Parent-Child';'8'='Org'}

# privilege id -> name (one paged pull)
$privName=@{}
foreach($p in (Page "$api/privileges?`$select=privilegeid,name")){ $privName[$p.privilegeid]=$p.name }
Write-Host "privileges: $($privName.Count)"

# in-scope roles
$roles = Page "$api/roles?`$select=roleid,name,ismanaged&`$filter=$(& $enc "contains(name,'$RoleNameContains')")"
$roles = $roles | Sort-Object name -Unique
Write-Host "roles matching '$RoleNameContains': $((@($roles)).Count)"

$depthEnum=@{'Basic'='User';'Local'='BU';'Deep'='Parent-Child';'Global'='Org'}
$rx=[regex]'(?i)^prv(Create|Read|Write|Delete|Append|AppendTo|Assign|Share)(.+)$'
$rows=@(); $summary=@()
foreach($r in $roles){
    $rp=@()
    try { $rp = (Invoke-RestMethod -Uri "$api/RetrieveRolePrivilegesRole(RoleId=$($r.roleid))" -Headers (Hdr)).RolePrivileges } catch { Write-Warning "role $($r.name): $($_.Exception.Message)" }
    $cnt=0; $orgWD=0
    foreach($x in $rp){
        $nm=$privName[$x.PrivilegeId]; if(-not $nm){ continue }
        $m=$rx.Match($nm); if(-not $m.Success){ continue }
        $access=$m.Groups[1].Value; $entity=$m.Groups[2].Value.ToLower(); $d=$depthEnum["$($x.Depth)"]
        if(-not $d){ $d=[string]$x.Depth }
        $rows += [pscustomobject]@{ Role=$r.name; Entity=$entity; Access=$access; Depth=$d }
        $cnt++; if($d -eq 'Org' -and $access -in @('Write','Delete')){ $orgWD++ }
    }
    $summary += [pscustomobject]@{ Role=$r.name; IsManaged=$r.ismanaged; Privileges=$cnt; OrgLevelWriteDelete=$orgWD }
    Write-Host ("  {0,-28} privileges={1} org-write/delete={2}" -f $r.name,$cnt,$orgWD)
}
$rows | Sort-Object Role,Entity,Access | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'security_roles.json') -Encoding UTF8
$summary | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $OutDir 'security_roles_summary.json') -Encoding UTF8
Write-Host "SECROLES_DONE: $($rows.Count) privilege rows across $((@($roles)).Count) roles -> $OutDir"
