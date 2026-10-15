<#
.SYNOPSIS
    Reads all content from an Excel workbook and outputs it as plain text.

.DESCRIPTION
    Uses Excel COM automation to open a workbook and dump every sheet's cell
    content as pipe-delimited rows. Output is suitable for Claude to read and
    summarize as a discovery artifact digest.

    IMPORTANT: Microsoft Excel must be installed on the machine.

.PARAMETER Path
    Absolute path to the .xlsx or .xlsm file.

.PARAMETER MaxRows
    Maximum rows to output per sheet. Default 0 = all rows.

.EXAMPLE
    .\Read-ExcelContent.ps1 -Path "C:\Users\JohnDoe\OneDrive - HSO\Project\Backlog.xlsx"
    .\Read-ExcelContent.ps1 -Path "C:\...\Security Role Design.xlsx" -MaxRows 50
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxRows = 0
)

$resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Error "File not found: $Path"
    exit 1
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
    $wb = $excel.Workbooks.Open($resolvedPath.Path)

    foreach ($sheet in $wb.Sheets) {
        $used = $sheet.UsedRange
        $rowCount = $used.Rows.Count
        $colCount = $used.Columns.Count
        $limit = if ($MaxRows -gt 0) { [Math]::Min($rowCount, $MaxRows) } else { $rowCount }

        Write-Host ""
        Write-Host "=== Sheet: $($sheet.Name) === ($rowCount rows x $colCount cols)"

        for ($r = 1; $r -le $limit; $r++) {
            $row = @()
            for ($c = 1; $c -le $colCount; $c++) {
                $row += $used.Cells($r, $c).Text
            }
            Write-Host ($row -join " | ")
        }

        if ($MaxRows -gt 0 -and $rowCount -gt $MaxRows) {
            Write-Host "... ($($rowCount - $MaxRows) more rows omitted — rerun without -MaxRows to see all)"
        }
    }

    $wb.Close($false)
}
finally {
    $excel.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
