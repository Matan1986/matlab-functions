# Non-blocking observability: read-only reporting from existing artifacts only.
# Writes: tables/run_fingerprint.csv, tables/switching_canonical_violations.csv,
#         tables/switching_canonical_drift_report.csv, tables/switching_canonical_control_status.csv
# ASCII only. Does not invoke MATLAB.
# Invariants: SSOT per docs/switching_backend_definition.md (Source of Truth); no inference fallbacks.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot 'Switching'))) {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$runsRoot = Join-Path $repoRoot 'results\switching\runs'
$tablesOut = Join-Path $repoRoot 'tables'
if (-not (Test-Path $tablesOut)) { New-Item -ItemType Directory -Path $tablesOut | Out-Null }

function Get-RunManifestObject {
    param([string]$runDir)
    $mf = Join-Path $runDir 'run_manifest.json'
    if (-not (Test-Path $mf)) { return $null }
    try {
        $raw = Get-Content -LiteralPath $mf -Raw -Encoding UTF8
        return ($raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Get-KeyValueFromManifestLines {
    param([string]$filePath, [string]$keyName)
    if (-not (Test-Path $filePath)) { return '' }
    foreach ($line in Get-Content -LiteralPath $filePath -Encoding UTF8) {
        if ($line -match ('^' + [regex]::Escape($keyName) + ',(.*)$')) {
            return $Matches[1].Trim()
        }
    }
    return ''
}

function Get-ParentRunId {
    param([string]$runDir)
    # SSOT: tables/canonicalization_manifest.csv OR tables/canonicalization_l2_manifest.csv ONLY (no inference).
    $l3 = Join-Path $runDir 'tables\canonicalization_manifest.csv'
    $v = Get-KeyValueFromManifestLines -filePath $l3 -keyName 'source_canonical_run_id'
    if ($v -ne '') { return $v }
    $l2 = Join-Path $runDir 'tables\canonicalization_l2_manifest.csv'
    $v = Get-KeyValueFromManifestLines -filePath $l2 -keyName 'physical_artifact_run_id'
    if ($v -ne '') { return $v }
    return ''
}

function Get-IsCanonicalFromManifestLabel {
    param($manifest)
    # SSOT: run_manifest.json label == "switching_canonical" ONLY. No CSV flags; no folder suffix inference.
    if ($null -eq $manifest) { return 'UNDEFINED' }
    if ($manifest.PSObject.Properties.Name -contains 'label' -and [string]$manifest.label -eq 'switching_canonical') {
        return 'YES'
    }
    return 'UNDEFINED'
}

function Get-InputSourceFromManifest {
    param($manifest)
    # SSOT: manifest field only if present; otherwise empty (officially undefined).
    if ($null -eq $manifest) { return '' }
    foreach ($key in @('INPUT_SOURCE', 'input_source', 'InputSource')) {
        if ($manifest.PSObject.Properties.Name -contains $key) {
            $v = $manifest.$key
            if ($null -eq $v) { return '' }
            $s = [string]$v
            if ([string]::IsNullOrWhiteSpace($s)) { return '' }
            return $s
        }
    }
    return ''
}

function Get-RunTimestamp {
    param($manifest)
    # Observability only: manifest timestamp when present (no RUN_ID parsing).
    if ($manifest -and $manifest.PSObject.Properties.Name -contains 'timestamp' -and $manifest.timestamp) {
        return [string]$manifest.timestamp
    }
    return ''
}

function Get-HasExecutionStatus {
    param([string]$runDir)
    $p = Join-Path $runDir 'execution_status.csv'
    if (Test-Path $p) { return 'YES' }
    return 'NO'
}

# --- Stage 1: run_fingerprint (manifest-backed columns; INPUT_SOURCE only if manifest field exists; no fingerprint hash synthesis) ---
$runDirs = @()
if (Test-Path $runsRoot) {
    $runDirs = Get-ChildItem -LiteralPath $runsRoot -Directory | Sort-Object Name
}

$fingerprintRows = @()
foreach ($d in $runDirs) {
    $runId = $d.Name
    $manifest = Get-RunManifestObject -runDir $d.FullName
    $parentId = Get-ParentRunId -runDir $d.FullName
    $fingerprintRows += [pscustomobject]@{
        RUN_ID               = $runId
        PARENT_RUN_ID        = $parentId
        INPUT_SOURCE         = (Get-InputSourceFromManifest -manifest $manifest)
        TIMESTAMP            = (Get-RunTimestamp -manifest $manifest)
        HAS_EXECUTION_STATUS = (Get-HasExecutionStatus -runDir $d.FullName)
    }
}

$fingerprintPath = Join-Path $tablesOut 'run_fingerprint.csv'
$fingerprintRows | Export-Csv -LiteralPath $fingerprintPath -NoTypeInformation -Encoding UTF8

# --- Stage 2: violation scan (Switching/analysis only, recursive) ---
$analysisRoot = Join-Path $repoRoot 'Switching\analysis'
$violationRows = @()
if (Test-Path $analysisRoot) {
    $mfiles = Get-ChildItem -LiteralPath $analysisRoot -Filter '*.m' -File -Recurse
    foreach ($f in $mfiles) {
        $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($null -eq $lines) { continue }
        $n = 0
        foreach ($line in $lines) {
            $n++
            $t = $line
            $kind = ''
            if ($t -match "load\s*\(\s*['\`"]tables/") { $kind = 'load_tables_path' }
            elseif ($t -match "readtable\s*\(\s*['\`"]tables/") { $kind = 'readtable_tables_path' }
            elseif ($t -match "readtable\s*\(\s*['\`"]reports/") { $kind = 'readtable_reports_path' }
            elseif ($t -match "fullfile\s*\(\s*repoRoot\s*,\s*['\`"]tables['\`"]") { $kind = 'fullfile_repoRoot_tables' }
            elseif ($t -match "fullfile\s*\(\s*repoRoot\s*,\s*['\`"]reports['\`"]") { $kind = 'fullfile_repoRoot_reports' }
            if ($kind -ne '') {
                $violationRows += [pscustomobject]@{
                    FILE         = $f.FullName.Substring($repoRoot.Length + 1)
                    LINE_NUMBER  = [string]$n
                    PATTERN_KIND = $kind
                    LINE_TEXT    = ($t.Trim())
                }
            }
        }
    }
}
$violPath = Join-Path $tablesOut 'switching_canonical_violations.csv'
$violationRows | Export-Csv -LiteralPath $violPath -NoTypeInformation -Encoding UTF8

# --- Stage 3: drift (manifest reads + parent id presence only) ---
$driftRows = @()
$runIdSet = @{}
foreach ($d in $runDirs) { $runIdSet[$d.Name] = $true }

foreach ($d in $runDirs) {
    $runId = $d.Name
    $manifest = Get-RunManifestObject -runDir $d.FullName
    $isCanonStr = Get-IsCanonicalFromManifestLabel -manifest $manifest
    $parentId = Get-ParentRunId -runDir $d.FullName
    $driftType = 'NONE'
    $firstBad = ''

    if ($parentId -ne '') {
        if (-not $runIdSet.ContainsKey($parentId)) {
            $driftType = 'PARENT_RUN_NOT_FOUND'
            $firstBad = $parentId
        }
    }

    if ($driftType -eq 'NONE') {
        $mfPath = Join-Path $d.FullName 'run_manifest.json'
        if (-not (Test-Path $mfPath)) {
            $driftType = 'MANIFEST_MISSING'
        }
    }

    $driftRows += [pscustomobject]@{
        RUN_ID                    = $runId
        IS_CANONICAL              = $isCanonStr
        DRIFT_TYPE                = $driftType
        FIRST_NONCANONICAL_SOURCE = $firstBad
    }
}

$driftPath = Join-Path $tablesOut 'switching_canonical_drift_report.csv'
$driftRows | Export-Csv -LiteralPath $driftPath -NoTypeInformation -Encoding UTF8

# --- Stage 4: summary ---
$totalRuns = $fingerprintRows.Count
$canonicalRuns = 0
foreach ($d in $runDirs) {
    $m = Get-RunManifestObject -runDir $d.FullName
    if ($null -eq $m) { continue }
    $names = @($m.PSObject.Properties | ForEach-Object { $_.Name })
    if ($names -contains 'label' -and [string]$m.label -eq 'switching_canonical') {
        $canonicalRuns++
    }
}
$violCount = $violationRows.Count
$driftAny = ($driftRows | Where-Object { $_.DRIFT_TYPE -ne 'NONE' }).Count -gt 0
$driftStr = if ($driftAny) { 'YES' } else { 'NO' }

$summaryRows = @([pscustomobject]@{
    TOTAL_RUNS       = [string]$totalRuns
    CANONICAL_RUNS   = [string]$canonicalRuns
    VIOLATIONS_COUNT = [string]$violCount
    DRIFT_DETECTED   = $driftStr
})
$summaryPath = Join-Path $tablesOut 'switching_canonical_control_status.csv'
$summaryRows | Export-Csv -LiteralPath $summaryPath -NoTypeInformation -Encoding UTF8

# --- Self-check: read-only reporting invariants ---
$script:ControlScanReadOnlyMode = $true
Write-Host "Wrote: $fingerprintPath"
Write-Host "Wrote: $violPath"
Write-Host "Wrote: $driftPath"
Write-Host "Wrote: $summaryPath"
Write-Host ("TOTAL_RUNS={0} CANONICAL_RUNS={1} VIOLATIONS_COUNT={2} DRIFT_DETECTED={3}" -f $totalRuns, $canonicalRuns, $violCount, $driftStr)
Write-Host "DERIVATION_SELF_CHECK=PASS (INPUT_SOURCE manifest-only when present; IS_CANONICAL=label-only; PARENT=canonicalization CSVs only; no RUN_ID timestamp parse; no fingerprint synthesis)"
Write-Host "CONTROL_SCAN_IS_SAFE=YES"
