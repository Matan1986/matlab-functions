<#
.SYNOPSIS
  Detection-only guard: run registry rows vs snapshot linkage fields (no mutations).

.DESCRIPTION
  Reads analysis/knowledge/run_registry.csv, detects run-id and snapshot_* columns,
  writes tables/run_snapshot_coverage_latest.csv and
  reports/maintenance/run_snapshot_coverage_latest.md.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$registryPath = Join-Path $repoRoot "analysis\knowledge\run_registry.csv"
$snapshotIndexPath = Join-Path $repoRoot "snapshot_scientific_v3\30_runs_evidence\run_index.json"
$consistencyPath = Join-Path $repoRoot "snapshot_scientific_v3\00_entrypoints\consistency_check.json"
$tableOut = Join-Path $repoRoot "tables\run_snapshot_coverage_latest.csv"
$reportOut = Join-Path $repoRoot "reports\maintenance\run_snapshot_coverage_latest.md"

$idCandidates = @("run_id", "run_label", "label", "run_name", "id")
$moduleCandidates = @("module", "experiment")

function Get-RegistryCsvHeadersFromFirstLine {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    $first = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)[0]
    if ([string]::IsNullOrWhiteSpace($first)) { return @() }
    $m = [regex]::Matches($first, '"((?:[^"]|"")*)"')
    if ($m.Count -gt 0) {
        return @($m | ForEach-Object { $_.Groups[1].Value -replace '""', '"' })
    }
    return @($first.Split(','))
}

function Test-TruthySnapshotHasEntry {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $v = $Value.Trim()
    switch -Regex ($v.ToLowerInvariant()) {
        "^1$" { return $true }
        "^true$" { return $true }
        "^yes$" { return $true }
        "^y$" { return $true }
        default { return $false }
    }
}

function Test-NonEmptyLinkageValue {
    param([string]$Value)
    return -not [string]::IsNullOrWhiteSpace($Value)
}

function Get-RowSnapshotLinkagePresent {
    param(
        [psobject]$Row,
        [string[]]$SnapshotColumnNames,
        [string]$HasEntryColumnName
    )
    if ($SnapshotColumnNames.Count -eq 0) {
        return $false
    }
    if ($HasEntryColumnName -and ($SnapshotColumnNames -contains $HasEntryColumnName)) {
        $hv = [string]$Row.$HasEntryColumnName
        if (Test-TruthySnapshotHasEntry -Value $hv) {
            return $true
        }
    }
    foreach ($col in $SnapshotColumnNames) {
        if ($col -eq $HasEntryColumnName) { continue }
        $cell = [string]$Row.$col
        if (Test-NonEmptyLinkageValue -Value $cell) {
            return $true
        }
    }
    return $false
}

$registryReadable = $false
$rows = @()
$headers = @()
$idCol = $null
$moduleCol = $null
$snapshotCols = @()
$hasEntryCol = $null
$importError = $null

if (-not (Test-Path -LiteralPath $registryPath)) {
    $importError = "Registry file not found."
} else {
    try {
        $rows = @(Import-Csv -LiteralPath $registryPath)
        $registryReadable = $true
    } catch {
        $importError = $_.Exception.Message
        $registryReadable = $false
    }
}

if ($registryReadable -and $rows.Count -gt 0) {
    $headers = @($rows[0].PSObject.Properties.Name)
} elseif ($registryReadable) {
    $headers = @(Get-RegistryCsvHeadersFromFirstLine -Path $registryPath)
}

if ($headers.Count -gt 0) {
    foreach ($c in $idCandidates) {
        if ($headers -contains $c) {
            $idCol = $c
            break
        }
    }
    foreach ($c in $moduleCandidates) {
        if ($headers -contains $c) {
            $moduleCol = $c
            break
        }
    }
    $snapList = New-Object System.Collections.Generic.List[string]
    if ($headers -contains "snapshot_has_entry") {
        $hasEntryCol = "snapshot_has_entry"
        [void]$snapList.Add("snapshot_has_entry")
    }
    foreach ($h in $headers) {
        if ($h -eq "snapshot_has_entry") { continue }
        if ($h.StartsWith("snapshot_", [System.StringComparison]::Ordinal)) {
            [void]$snapList.Add($h)
        }
    }
    $snapshotCols = @($snapList | Select-Object -Unique)
}

$snapshotIndexExists = Test-Path -LiteralPath $snapshotIndexPath
$consistencyExists = Test-Path -LiteralPath $consistencyPath

$snapshotLinkageColumnsFound = ($snapshotCols.Count -gt 0)
$linkageColsFound = $snapshotLinkageColumnsFound

$outputRows = New-Object System.Collections.Generic.List[object]
$missingSamples = New-Object System.Collections.Generic.List[string]

$totalRows = 0
$coveredRows = 0
$missingRows = 0
$unknownSchemaRows = 0
$health = "UNKNOWN"
$stalenessNote = ""

if (-not $registryReadable) {
    $stalenessNote = if ($importError) { $importError } else { "Registry missing or unreadable." }
} elseif ($rows.Count -eq 0) {
    $stalenessNote = "Registry readable but contains no data rows (header-only or empty)."
} elseif (-not $idCol) {
    $stalenessNote = "No recognized run identifier column; schema insufficient."
    $unknownSchemaRows = $rows.Count
    foreach ($r in $rows) {
        $modVal = ""
        if ($moduleCol) { $modVal = [string]$r.$moduleCol }
        [void]$outputRows.Add([pscustomobject][ordered]@{
            run_id = ""
            module = $modVal
            snapshot_has_entry = ""
            snapshot_linkage_present = "FALSE"
            coverage_status = "UNKNOWN_SCHEMA"
            notes = "Run ID column not detected among candidates."
        })
    }
} elseif (-not $linkageColsFound) {
    $stalenessNote = "No snapshot_* or snapshot_has_entry columns; cannot assess linkage."
    $totalRows = $rows.Count
    $unknownSchemaRows = $totalRows
    foreach ($r in $rows) {
        $rid = [string]$r.$idCol
        $modVal = ""
        if ($moduleCol) { $modVal = [string]$r.$moduleCol }
        [void]$outputRows.Add([pscustomobject][ordered]@{
            run_id = $rid
            module = $modVal
            snapshot_has_entry = ""
            snapshot_linkage_present = "FALSE"
            coverage_status = "UNKNOWN_SCHEMA"
            notes = "No snapshot linkage columns in registry header."
        })
    }
} else {
    $totalRows = $rows.Count
    foreach ($r in $rows) {
        $rid = [string]$r.$idCol
        $modVal = ""
        if ($moduleCol) { $modVal = [string]$r.$moduleCol }
        $hasEntryVal = ""
        if ($hasEntryCol) {
            $hasEntryVal = [string]$r.$hasEntryCol
        }
        $present = Get-RowSnapshotLinkagePresent -Row $r -SnapshotColumnNames $snapshotCols -HasEntryColumnName $hasEntryCol
        $presentStr = if ($present) { "TRUE" } else { "FALSE" }
        if ($present) {
            $coveredRows++
            $status = "COVERED"
            $notes = "At least one snapshot linkage field populated or snapshot_has_entry truthy."
        } else {
            $missingRows++
            $status = "MISSING"
            $notes = "No truthy snapshot_has_entry and no non-empty other snapshot_* fields."
            if ($missingSamples.Count -lt 20) {
                $missingSamples.Add($rid)
            }
        }
        [void]$outputRows.Add([pscustomobject][ordered]@{
            run_id = $rid
            module = $modVal
            snapshot_has_entry = $hasEntryVal
            snapshot_linkage_present = $presentStr
            coverage_status = $status
            notes = $notes
        })
    }

    $pct = 0.0
    if ($totalRows -gt 0) {
        $pct = [math]::Round(100.0 * $coveredRows / $totalRows, 2)
    }
    if ($pct -ge 90.0) {
        $health = "GOOD"
    } elseif ($pct -ge 50.0) {
        $health = "PARTIAL"
    } else {
        $health = "WEAK"
    }

    $stalenessNote = "Coverage {0}% ({1} of {2} rows with linkage)." -f $pct, $coveredRows, $totalRows
    if ($snapshotIndexExists -and (Test-Path -LiteralPath $registryPath)) {
        $regTime = (Get-Item -LiteralPath $registryPath).LastWriteTimeUtc
        $idxTime = (Get-Item -LiteralPath $snapshotIndexPath).LastWriteTimeUtc
        if ($regTime -gt $idxTime) {
            $stalenessNote += " Registry newer than run_index.json (UTC); snapshot index may be stale relative to registry."
        }
    }
}

$tableDir = Split-Path -Parent $tableOut
if (-not (Test-Path -LiteralPath $tableDir)) {
    New-Item -ItemType Directory -Path $tableDir -Force | Out-Null
}
$reportDir = Split-Path -Parent $reportOut
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

if ($outputRows.Count -eq 0) {
    $headerOnly = "run_id,module,snapshot_has_entry,snapshot_linkage_present,coverage_status,notes"
    Set-Content -LiteralPath $tableOut -Value $headerOnly -Encoding UTF8
} else {
    $outputRows | Select-Object run_id, module, snapshot_has_entry, snapshot_linkage_present, coverage_status, notes |
        Export-Csv -LiteralPath $tableOut -NoTypeInformation -Encoding UTF8
}

$coveragePctDisplay = "N/A"
if ($registryReadable -and $idCol -and $linkageColsFound -and $totalRows -gt 0) {
    $coveragePctDisplay = ("{0}%" -f ([math]::Round(100.0 * $coveredRows / $totalRows, 2)))
}

$runRegistryReadableVerdict = if ($registryReadable) { "YES" } else { "NO" }
$snapshotLinkageColsVerdict = if ($snapshotLinkageColumnsFound) { "YES" } else { "NO" }
$snapshotIndexVerdict = if ($snapshotIndexExists) { "YES" } else { "NO" }
$consistencyVerdict = if ($consistencyExists) { "YES" } else { "NO" }

$healthVerdict = switch ($health) {
    "GOOD" { "GOOD" }
    "PARTIAL" { "PARTIAL" }
    "WEAK" { "WEAK" }
    default { "UNKNOWN" }
}

$missingSampleBlock = if ($missingSamples.Count -eq 0) {
    "(none in sample cap; either all covered or schema unknown.)"
} else {
    ($missingSamples | ForEach-Object { "- ``$_``" }) -join [Environment]::NewLine
}

$linkageColList = if ($snapshotCols.Count -eq 0) { "(none)" } else { $snapshotCols -join ", " }

$fence3 = [string]::new([char]96, 3)
$verdictBlock = @(
    ($fence3 + "text"),
    ("RUN_REGISTRY_READABLE = {0}" -f $runRegistryReadableVerdict),
    ("SNAPSHOT_LINKAGE_COLUMNS_FOUND = {0}" -f $snapshotLinkageColsVerdict),
    ("SNAPSHOT_INDEX_EXISTS = {0}" -f $snapshotIndexVerdict),
    ("CONSISTENCY_CHECK_EXISTS = {0}" -f $consistencyVerdict),
    ("RUN_SNAPSHOT_COVERAGE_HEALTH = {0}" -f $healthVerdict),
    "GUARD_COMPLETED = YES",
    $fence3
) -join [Environment]::NewLine

$md = @"
# Run Snapshot Coverage Guard

## Summary

- Registry rows read: **$($rows.Count)**
- Run ID column used: **$(if ($idCol) { $idCol } else { '(not detected)' })**
- Module column used: **$(if ($moduleCol) { $moduleCol } else { '(none)' })**
- Snapshot linkage columns: **$linkageColList**
- Rows with linkage present (COVERED): **$coveredRows**
- Rows missing linkage (MISSING): **$missingRows**
- Rows UNKNOWN_SCHEMA: **$unknownSchemaRows**
- Coverage (linkage present / total): **$coveragePctDisplay**
- ``RUN_SNAPSHOT_COVERAGE_HEALTH`` classification: **$healthVerdict**

## Inputs

| Path | Role |
|------|------|
| ``$registryPath`` | Run registry (read-only) |
| ``$snapshotIndexPath`` | Optional scientific snapshot run index |
| ``$consistencyPath`` | Optional consistency check artifact |

## Coverage Metrics

| Metric | Value |
|--------|-------|
| Total registry rows | $($rows.Count) |
| Linkage columns detected | $($snapshotCols.Count) |
| COVERED | $coveredRows |
| MISSING | $missingRows |
| UNKNOWN_SCHEMA | $unknownSchemaRows |
| Coverage % | $coveragePctDisplay |

## Missing Coverage Sample

Up to 20 ``run_id`` values with ``MISSING`` status:

$missingSampleBlock

## Interpretation

This guard is **detection-only**. It does not modify the registry, snapshots, or knowledge exports.

$stalenessNote

## Final Verdicts

$verdictBlock

"@

Set-Content -LiteralPath $reportOut -Value $md.TrimEnd() -Encoding UTF8

Write-Output ("Registry: {0}" -f $registryPath)
Write-Output ("Rows read: {0}" -f $rows.Count)
Write-Output ("Linkage columns: {0}" -f $linkageColList)
Write-Output ("Coverage: {0}" -f $coveragePctDisplay)
Write-Output ("Table: {0}" -f $tableOut)
Write-Output ("Report: {0}" -f $reportOut)
exit 0
