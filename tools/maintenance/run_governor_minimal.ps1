[CmdletBinding()]
param(
    [string]$Date = (Get-Date -Format "yyyy_MM_dd")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$inputDir = Join-Path $repoRoot ("reports\maintenance\agent_outputs\{0}" -f $Date)
$latestOutputPath = Join-Path $repoRoot "tables\maintenance_findings_latest.csv"
$summaryOutputPath = Join-Path $repoRoot "reports\maintenance\governor_summary_latest.md"

if (-not (Test-Path -LiteralPath $inputDir)) {
    Write-Output ("Input folder does not exist: {0}" -f $inputDir)
    Write-Output "Governor minimal exited cleanly (no input folder)."
    exit 0
}

$csvFiles = @(Get-ChildItem -LiteralPath $inputDir -Filter "*.csv" -File)
if ($csvFiles.Count -eq 0) {
    Write-Output ("No CSV files found in: {0}" -f $inputDir)
    Write-Output "Governor minimal exited cleanly (no input files)."
    exit 0
}

$allRows = New-Object System.Collections.Generic.List[object]
$filesLoaded = 0

foreach ($file in $csvFiles) {
    try {
        $rows = Import-Csv -LiteralPath $file.FullName
    } catch {
        Write-Warning ("Skipping unreadable CSV: {0}" -f $file.FullName)
        continue
    }

    foreach ($row in $rows) {
        $newRow = [ordered]@{}
        foreach ($property in $row.PSObject.Properties) {
            $newRow[$property.Name] = $property.Value
        }
        $newRow["source_file"] = $file.Name
        $allRows.Add([pscustomobject]$newRow)
    }

    $filesLoaded++
}

$rowsBeforeDedup = $allRows.Count
if ($rowsBeforeDedup -eq 0) {
    Write-Output ("Files loaded: {0}" -f $filesLoaded)
    Write-Output "Total rows before dedup: 0"
    Write-Output "Governor minimal exited cleanly (no rows loaded)."
    exit 0
}

$dedupMap = @{}
$dedupRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $allRows) {
    $findingId = ""
    $module = ""
    $severity = ""

    if ($row.PSObject.Properties.Name -contains "finding_id") { $findingId = [string]$row.finding_id }
    if ($row.PSObject.Properties.Name -contains "module") { $module = [string]$row.module }
    if ($row.PSObject.Properties.Name -contains "severity") { $severity = [string]$row.severity }

    $dedupKey = "{0}|{1}|{2}" -f $findingId.Trim(), $module.Trim(), $severity.Trim()
    if (-not $dedupMap.ContainsKey($dedupKey)) {
        $dedupMap[$dedupKey] = $true
        $dedupRows.Add($row)
    }
}

$rowsAfterDedup = $dedupRows.Count

$latestDir = Split-Path -Parent $latestOutputPath
if (-not (Test-Path -LiteralPath $latestDir)) {
    New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
}
$summaryDir = Split-Path -Parent $summaryOutputPath
if (-not (Test-Path -LiteralPath $summaryDir)) {
    New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
}

$dedupRows | Export-Csv -LiteralPath $latestOutputPath -NoTypeInformation -Encoding UTF8

$lowCount = @($dedupRows | Where-Object { ([string]$_.severity).ToUpperInvariant() -eq "LOW" }).Count
$mediumCount = @($dedupRows | Where-Object { ([string]$_.severity).ToUpperInvariant() -eq "MEDIUM" }).Count
$highCount = @($dedupRows | Where-Object { ([string]$_.severity).ToUpperInvariant() -eq "HIGH" }).Count

$sampleRows = @($dedupRows | Select-Object -First 5)
$sampleLines = New-Object System.Collections.Generic.List[string]
foreach ($row in $sampleRows) {
    $sev = [string]$row.severity
    $fid = ""
    $mod = ""
    if ($row.PSObject.Properties.Name -contains "finding_id") { $fid = [string]$row.finding_id }
    if ($row.PSObject.Properties.Name -contains "module") { $mod = [string]$row.module }
    $sampleLine = "- [{0}] {1} ({2})" -f $sev, $fid, $mod
    $sampleLines.Add($sampleLine)
}
if ($sampleLines.Count -eq 0) {
    $sampleLines.Add("- [N/A] N/A (N/A)")
}

$summaryText = @"
# Maintenance Governor Summary

Date: $Date

## Totals
- Total findings: $rowsAfterDedup

## By Severity
- LOW: $lowCount
- MEDIUM: $mediumCount
- HIGH: $highCount

## Sample Findings
$(($sampleLines -join [Environment]::NewLine))
"@

Set-Content -LiteralPath $summaryOutputPath -Value $summaryText -Encoding UTF8

Write-Output ("Files loaded: {0}" -f $filesLoaded)
Write-Output ("Total rows before dedup: {0}" -f $rowsBeforeDedup)
Write-Output ("Total rows after dedup: {0}" -f $rowsAfterDedup)
Write-Output ("Latest output: {0}" -f $latestOutputPath)
Write-Output ("Summary output: {0}" -f $summaryOutputPath)
