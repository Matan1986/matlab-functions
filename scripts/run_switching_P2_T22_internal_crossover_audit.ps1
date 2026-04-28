# Narrow Switching P2 audit: 22K internal crossover / reorganization evidence.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$tablesDir = Join-Path $RepoRoot 'tables'
$reportsDir = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$inFreeze = Join-Path $tablesDir 'switching_P0_old_collapse_freeze_metrics.csv'
$inP0 = Join-Path $tablesDir 'switching_P0_effective_observables_values.csv'
$inP1 = Join-Path $tablesDir 'switching_P1_asymmetry_LR_values.csv'
$inFailureByT = Join-Path $tablesDir 'switching_old_collapse_apples_to_apples_failure_by_T.csv'

$outMetrics = Join-Path $tablesDir 'switching_P2_T22_crossover_metrics.csv'
$outNeighbors = Join-Path $tablesDir 'switching_P2_T22_crossover_neighbor_contrasts.csv'
$outStatus = Join-Path $tablesDir 'switching_P2_T22_crossover_status.csv'
$outReport = Join-Path $reportsDir 'switching_P2_T22_internal_crossover_audit.md'

function To-DoubleOrNaN($v) {
    if ($null -eq $v) { return [double]::NaN }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return [double]::NaN }
    $x = 0.0
    if ([double]::TryParse($s, [ref]$x)) { return [double]$x }
    $m = [regex]::Match($s, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?')
    if ($m.Success) {
        $y = 0.0
        if ([double]::TryParse($m.Value, [ref]$y)) { return [double]$y }
    }
    return [double]::NaN
}

function Median-Of([double[]]$vals) {
    $clean = @($vals | Where-Object { -not [double]::IsNaN($_) } | Sort-Object)
    if ($clean.Count -eq 0) { return [double]::NaN }
    $n = $clean.Count
    if (($n % 2) -eq 1) { return [double]$clean[($n - 1) / 2] }
    return [double](($clean[$n/2 - 1] + $clean[$n/2]) / 2.0)
}

function Mad-Of([double[]]$vals, [double]$center) {
    if ([double]::IsNaN($center)) { return [double]::NaN }
    $dev = @()
    foreach ($v in $vals) {
        if ([double]::IsNaN($v)) { continue }
        $dev += [Math]::Abs($v - $center)
    }
    return Median-Of ([double[]]$dev)
}

function Rank-ByDescending([double[]]$vals, [double]$target) {
    $sorted = @($vals | Where-Object { -not [double]::IsNaN($_) } | Sort-Object -Descending)
    if ($sorted.Count -eq 0 -or [double]::IsNaN($target)) { return $null }
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        if ($sorted[$i] -eq $target) { return ($i + 1) }
    }
    return $null
}

function Write-Missing([string]$reason) {
    @([pscustomobject]@{
        metric_name = 'MISSING_INPUT'
        t22_value = ''
        primary_median = ''
        primary_mad = ''
        robust_mad_score = ''
        z_score = ''
        rank_desc = ''
        n_primary = ''
        outlier_flag = ''
        note = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $outMetrics

    @([pscustomobject]@{
        metric_name = 'MISSING_INPUT'
        t22_value = ''
        neighbor_left_T = ''
        neighbor_left_value = ''
        neighbor_right_T = ''
        neighbor_right_value = ''
        delta_vs_left = ''
        delta_vs_right = ''
        mean_neighbor_value = ''
        delta_vs_neighbor_mean = ''
        note = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $outNeighbors

    $status = @(
        [pscustomobject]@{ verdict_key = 'P2_T22_INTERNAL_CROSSOVER_AUDIT_COMPLETE'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'P0_COLLAPSE_USED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'P0_EFFECTIVE_OBSERVABLES_USED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'P1_ASYMMETRY_USED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'T22_INCLUDED_IN_PRIMARY_DOMAIN'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'ABOVE_31P5_DIAGNOSTIC_ONLY'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'T22_COLLAPSE_OUTLIER'; verdict_value = 'UNKNOWN' }
        [pscustomobject]@{ verdict_key = 'T22_EFFECTIVE_OBSERVABLE_OUTLIER'; verdict_value = 'UNKNOWN' }
        [pscustomobject]@{ verdict_key = 'T22_ASYMMETRY_OUTLIER'; verdict_value = 'UNKNOWN' }
        [pscustomobject]@{ verdict_key = 'T22_INTERNAL_REORGANIZATION_SUPPORTED'; verdict_value = 'UNKNOWN' }
        [pscustomobject]@{ verdict_key = 'T22_EXCLUDED_FROM_PRIMARY_DOMAIN'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'MISSING_INPUT'; verdict_value = 'YES' }
        [pscustomobject]@{ verdict_key = 'MISSING_INPUT_REASON'; verdict_value = $reason }
    )
    $status | Export-Csv -NoTypeInformation -Encoding UTF8 $outStatus

    $lines = @(
        '# Switching P2 22K internal crossover / reorganization audit',
        '',
        'Audit could not run because required input artifacts are missing.',
        '',
        'Reason:',
        ('- ' + $reason),
        '',
        'Outputs were still written with explicit MISSING_INPUT status.'
    )
    $lines | Set-Content -Encoding UTF8 $outReport
}

if (-not (Test-Path $inFreeze)) { Write-Missing "Missing required input: $inFreeze"; exit 0 }
if (-not (Test-Path $inP0)) { Write-Missing "Missing required input: $inP0"; exit 0 }
if (-not (Test-Path $inP1)) { Write-Missing "Missing required input: $inP1"; exit 0 }

$freeze = @(Import-Csv $inFreeze)
$p0 = @(Import-Csv $inP0)
$p1 = @(Import-Csv $inP1)
if ($p0.Count -eq 0) { Write-Missing "P0 effective observables table is empty."; exit 0 }
if ($p1.Count -eq 0) { Write-Missing "P1 asymmetry table is empty."; exit 0 }

# Primary domain from P0 lock.
$primary = @($p0 | Where-Object { $_.in_primary_domain_T_lt_31p5 -eq 'YES' })
if ($primary.Count -eq 0) { Write-Missing 'No primary-domain rows found in P0 table.'; exit 0 }

$hasT22 = @($primary | Where-Object { [Math]::Abs((To-DoubleOrNaN $_.T_K) - 22.0) -lt 1.0e-9 }).Count -gt 0
if (-not $hasT22) { Write-Missing 'No T=22K row found in primary-domain data.'; exit 0 }

# Build helper maps
$p0ByT = @{}
foreach ($r in $p0) { $p0ByT[[string]([int](To-DoubleOrNaN $r.T_K))] = $r }
$p1ByT = @{}
foreach ($r in $p1) { $p1ByT[[string]([int](To-DoubleOrNaN $r.T_K))] = $r }

# Optional per-T collapse defect (preferred: failure_by_T variant PRIMARY_T_LT_31P5)
$defectByT = @{}
if (Test-Path $inFailureByT) {
    $rows = @(Import-Csv $inFailureByT | Where-Object { $_.variant_id -eq 'PRIMARY_T_LT_31P5' })
    foreach ($r in $rows) { $defectByT[[string]([int](To-DoubleOrNaN $r.T_K))] = To-DoubleOrNaN $r.curve_rmse_to_master }
} else {
    foreach ($r in $primary) {
        $defectByT[[string]([int](To-DoubleOrNaN $r.T_K))] = To-DoubleOrNaN $r.collapse_defect_vs_T_old_style
    }
}

# Metrics to audit
$metricSpecs = @(
    @{ name = 'collapse_defect_vs_T'; getter = { param($tKey,$p0r,$p1r) if ($defectByT.ContainsKey($tKey)) { $defectByT[$tKey] } else { [double]::NaN } } }
    @{ name = 'X_eff'; getter = { param($tKey,$p0r,$p1r) To-DoubleOrNaN $p0r.X_eff } }
    @{ name = 'W_I_mA'; getter = { param($tKey,$p0r,$p1r) To-DoubleOrNaN $p0r.W_I_mA } }
    @{ name = 'asym_WI'; getter = { param($tKey,$p0r,$p1r) if ($null -ne $p1r) { To-DoubleOrNaN $p1r.asym_WI } else { To-DoubleOrNaN $p0r.asym_WI } } }
    @{ name = 'asym_lr_sum'; getter = { param($tKey,$p0r,$p1r) if ($null -ne $p1r) { To-DoubleOrNaN $p1r.asym_lr_sum } else { To-DoubleOrNaN $p0r.asym_lr_sum } } }
    @{ name = 'S_peak'; getter = { param($tKey,$p0r,$p1r) To-DoubleOrNaN $p0r.S_peak } }
    @{ name = 'I_peak_mA'; getter = { param($tKey,$p0r,$p1r) To-DoubleOrNaN $p0r.I_peak_mA } }
)

$metricRows = New-Object System.Collections.ArrayList
$neighborRows = New-Object System.Collections.ArrayList

$primaryTemps = @($primary | ForEach-Object { To-DoubleOrNaN $_.T_K } | Sort-Object)
$t22 = 22.0
$leftNeighborT = @($primaryTemps | Where-Object { $_ -lt $t22 } | Sort-Object -Descending | Select-Object -First 1)[0]
$rightNeighborT = @($primaryTemps | Where-Object { $_ -gt $t22 } | Sort-Object | Select-Object -First 1)[0]
$t22Key = [string]([int]$t22)

$outlierFlags = @{}
foreach ($spec in $metricSpecs) {
    $m = [string]$spec.name
    $vals = @()
    foreach ($tr in $primaryTemps) {
        $k = [string]([int]$tr)
        $p0r = if ($p0ByT.ContainsKey($k)) { $p0ByT[$k] } else { $null }
        $p1r = if ($p1ByT.ContainsKey($k)) { $p1ByT[$k] } else { $null }
        $v = & $spec.getter $k $p0r $p1r
        if (-not [double]::IsNaN($v)) { $vals += [double]$v }
    }
    $p0_22 = $p0ByT[$t22Key]
    $p1_22 = if ($p1ByT.ContainsKey($t22Key)) { $p1ByT[$t22Key] } else { $null }
    $v22 = & $spec.getter $t22Key $p0_22 $p1_22

    $med = Median-Of ([double[]]$vals)
    $mad = Mad-Of ([double[]]$vals) $med
    $sd = if ($vals.Count -gt 1) {
        $mu = ($vals | Measure-Object -Average).Average
        $ss = 0.0
        foreach ($x in $vals) { $ss += ($x - $mu) * ($x - $mu) }
        [Math]::Sqrt($ss / ($vals.Count - 1))
    } else { [double]::NaN }
    $z = if ((-not [double]::IsNaN($sd)) -and ($sd -gt 0) -and (-not [double]::IsNaN($v22))) { ($v22 - (($vals | Measure-Object -Average).Average)) / $sd } else { [double]::NaN }
    $rms = if ((-not [double]::IsNaN($mad)) -and ($mad -gt 0) -and (-not [double]::IsNaN($v22))) { [Math]::Abs($v22 - $med) / (1.4826 * $mad) } else { [double]::NaN }
    $rank = Rank-ByDescending ([double[]]$vals) ([double]$v22)
    $outlier = if ((-not [double]::IsNaN($rms)) -and ($rms -ge 2.5)) { 'YES' } else { 'NO' }
    $outlierFlags[$m] = $outlier

    [void]$metricRows.Add([pscustomobject]@{
        metric_name = $m
        t22_value = $v22
        primary_median = $med
        primary_mad = $mad
        robust_mad_score = $rms
        z_score = $z
        rank_desc = $rank
        n_primary = $vals.Count
        outlier_flag = $outlier
        note = 'Primary domain only (T_K < 31.5); 22K kept in-domain.'
    })

    $leftKey = if ($null -ne $leftNeighborT) { [string]([int]$leftNeighborT) } else { '' }
    $rightKey = if ($null -ne $rightNeighborT) { [string]([int]$rightNeighborT) } else { '' }
    $leftP0 = if ($leftKey -and $p0ByT.ContainsKey($leftKey)) { $p0ByT[$leftKey] } else { $null }
    $leftP1 = if ($leftKey -and $p1ByT.ContainsKey($leftKey)) { $p1ByT[$leftKey] } else { $null }
    $rightP0 = if ($rightKey -and $p0ByT.ContainsKey($rightKey)) { $p0ByT[$rightKey] } else { $null }
    $rightP1 = if ($rightKey -and $p1ByT.ContainsKey($rightKey)) { $p1ByT[$rightKey] } else { $null }
    $vL = if ($null -ne $leftP0) { & $spec.getter $leftKey $leftP0 $leftP1 } else { [double]::NaN }
    $vR = if ($null -ne $rightP0) { & $spec.getter $rightKey $rightP0 $rightP1 } else { [double]::NaN }
    $meanNbr = if ((-not [double]::IsNaN($vL)) -and (-not [double]::IsNaN($vR))) { ($vL + $vR) / 2.0 } elseif (-not [double]::IsNaN($vL)) { $vL } else { $vR }
    [void]$neighborRows.Add([pscustomobject]@{
        metric_name = $m
        t22_value = $v22
        neighbor_left_T = $leftNeighborT
        neighbor_left_value = $vL
        neighbor_right_T = $rightNeighborT
        neighbor_right_value = $vR
        delta_vs_left = if ((-not [double]::IsNaN($v22)) -and (-not [double]::IsNaN($vL))) { $v22 - $vL } else { [double]::NaN }
        delta_vs_right = if ((-not [double]::IsNaN($v22)) -and (-not [double]::IsNaN($vR))) { $v22 - $vR } else { [double]::NaN }
        mean_neighbor_value = $meanNbr
        delta_vs_neighbor_mean = if ((-not [double]::IsNaN($v22)) -and (-not [double]::IsNaN($meanNbr))) { $v22 - $meanNbr } else { [double]::NaN }
        note = 'Nearest neighbors in primary T ladder.'
    })
}

$metricRows | Export-Csv -NoTypeInformation -Encoding UTF8 $outMetrics
$neighborRows | Export-Csv -NoTypeInformation -Encoding UTF8 $outNeighbors

# Leave-22K-out sensitivity from freeze metrics, if available.
$freezePrimary = @($freeze | Where-Object { $_.metric_id -eq 'PRIMARY_MEAN_INTERCURVE_STD_LT_31P5' } | Select-Object -First 1)
$freezeExcl22 = @($freeze | Where-Object { $_.metric_id -eq 'T22_EXCLUSION_SENSITIVITY_DEFECT_OPTIONAL' } | Select-Object -First 1)
$freezePrimaryDefect = if ($freezePrimary.Count -gt 0) { To-DoubleOrNaN $freezePrimary[0].numeric_value_text } else { [double]::NaN }
$freezeExclDefect = if ($freezeExcl22.Count -gt 0) { To-DoubleOrNaN $freezeExcl22[0].numeric_value_text } else { [double]::NaN }
$leave22Delta = if ((-not [double]::IsNaN($freezePrimaryDefect)) -and (-not [double]::IsNaN($freezeExclDefect))) { $freezeExclDefect - $freezePrimaryDefect } else { [double]::NaN }

$collapseOut = if ($outlierFlags.ContainsKey('collapse_defect_vs_T')) { $outlierFlags['collapse_defect_vs_T'] } else { 'NO' }
$effOut = if (@($outlierFlags['X_eff'], $outlierFlags['W_I_mA'], $outlierFlags['S_peak'], $outlierFlags['I_peak_mA']) -contains 'YES') { 'YES' } else { 'NO' }
$asymOut = if (@($outlierFlags['asym_WI'], $outlierFlags['asym_lr_sum']) -contains 'YES') { 'YES' } else { 'NO' }
$supported = if (@($collapseOut, $effOut, $asymOut) -contains 'YES') { 'YES' } else { 'NO' }

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'P2_T22_INTERNAL_CROSSOVER_AUDIT_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P0_COLLAPSE_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P0_EFFECTIVE_OBSERVABLES_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P1_ASYMMETRY_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'T22_INCLUDED_IN_PRIMARY_DOMAIN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ABOVE_31P5_DIAGNOSTIC_ONLY'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'T22_COLLAPSE_OUTLIER'; verdict_value = $collapseOut }
    [pscustomobject]@{ verdict_key = 'T22_EFFECTIVE_OBSERVABLE_OUTLIER'; verdict_value = $effOut }
    [pscustomobject]@{ verdict_key = 'T22_ASYMMETRY_OUTLIER'; verdict_value = $asymOut }
    [pscustomobject]@{ verdict_key = 'T22_INTERNAL_REORGANIZATION_SUPPORTED'; verdict_value = $supported }
    [pscustomobject]@{ verdict_key = 'T22_EXCLUDED_FROM_PRIMARY_DOMAIN'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'MISSING_INPUT'; verdict_value = 'NO' }
)
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $outStatus

$lines = @()
$lines += '# Switching P2 22K internal crossover / reorganization audit'
$lines += ''
$lines += 'Narrow P2 audit only: use locked P0/P1 canonical recipe layers to assess whether 22K behaves as an internal crossover/reorganization point within primary domain.'
$lines += 'No mechanism claim, no scaling claim, no geocanon/residual/PT-CDF/cross-module work.'
$lines += ''
$lines += '## Inputs used'
$lines += '- `tables/switching_P0_old_collapse_freeze_metrics.csv`'
$lines += '- `tables/switching_P0_effective_observables_values.csv`'
$lines += '- `tables/switching_P1_asymmetry_LR_values.csv`'
$failureInputTxt = '(not available, fallback to P0 per-T defect)'
if (Test-Path $inFailureByT) { $failureInputTxt = '(used)' }
$lines += ('- `tables/switching_old_collapse_apples_to_apples_failure_by_T.csv` ' + $failureInputTxt)
$lines += ''
$lines += '## Domain lock'
$lines += '- Primary domain: `T_K < 31.5`.'
$lines += '- `22K` remains included in primary domain with internal-crossover tag.'
$lines += '- `32/34K` remain above-transition diagnostic-only.'
$lines += ''
$lines += '## Diagnostics'
$lines += '- Metrics audited: collapse defect vs T, X_eff, W_I_mA, asym_WI, asym_lr_sum, S_peak, I_peak_mA.'
$lines += '- For each metric: 22K rank in primary domain, robust MAD score, z-score, nearest-neighbor contrasts.'
$lines += ('- Leave-22K-out sensitivity (from freeze metrics): primary=' + $freezePrimaryDefect + ', excl22=' + $freezeExclDefect + ', delta=' + $leave22Delta + '.')
$lines += ''
$lines += '## Classification summary'
$lines += ('- T22_COLLAPSE_OUTLIER = ' + $collapseOut)
$lines += ('- T22_EFFECTIVE_OBSERVABLE_OUTLIER = ' + $effOut)
$lines += ('- T22_ASYMMETRY_OUTLIER = ' + $asymOut)
$lines += ('- T22_INTERNAL_REORGANIZATION_SUPPORTED = ' + $supported)
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_P2_T22_crossover_metrics.csv`'
$lines += '- `tables/switching_P2_T22_crossover_neighbor_contrasts.csv`'
$lines += '- `tables/switching_P2_T22_crossover_status.csv`'
$lines += '- `reports/switching_P2_T22_internal_crossover_audit.md`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $statusRows) { $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`') }
$lines | Set-Content -Encoding UTF8 $outReport

Write-Host "P2 T22 crossover audit written: $outReport"

