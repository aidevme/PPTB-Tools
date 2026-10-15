<#
.SYNOPSIS
Scaffolds a new per-dataset sample-data folder (manifest + Import/Export/Remove trio +
README + starter CSVs) under SampleData/Datasets/<DatasetName>/.

.DESCRIPTION
Generates the per-dataset script trio defined by the Sample Data Management and Validation
SOP. Reads the templates from this skill's assets/templates/ folder, substitutes the dataset
name, and writes a self-contained, runnable dataset folder. Purely local file generation - no
Dataverse connection or authentication. The generated scripts dot-source the repo-root
`.scripts/Common-Functions.ps1` (provisioned by hso-dataverse-init-repo).

.PARAMETER DatasetName
PascalCase noun phrase, e.g. SubscriptionBilling, ContractCore. Becomes the folder name and
the verb suffix on every script (Import-<DatasetName>.ps1).

.PARAMETER SampleDataRoot
Path to the SampleData root in the consuming repo (default: ./SampleData relative to CWD).

.PARAMETER Force
Overwrite an existing dataset folder. Without it, the script refuses to clobber.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File ".claude/skills/hso-dataverse-sample-data/scripts/New-SampleDataset.ps1" -DatasetName SubscriptionBilling

.NOTES
Authority SOP: shared/dv/agent/wiki/sop/sample-data/sample-data-validation-workflow.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string]$DatasetName,
    [string]$SampleDataRoot = (Join-Path (Get-Location) 'SampleData'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$templateDir = Join-Path $PSScriptRoot '..\assets\templates'
if (-not (Test-Path $templateDir)) { throw "Template folder not found at $templateDir" }

$datasetDir = Join-Path (Join-Path $SampleDataRoot 'Datasets') $DatasetName
if ((Test-Path $datasetDir) -and -not $Force) { throw "Dataset folder already exists: $datasetDir. Use -Force to overwrite." }
New-Item -ItemType Directory -Force -Path $datasetDir | Out-Null

function Expand-Template([string]$templateFile, [string]$outFile) {
    $text = Get-Content (Join-Path $templateDir $templateFile) -Raw
    $text = $text -replace '__DATASET__', $DatasetName
    Set-Content -Path (Join-Path $datasetDir $outFile) -Value $text -Encoding UTF8 -NoNewline
    Write-Host "  [+] $outFile" -ForegroundColor Green
}

Write-Host "Scaffolding dataset '$DatasetName' -> $datasetDir" -ForegroundColor Cyan
Expand-Template 'manifest.psd1.template'        'manifest.psd1'
Expand-Template 'Import-Dataset.ps1.template'   "Import-$DatasetName.ps1"
Expand-Template 'Export-Dataset.ps1.template'   "Export-$DatasetName.ps1"
Expand-Template 'Remove-Dataset.ps1.template'   "Remove-$DatasetName.ps1"
Expand-Template 'dataset-README.md.template'    'README.md'

# Starter CSVs consistent with the manifest's two illustrative tables. Replace with real data.
$csv01 = "hso_contosoaccountid,hso_name,hso_tier_code`r`na0000001-0000-4000-8000-000000000001,Contoso Northwind,1"
$csv02 = "hso_contosocontractid,hso_name,hso_value,hso_startdate,_hso_account_id_value`r`nb0000001-0000-4000-8000-000000000001,Contoso MSA 2026,50000,2026-01-01,a0000001-0000-4000-8000-000000000001"
Set-Content -Path (Join-Path $datasetDir '01_ContosoAccounts.csv')  -Value $csv01 -Encoding UTF8
Set-Content -Path (Join-Path $datasetDir '02_ContosoContracts.csv') -Value $csv02 -Encoding UTF8
Write-Host "  [+] 01_ContosoAccounts.csv (starter)"  -ForegroundColor Green
Write-Host "  [+] 02_ContosoContracts.csv (starter)" -ForegroundColor Green

# Keep extraction snapshots out of git.
Set-Content -Path (Join-Path $datasetDir '.gitignore') -Value "TestResults/`r`n*.errors.log" -Encoding UTF8

# Sanity check on the shared module the generated scripts depend on.
$commonFunctions = Join-Path $SampleDataRoot '..\.scripts\Common-Functions.ps1'
if (-not (Test-Path $commonFunctions)) {
    Write-Warning "Repo-root .scripts\Common-Functions.ps1 was not found. Run hso-dataverse-init-repo to provision it before seeding."
}

Write-Host "`nDone. Next:" -ForegroundColor Cyan
Write-Host "  1. Edit manifest.psd1 - set the real tables, FieldTypes, Lookups, and Ids." -ForegroundColor Gray
Write-Host "  2. Replace the starter CSVs with the records to seed (PK column first, UTF-8)." -ForegroundColor Gray
Write-Host "  3. Dry-run:  .\Datasets\$DatasetName\Import-$DatasetName.ps1 -EnvironmentUrl your-env-url -Interactive -DryRun" -ForegroundColor Gray
