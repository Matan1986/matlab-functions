# Narrow Switching P1 asymmetry / LR half-width canonical replay.
# Scope: canonical S + P0 values parity, legacy artifact search, status/report outputs.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$tablesDir = Join-Path $RepoRoot 'tables'
$reportsDir = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$canonicalRunId = 'run_2026_04_03_000147_switching_canonical'
$canonicalSPath = Join-Path $RepoRoot "results/switching/runs/$canonicalRunId/tables/switching_canonical_S_long.csv"
$p0Path = Join-Path $tablesDir 'switching_P0_effective_observables_values.csv'

$valuesPath = Join-Path $tablesDir 'switching_P1_asymmetry_LR_values.csv'
$legacyCompPath = Join-Path $tablesDir 'switching_P1_asymmetry_LR_legacy_comparison.csv'
$statusPath = Join-Path $tablesDir 'switching_P1_asymmetry_LR_status.csv'
$reportPath = Join-Path $reportsDir 'switching_P1_asymmetry_LR_replay.md'

function To-DoubleOrNaN($v) {
    if ($null -eq $v) { return [double]::NaN }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return [double]::NaN }
    $x = 0.0
    if ([double]::TryParse($s, [ref]$x)) { return [double]$x }
    return [double]::NaN
}

function Interp-Crossing([double]$x1,[double]$y1,[double]$x2,[double]$y2,[double]$target) {
    if ($x2 -eq $x1) { return $x1 }
    if ($y2 -eq $y1) { return (($x1 + $x2) / 2.0) }
    $t = ($target - $y1) / ($y2 - $y1)
    return ($x1 + $t * ($x2 - $x1))
}

function Build-EmptyOutputs([string]$reason) {
    @([pscustomobject]@{
        T_K = ''
        I_peak_mA = ''
        S_peak = ''
        left_half_current_mA = ''
        right_half_current_mA = ''
        width_fwhm_mA = ''
        W_I_mA = ''
        width_chosen_mA = ''
        asym_WI = ''
        asym_lr_sum = ''
        in_primary_domain_T_lt_31p5 = ''
        above_31p5_diagnostic_only = ''
        T22_internal_crossover_candidate_tag = ''
        replay_status = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $valuesPath

    @([pscustomobject]@{
        comparison_status = 'NOT_PERFORMED'
        reason = $reason
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $legacyCompPath

    $statusRows = @(
        [pscustomobject]@{ verdict_key = 'P1_ASYMMETRY_LR_REPLAY_COMPLETE'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'CANONICAL_S_USED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'P0_EFFECTIVE_OBSERVABLES_USED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'NUMERIC_VALUES_WRITTEN'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'LEGACY_ASYMMETRY_ARTIFACTS_FOUND'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_CHECK_PERFORMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_PASSED'; verdict_value = 'NOT_PERFORMED' }
        [pscustomobject]@{ verdict_key = 'T22_INCLUDED_IN_PRIMARY_DOMAIN'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'ABOVE_31P5_DIAGNOSTIC_ONLY'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'ASYMMETRY_CANONICAL_RECIPE_VALIDATED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
        [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
    )
    $statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusPath

    $lines = @(
        '# Switching P1 asymmetry / LR half-width replay',
        '',
        'Replay did not execute due to missing required inputs.',
        '',
        'Reason:',
        ('- ' + $reason),
        '',
        'Required outputs were still written as mandated.'
    )
    $lines | Set-Content -Encoding UTF8 $reportPath
}

if (-not (Test-Path $canonicalSPath)) {
    Build-EmptyOutputs "Missing canonical S_long: $canonicalSPath"
    Write-Host "P1 asymmetry replay outputs written (input missing)."
    exit 0
}
if (-not (Test-Path $p0Path)) {
    Build-EmptyOutputs "Missing P0 effective observables table: $p0Path"
    Write-Host "P1 asymmetry replay outputs written (input missing)."
    exit 0
}

$canonical = @(Import-Csv $canonicalSPath)
$p0 = @(Import-Csv $p0Path)
if ($canonical.Count -eq 0) {
    Build-EmptyOutputs "Canonical S_long table is empty."
    Write-Host "P1 asymmetry replay outputs written (empty canonical)."
    exit 0
}
if ($p0.Count -eq 0) {
    Build-EmptyOutputs "P0 effective observables table is empty."
    Write-Host "P1 asymmetry replay outputs written (empty P0)."
    exit 0
}

# Recompute asymmetry/LR quantities from canonical S map.
$replayRows = New-Object System.Collections.ArrayList
$groups = $canonical | Group-Object T_K
foreach ($g in $groups) {
    $t = To-DoubleOrNaN $g.Name
    $pts = @($g.Group | Sort-Object { To-DoubleOrNaN $_.current_mA })
    if ($pts.Count -lt 2) { continue }

    $iPeak = [double]::NaN
    $sPeak = -1.0e300
    foreach ($p in $pts) {
        $c = To-DoubleOrNaN $p.current_mA
        $s = To-DoubleOrNaN $p.S_percent
        if ($s -gt $sPeak) { $sPeak = [double]$s; $iPeak = [double]$c }
    }

    $half = 0.5 * $sPeak
    $leftCross = New-Object System.Collections.ArrayList
    $rightCross = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt ($pts.Count - 1); $i++) {
        $x1 = To-DoubleOrNaN $pts[$i].current_mA
        $x2 = To-DoubleOrNaN $pts[$i+1].current_mA
        $y1 = To-DoubleOrNaN $pts[$i].S_percent
        $y2 = To-DoubleOrNaN $pts[$i+1].S_percent
        $crosses = (($y1 -eq $half) -or ($y2 -eq $half) -or ((($y1 - $half) * ($y2 - $half)) -lt 0))
        if (-not $crosses) { continue }
        $xh = Interp-Crossing $x1 $y1 $x2 $y2 $half
        if ($xh -le $iPeak) { [void]$leftCross.Add($xh) }
        if ($xh -ge $iPeak) { [void]$rightCross.Add($xh) }
    }
    $left = if ($leftCross.Count -gt 0) { [double](($leftCross | Measure-Object -Maximum).Maximum) } else { [double]::NaN }
    $right = if ($rightCross.Count -gt 0) { [double](($rightCross | Measure-Object -Minimum).Minimum) } else { [double]::NaN }
    $widthFwhm = if ((-not [double]::IsNaN($left)) -and (-not [double]::IsNaN($right)) -and ($right -ge $left)) { [double]($right - $left) } else { [double]::NaN }
    $wL = if (-not [double]::IsNaN($left)) { [double]($iPeak - $left) } else { [double]::NaN }
    $wR = if (-not [double]::IsNaN($right)) { [double]($right - $iPeak) } else { [double]::NaN }
    $asymWI = if ((-not [double]::IsNaN($widthFwhm)) -and ($widthFwhm -ne 0) -and (-not [double]::IsNaN($wL)) -and (-not [double]::IsNaN($wR))) { [double](($wR - $wL) / $widthFwhm) } else { [double]::NaN }
    $asymLrSum = if ((-not [double]::IsNaN($wL)) -and (-not [double]::IsNaN($wR)) -and (($wR + $wL) -ne 0)) { [double](($wR - $wL) / ($wR + $wL)) } else { [double]::NaN }

    $inPrimary = ($t -lt 31.5)
    [void]$replayRows.Add([pscustomobject]@{
        T_K                                  = $t
        I_peak_mA                            = $iPeak
        S_peak                               = $sPeak
        left_half_current_mA                 = $left
        right_half_current_mA                = $right
        width_fwhm_mA                        = $widthFwhm
        W_I_mA                               = $widthFwhm
        width_chosen_mA                      = $widthFwhm
        asym_WI                              = $asymWI
        asym_lr_sum                          = $asymLrSum
        in_primary_domain_T_lt_31p5          = if ($inPrimary) { 'YES' } else { 'NO' }
        above_31p5_diagnostic_only           = if ($inPrimary) { 'NO' } else { 'YES' }
        T22_internal_crossover_candidate_tag = if ([Math]::Abs($t - 22.0) -lt 1.0e-9) { 'YES' } else { 'NO' }
        canonical_run_id                     = $canonicalRunId
        canonical_s_source                   = 'results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv'
    })
}
$replay = @($replayRows | Sort-Object T_K)

# Merge/verify with P0 values when present at same T.
$p0ByT = @{}
foreach ($r in $p0) { $p0ByT[[string]([int](To-DoubleOrNaN $r.T_K))] = $r }
$valueOut = New-Object System.Collections.ArrayList
$maxDeltaAsymWI = 0.0
$maxDeltaAsymLr = 0.0
$finiteDeltaCount = 0
foreach ($r in $replay) {
    $k = [string]([int][double]$r.T_K)
    if ($p0ByT.ContainsKey($k)) {
        $p0r = $p0ByT[$k]
        $dWI = [Math]::Abs([double]($r.asym_WI - (To-DoubleOrNaN $p0r.asym_WI)))
        $dLR = [Math]::Abs([double]($r.asym_lr_sum - (To-DoubleOrNaN $p0r.asym_lr_sum)))
        if (-not [double]::IsNaN($dWI)) {
            $maxDeltaAsymWI = [Math]::Max($maxDeltaAsymWI, $dWI)
            $finiteDeltaCount += 1
        }
        if (-not [double]::IsNaN($dLR)) {
            $maxDeltaAsymLr = [Math]::Max($maxDeltaAsymLr, $dLR)
        }
        $r | Add-Member -NotePropertyName p0_row_found -NotePropertyValue 'YES' -Force
        $r | Add-Member -NotePropertyName delta_vs_p0_asym_WI -NotePropertyValue $dWI -Force
        $r | Add-Member -NotePropertyName delta_vs_p0_asym_lr_sum -NotePropertyValue $dLR -Force
    } else {
        $r | Add-Member -NotePropertyName p0_row_found -NotePropertyValue 'NO' -Force
        $r | Add-Member -NotePropertyName delta_vs_p0_asym_WI -NotePropertyValue ([double]::NaN) -Force
        $r | Add-Member -NotePropertyName delta_vs_p0_asym_lr_sum -NotePropertyValue ([double]::NaN) -Force
    }
    [void]$valueOut.Add($r)
}
$valueOut | Export-Csv -NoTypeInformation -Encoding UTF8 $valuesPath

# Legacy artifact search in required roots.
$legacyRoots = @(
    (Join-Path $RepoRoot 'results_old/switching/runs'),
    (Join-Path $RepoRoot 'tables_old'),
    (Join-Path $RepoRoot 'tables'),
    (Join-Path $RepoRoot 'reports')
)
$legacyCandidates = New-Object System.Collections.ArrayList
foreach ($root in $legacyRoots) {
    if (-not (Test-Path $root)) { continue }
    $files = Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -match 'asym|halfwidth|half_width|left|right|effective_observables') -and
            ($_.Extension -in @('.csv', '.md'))
        } |
        Select-Object -First 80
    foreach ($f in $files) { [void]$legacyCandidates.Add($f.FullName) }
}

$legacyAsymTable = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_13_152008_switching_effective_observables/tables/switching_effective_observables_table.csv'
$legacyFound = Test-Path $legacyAsymTable
$legacyPerformed = $false
$legacyPassed = 'NOT_PERFORMED'

if ($legacyFound) {
    $legacy = @(Import-Csv $legacyAsymTable)
    $legacyByT = @{}
    foreach ($l in $legacy) { $legacyByT[[string]([int](To-DoubleOrNaN $l.T_K))] = $l }

    $compRows = New-Object System.Collections.ArrayList
    $maxDeltaLegacyAsym = 0.0
    foreach ($r in $valueOut) {
        $k = [string]([int][double]$r.T_K)
        if ($legacyByT.ContainsKey($k)) {
            $legacyPerformed = $true
            $la = To-DoubleOrNaN $legacyByT[$k].asym
            $dA = [double]($r.asym_lr_sum - $la)
            $maxDeltaLegacyAsym = [Math]::Max($maxDeltaLegacyAsym, [Math]::Abs($dA))
            [void]$compRows.Add([pscustomobject]@{
                T_K                        = $r.T_K
                canonical_asym_WI          = $r.asym_WI
                canonical_asym_lr_sum      = $r.asym_lr_sum
                legacy_asym                = $la
                delta_asym_lr_sum_vs_legacy = $dA
                overlap_status             = 'OVERLAP'
                note                       = 'Legacy asym compared to canonical asym_lr_sum.'
            })
        } else {
            [void]$compRows.Add([pscustomobject]@{
                T_K                        = $r.T_K
                canonical_asym_WI          = $r.asym_WI
                canonical_asym_lr_sum      = $r.asym_lr_sum
                legacy_asym                = [double]::NaN
                delta_asym_lr_sum_vs_legacy = [double]::NaN
                overlap_status             = 'NO_LEGACY_ROW'
                note                       = 'No legacy row at this T.'
            })
        }
    }
    $tol = 1.0e-6
    if ($legacyPerformed) { $legacyPassed = if ($maxDeltaLegacyAsym -le $tol) { 'YES' } else { 'NO' } }
    $compRows | Export-Csv -NoTypeInformation -Encoding UTF8 $legacyCompPath
} else {
    @([pscustomobject]@{
        comparison_status = 'NOT_PERFORMED'
        reason = 'No clean legacy numeric asymmetry table found.'
        legacy_search_roots = ($legacyRoots -join '; ')
        legacy_candidates_sample = (($legacyCandidates | Select-Object -First 12) -join '; ')
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $legacyCompPath
}

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'P1_ASYMMETRY_LR_REPLAY_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'CANONICAL_S_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'P0_EFFECTIVE_OBSERVABLES_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'NUMERIC_VALUES_WRITTEN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'LEGACY_ASYMMETRY_ARTIFACTS_FOUND'; verdict_value = if ($legacyFound) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_CHECK_PERFORMED'; verdict_value = if ($legacyPerformed) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_PASSED'; verdict_value = if ($legacyPerformed) { $legacyPassed } else { 'NOT_PERFORMED' } }
    [pscustomobject]@{ verdict_key = 'T22_INCLUDED_IN_PRIMARY_DOMAIN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ABOVE_31P5_DIAGNOSTIC_ONLY'; verdict_value = 'YES' }
    [pscustomobject]@{
        verdict_key = 'ASYMMETRY_CANONICAL_RECIPE_VALIDATED'
        verdict_value = if (($finiteDeltaCount -gt 0) -and ($maxDeltaAsymWI -le 1.0e-6) -and ($maxDeltaAsymLr -le 1.0e-6)) { 'YES' } else { 'NO' }
    }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
)
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusPath

$lines = @()
$lines += '# Switching P1 asymmetry / LR half-width canonical replay'
$lines += ''
$lines += 'This is a narrow replay only: canonical asymmetry/LR-half-width recipe validation on canonical S with optional legacy numeric parity.'
$lines += 'No collapse reopening, no geocanon, no residual/Phi/kappa, no PT/CDF/barrier, and no cross-module synthesis.'
$lines += ''
$lines += '## Inputs'
$lines += '- `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv`'
$lines += '- `tables/switching_P0_effective_observables_values.csv`'
$lines += ''
$lines += '## Canonical Replay Values'
$lines += '- Recomputed per-T: `I_peak_mA`, `S_peak`, left/right half currents, FWHM width, `asym_WI`, `asym_lr_sum`.'
$lines += "- Verification vs P0 values (finite overlaps): max_abs_delta_asym_WI=$maxDeltaAsymWI, max_abs_delta_asym_lr_sum=$maxDeltaAsymLr, n_finite_overlap_rows=$finiteDeltaCount."
$lines += '- Domain lock: primary `T_K < 31.5`, `22 K` included/tagged internal crossover, `32/34 K` diagnostic-only.'
$lines += ''
$lines += '## Legacy Search and Parity'
$lines += ('- Legacy search roots: ' + ($legacyRoots -join '; '))
if ($legacyFound) {
    $lines += '- Clean legacy table used: `results_old/switching/runs/run_2026_03_13_152008_switching_effective_observables/tables/switching_effective_observables_table.csv`.'
    $legacyPerfTxt = 'NO'
    if ($legacyPerformed) { $legacyPerfTxt = 'YES' }
    $lines += ('- Legacy numeric parity performed: ' + $legacyPerfTxt + '; result=' + $legacyPassed + '.')
} else {
    $lines += '- No clean legacy numeric asymmetry table found; parity marked `NOT_PERFORMED`.'
    if ($legacyCandidates.Count -gt 0) {
        $lines += '- Recovery/inventory sample candidates:'
        foreach ($c in ($legacyCandidates | Select-Object -First 12)) { $lines += ('  - `' + $c + '`') }
    } else {
        $lines += '- Recovery/inventory scan found no candidate asymmetry artifacts in configured roots.'
    }
}
$lines += ''
$lines += '## Claim Boundary'
$lines += '- No `X_canon` claim.'
$lines += '- No unique-W claim.'
$lines += '- No scaling claim.'
$lines += '- No mechanism claim.'
$lines += '- No cross-module synthesis.'
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_P1_asymmetry_LR_values.csv`'
$lines += '- `tables/switching_P1_asymmetry_LR_legacy_comparison.csv`'
$lines += '- `tables/switching_P1_asymmetry_LR_status.csv`'
$lines += '- `reports/switching_P1_asymmetry_LR_replay.md`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $statusRows) { $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`') }
$lines | Set-Content -Encoding UTF8 $reportPath

Write-Host "P1 asymmetry LR replay written: $reportPath"

