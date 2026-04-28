# Materialize P0 effective-observables numeric values from locked canonical S map.
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'

$tablesDir = Join-Path $RepoRoot 'tables'
$reportsDir = Join-Path $RepoRoot 'reports'
if (-not (Test-Path $tablesDir)) { New-Item -ItemType Directory -Path $tablesDir -Force | Out-Null }
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$canonicalRunId = 'run_2026_04_03_000147_switching_canonical'
$canonicalSPath = Join-Path $RepoRoot "results/switching/runs/$canonicalRunId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $canonicalSPath)) { throw "Missing canonical S map: $canonicalSPath" }

$legacyBase = Join-Path $RepoRoot 'results_old/switching/runs/run_2026_03_13_152008_switching_effective_observables'
$legacyObsPath = Join-Path $legacyBase 'tables/switching_effective_observables_table.csv'
$legacyXPath = Join-Path $legacyBase 'tables/switching_effective_coordinate_x.csv'
$legacyDefectPath = Join-Path $legacyBase 'tables/switching_effective_collapse_defect_vs_T.csv'
$legacyObsRootPath = Join-Path $legacyBase 'observables.csv'

$p0DefectByTPath = Join-Path $tablesDir 'switching_old_collapse_apples_to_apples_failure_by_T.csv'

function Interp-Crossing([double]$x1,[double]$y1,[double]$x2,[double]$y2,[double]$target) {
    if ($x2 -eq $x1) { return $x1 }
    if ($y2 -eq $y1) { return (($x1 + $x2) / 2.0) }
    $t = ($target - $y1) / ($y2 - $y1)
    return ($x1 + $t * ($x2 - $x1))
}

function To-DoubleOrNaN($v) {
    if ($null -eq $v) { return [double]::NaN }
    $s = [string]$v
    if ([string]::IsNullOrWhiteSpace($s)) { return [double]::NaN }
    $x = 0.0
    if ([double]::TryParse($s, [ref]$x)) { return [double]$x }
    return [double]::NaN
}

$canon = @(Import-Csv $canonicalSPath)
if ($canon.Count -eq 0) { throw "Canonical S table is empty: $canonicalSPath" }

$rows = New-Object System.Collections.ArrayList

$grouped = $canon | Group-Object T_K
foreach ($g in $grouped) {
    $t = To-DoubleOrNaN $g.Name
    $pts = @($g.Group | Sort-Object { To-DoubleOrNaN $_.current_mA })
    if ($pts.Count -lt 2) { continue }

    $iPeak = [double]::NaN
    $sPeak = -1.0e300
    foreach ($p in $pts) {
        $c = To-DoubleOrNaN $p.current_mA
        $s = To-DoubleOrNaN $p.S_percent
        if ($s -gt $sPeak) {
            $sPeak = [double]$s
            $iPeak = [double]$c
        }
    }

    $half = 0.5 * $sPeak
    $leftCrossings = New-Object System.Collections.ArrayList
    $rightCrossings = New-Object System.Collections.ArrayList

    for ($i = 0; $i -lt ($pts.Count - 1); $i++) {
        $x1 = To-DoubleOrNaN $pts[$i].current_mA
        $x2 = To-DoubleOrNaN $pts[$i+1].current_mA
        $y1 = To-DoubleOrNaN $pts[$i].S_percent
        $y2 = To-DoubleOrNaN $pts[$i+1].S_percent
        $crosses = (($y1 -eq $half) -or ($y2 -eq $half) -or ((($y1 - $half) * ($y2 - $half)) -lt 0))
        if (-not $crosses) { continue }
        $xh = Interp-Crossing $x1 $y1 $x2 $y2 $half
        if ($xh -le $iPeak) { [void]$leftCrossings.Add($xh) }
        if ($xh -ge $iPeak) { [void]$rightCrossings.Add($xh) }
    }

    $left = [double]::NaN
    $right = [double]::NaN
    if ($leftCrossings.Count -gt 0) { $left = [double](($leftCrossings | Measure-Object -Maximum).Maximum) }
    if ($rightCrossings.Count -gt 0) { $right = [double](($rightCrossings | Measure-Object -Minimum).Minimum) }

    $widthFwhm = [double]::NaN
    if ((-not [double]::IsNaN($left)) -and (-not [double]::IsNaN($right)) -and ($right -ge $left)) {
        $widthFwhm = [double]($right - $left)
    }

    # Sigma fallback as Gaussian-FWHM-equivalent width.
    $wSum = 0.0
    $vSum = 0.0
    foreach ($p in $pts) {
        $c = To-DoubleOrNaN $p.current_mA
        $s = To-DoubleOrNaN $p.S_percent
        $w = [Math]::Max([double]$s, 0.0)
        $wSum += $w
        $vSum += $w * (($c - $iPeak) * ($c - $iPeak))
    }
    $widthSigma = [double]::NaN
    if ($wSum -gt 0) {
        $sigma = [Math]::Sqrt($vSum / $wSum)
        $widthSigma = [double](2.0 * [Math]::Sqrt(2.0 * [Math]::Log(2.0)) * $sigma)
    }

    $widthChosen = [double]::NaN
    $widthMethod = 'sigma_fallback'
    if ((-not [double]::IsNaN($widthFwhm)) -and ($widthFwhm -gt 0)) {
        $widthChosen = [double]$widthFwhm
        $widthMethod = 'fwhm_interpolated'
    } else {
        $widthChosen = [double]$widthSigma
    }

    $wL = if (-not [double]::IsNaN($left)) { [double]($iPeak - $left) } else { [double]::NaN }
    $wR = if (-not [double]::IsNaN($right)) { [double]($right - $iPeak) } else { [double]::NaN }
    $xEff = if ((-not [double]::IsNaN($widthChosen)) -and ($widthChosen -ne 0) -and ($sPeak -ne 0)) { [double]($iPeak / ($widthChosen * $sPeak)) } else { [double]::NaN }
    $asymWI = if ((-not [double]::IsNaN($wL)) -and (-not [double]::IsNaN($wR)) -and (-not [double]::IsNaN($widthChosen)) -and ($widthChosen -ne 0)) { [double](($wR - $wL) / $widthChosen) } else { [double]::NaN }
    $asymLrSum = if ((-not [double]::IsNaN($wL)) -and (-not [double]::IsNaN($wR)) -and (($wR + $wL) -ne 0)) { [double](($wR - $wL) / ($wR + $wL)) } else { [double]::NaN }

    $inPrimary = ($t -lt 31.5)
    $t22Tag = ([Math]::Abs($t - 22.0) -lt 1.0e-9)

    [void]$rows.Add([pscustomobject]@{
        T_K                                  = $t
        I_peak_mA                            = $iPeak
        S_peak                               = $sPeak
        left_half_current_mA                 = $left
        right_half_current_mA                = $right
        width_fwhm_mA                        = $widthFwhm
        width_sigma_mA                       = $widthSigma
        W_I_mA                               = $widthChosen
        width_chosen_mA                      = $widthChosen
        width_method                         = $widthMethod
        X_eff                                = $xEff
        asym_WI                              = $asymWI
        asym_lr_sum                          = $asymLrSum
        in_primary_domain_T_lt_31p5          = if ($inPrimary) { 'YES' } else { 'NO' }
        above_31p5_diagnostic_only           = if ($inPrimary) { 'NO' } else { 'YES' }
        T22_internal_crossover_candidate_tag = if ($t22Tag) { 'YES' } else { 'NO' }
        canonical_run_id                     = $canonicalRunId
        canonical_s_source                   = 'results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv'
    })
}

$values = @($rows | Sort-Object T_K)

$collapseMerged = $false
if (Test-Path $p0DefectByTPath) {
    $def = @(Import-Csv $p0DefectByTPath | Where-Object { $_.variant_id -eq 'PRIMARY_T_LT_31P5' })
    $defByT = @{}
    foreach ($d in $def) { $defByT[[string]$d.T_K] = $d }
    foreach ($v in $values) {
        $k = [string]([int][double]$v.T_K)
        if ($defByT.ContainsKey($k)) {
            $v | Add-Member -NotePropertyName collapse_defect_vs_T_old_style -NotePropertyValue (To-DoubleOrNaN $defByT[$k].curve_rmse_to_master) -Force
            $v | Add-Member -NotePropertyName collapse_defect_domain_note -NotePropertyValue ([string]$defByT[$k].domain_note) -Force
            $collapseMerged = $true
        } else {
            $v | Add-Member -NotePropertyName collapse_defect_vs_T_old_style -NotePropertyValue ([double]::NaN) -Force
            $v | Add-Member -NotePropertyName collapse_defect_domain_note -NotePropertyValue 'unavailable' -Force
        }
    }
} else {
    foreach ($v in $values) {
        $v | Add-Member -NotePropertyName collapse_defect_vs_T_old_style -NotePropertyValue ([double]::NaN) -Force
        $v | Add-Member -NotePropertyName collapse_defect_domain_note -NotePropertyValue 'unavailable' -Force
    }
}

$valuesPath = Join-Path $tablesDir 'switching_P0_effective_observables_values.csv'
$values | Export-Csv -NoTypeInformation -Encoding UTF8 $valuesPath

$legacyFound = (Test-Path $legacyObsPath) -and (Test-Path $legacyObsRootPath) -and (Test-Path $legacyXPath) -and (Test-Path $legacyDefectPath)
$legacyPerformed = $false
$legacyPassed = $false

$compPath = Join-Path $tablesDir 'switching_P0_effective_observables_numeric_comparison.csv'
$maxDelta = @{
    I_peak = [double]::NaN
    S_peak = [double]::NaN
    WI = [double]::NaN
    X = [double]::NaN
    defect = [double]::NaN
}

if ($legacyFound) {
    $legacy = @(Import-Csv $legacyObsPath)
    $legacyByT = @{}
    foreach ($l in $legacy) { $legacyByT[[string]([int](To-DoubleOrNaN $l.T_K))] = $l }

    $compRows = New-Object System.Collections.ArrayList
    foreach ($v in $values) {
        $k = [string]([int][double]$v.T_K)
        if ($legacyByT.ContainsKey($k)) {
            $legacyPerformed = $true
            $l = $legacyByT[$k]
            $dI = [double]($v.I_peak_mA - (To-DoubleOrNaN $l.I_peak_mA))
            $dS = [double]($v.S_peak - (To-DoubleOrNaN $l.S_peak))
            $dW = [double]($v.W_I_mA - (To-DoubleOrNaN $l.width_mA))
            $dX = [double]($v.X_eff - (To-DoubleOrNaN $l.X))
            $dD = [double]($v.collapse_defect_vs_T_old_style - (To-DoubleOrNaN $l.collapse_defect))
            $dA = [double]($v.asym_lr_sum - (To-DoubleOrNaN $l.asym))
            $maxDelta.I_peak = if ([double]::IsNaN($maxDelta.I_peak)) { [Math]::Abs($dI) } else { [Math]::Max($maxDelta.I_peak, [Math]::Abs($dI)) }
            $maxDelta.S_peak = if ([double]::IsNaN($maxDelta.S_peak)) { [Math]::Abs($dS) } else { [Math]::Max($maxDelta.S_peak, [Math]::Abs($dS)) }
            $maxDelta.WI = if ([double]::IsNaN($maxDelta.WI)) { [Math]::Abs($dW) } else { [Math]::Max($maxDelta.WI, [Math]::Abs($dW)) }
            $maxDelta.X = if ([double]::IsNaN($maxDelta.X)) { [Math]::Abs($dX) } else { [Math]::Max($maxDelta.X, [Math]::Abs($dX)) }
            $maxDelta.defect = if ([double]::IsNaN($maxDelta.defect)) { [Math]::Abs($dD) } else { [Math]::Max($maxDelta.defect, [Math]::Abs($dD)) }

            [void]$compRows.Add([pscustomobject]@{
                T_K                               = $v.T_K
                I_peak_mA                         = $v.I_peak_mA
                legacy_I_peak_mA                  = To-DoubleOrNaN $l.I_peak_mA
                delta_I_peak_mA                   = $dI
                S_peak                            = $v.S_peak
                legacy_S_peak                     = To-DoubleOrNaN $l.S_peak
                delta_S_peak                      = $dS
                W_I_mA                            = $v.W_I_mA
                legacy_width_mA                   = To-DoubleOrNaN $l.width_mA
                delta_W_I_mA                      = $dW
                X_eff                             = $v.X_eff
                legacy_X                          = To-DoubleOrNaN $l.X
                delta_X_eff                       = $dX
                collapse_defect_vs_T_old_style    = $v.collapse_defect_vs_T_old_style
                legacy_collapse_defect            = To-DoubleOrNaN $l.collapse_defect
                delta_collapse_defect_vs_T        = $dD
                asym_WI                           = $v.asym_WI
                asym_lr_sum                       = $v.asym_lr_sum
                legacy_asym                       = To-DoubleOrNaN $l.asym
                delta_asym_lr_sum_vs_legacy_asym  = $dA
                legacy_comparison_available       = 'YES'
                notes                             = 'Legacy asym compared to asym_lr_sum; asym_WI retained as canonical width-normalized diagnostic.'
            })
        } else {
            [void]$compRows.Add([pscustomobject]@{
                T_K                               = $v.T_K
                I_peak_mA                         = $v.I_peak_mA
                legacy_I_peak_mA                  = [double]::NaN
                delta_I_peak_mA                   = [double]::NaN
                S_peak                            = $v.S_peak
                legacy_S_peak                     = [double]::NaN
                delta_S_peak                      = [double]::NaN
                W_I_mA                            = $v.W_I_mA
                legacy_width_mA                   = [double]::NaN
                delta_W_I_mA                      = [double]::NaN
                X_eff                             = $v.X_eff
                legacy_X                          = [double]::NaN
                delta_X_eff                       = [double]::NaN
                collapse_defect_vs_T_old_style    = $v.collapse_defect_vs_T_old_style
                legacy_collapse_defect            = [double]::NaN
                delta_collapse_defect_vs_T        = [double]::NaN
                asym_WI                           = $v.asym_WI
                asym_lr_sum                       = $v.asym_lr_sum
                legacy_asym                       = [double]::NaN
                delta_asym_lr_sum_vs_legacy_asym  = [double]::NaN
                legacy_comparison_available       = 'NO'
                notes                             = 'No matching legacy row at this T.'
            })
        }
    }
    $compRows | Export-Csv -NoTypeInformation -Encoding UTF8 $compPath

    $tol = 1.0e-6
    if ($legacyPerformed) {
        $legacyPassed = (($maxDelta.I_peak -le $tol) -and ($maxDelta.S_peak -le $tol) -and ($maxDelta.WI -le $tol) -and ($maxDelta.X -le $tol) -and ($maxDelta.defect -le $tol))
    }
} else {
    @([pscustomobject]@{
        comparison_status = 'LEGACY_EFFECTIVE_OBSERVABLES_ARTIFACTS_NOT_FOUND'
        expected_legacy_paths = 'results_old/.../switching_effective_observables_table.csv; observables.csv; switching_effective_coordinate_x.csv; switching_effective_collapse_defect_vs_T.csv'
    }) | Export-Csv -NoTypeInformation -Encoding UTF8 $compPath
}

# Update recipe parity table with numeric materialization metadata.
$parityPath = Join-Path $tablesDir 'switching_P0_effective_observables_recipe_parity.csv'
if (Test-Path $parityPath) {
    $parity = @(Import-Csv $parityPath)
    foreach ($p in $parity) {
        $p | Add-Member -NotePropertyName numeric_materialization_status -NotePropertyValue 'NUMERIC_VALUES_WRITTEN_FROM_CANONICAL_S' -Force
        $p | Add-Member -NotePropertyName canonical_numeric_source -NotePropertyValue 'run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv' -Force
        if ($legacyFound -and $legacyPerformed) {
            $p | Add-Member -NotePropertyName legacy_numeric_comparison_status -NotePropertyValue 'PERFORMED' -Force
            $legacyPassTxt = 'NO'
            if ($legacyPassed) { $legacyPassTxt = 'YES' }
            $p | Add-Member -NotePropertyName legacy_numeric_parity_passed -NotePropertyValue $legacyPassTxt -Force
        } else {
            $p | Add-Member -NotePropertyName legacy_numeric_comparison_status -NotePropertyValue 'UNAVAILABLE' -Force
            $p | Add-Member -NotePropertyName legacy_numeric_parity_passed -NotePropertyValue 'UNAVAILABLE' -Force
        }
    }
    $parity | Export-Csv -NoTypeInformation -Encoding UTF8 $parityPath
}

$status = @(
    [pscustomobject]@{ verdict_key = 'P0_EFFECTIVE_OBSERVABLES_NUMERIC_MATERIALIZATION_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'CANONICAL_S_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'NUMERIC_VALUES_WRITTEN'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'I_PEAK_NUMERIC_COMPUTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'S_PEAK_NUMERIC_COMPUTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'WI_NUMERIC_COMPUTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'X_NUMERIC_COMPUTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ASYMMETRY_NUMERIC_COMPUTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'COLLAPSE_DEFECT_VS_T_MERGED'; verdict_value = if ($collapseMerged) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_EFFECTIVE_OBSERVABLES_FOUND'; verdict_value = if ($legacyFound) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_CHECK_PERFORMED'; verdict_value = if ($legacyPerformed) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'LEGACY_NUMERIC_PARITY_PASSED'; verdict_value = if ($legacyPerformed) { if ($legacyPassed) { 'YES' } else { 'NO' } } else { 'UNAVAILABLE' } }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'UNIQUE_W_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_SYNTHESIS_PERFORMED'; verdict_value = 'NO' }
)
$statusPath = Join-Path $tablesDir 'switching_P0_effective_observables_status.csv'
$status | Export-Csv -NoTypeInformation -Encoding UTF8 $statusPath

$reportPath = Join-Path $reportsDir 'switching_P0_effective_observables_recipe_parity.md'
$lines = @()
$lines += '# P0 effective observables recipe parity (numeric materialization)'
$lines += ''
$lines += ('Numeric values were materialized from locked canonical run `' + $canonicalRunId + '` using `switching_canonical_S_long.csv`.')
$lines += 'This is recipe materialization/parity only; no mechanism inference, no `X_canon`, no unique-W claim, no scaling claim.'
$lines += ''
$lines += '## Canonical Numeric Source'
$lines += '- `results/switching/runs/run_2026_04_03_000147_switching_canonical/tables/switching_canonical_S_long.csv`'
$lines += ''
$lines += '## Materialized Observables'
$lines += '- `I_peak(T)` from row-max current of canonical `S(I,T)`.'
$lines += '- `S_peak(T)` from row-max value.'
$lines += '- `W_I(T)` from interpolated FWHM at `0.5*S_peak`; sigma fallback only when unresolved (`width_method`).'
$lines += '- `X_eff(T)=I_peak/(W_I*S_peak)`.'
$lines += '- `collapse_defect_vs_T` merged from apples-to-apples `PRIMARY_T_LT_31P5` per-T RMSE table when available.'
$lines += '- `asym_WI=(w_R-w_L)/W_I`, diagnostic `asym_lr_sum=(w_R-w_L)/(w_R+w_L)`.'
$lines += ''
$lines += '## Domain Flags'
$lines += '- Primary: `T_K < 31.5`.'
$lines += '- `22 K`: included with internal crossover candidate tag.'
$lines += '- `32/34 K` and generally `T_K >= 31.5`: diagnostic-only.'
$lines += ''
$lines += '## Legacy Numeric Comparison'
if ($legacyFound -and $legacyPerformed) {
    $lines += '- Legacy effective-observables artifacts were found under `results_old/.../run_2026_03_13_152008_switching_effective_observables`.'
    $parityTxt = 'NOT PASS'
    if ($legacyPassed) { $parityTxt = 'PASS' }
    $lines += ("- Numeric parity check performed with strict tolerance `1e-6`; result: **" + $parityTxt + "**.")
    $lines += ('- `max_abs_delta_I_peak_mA` = `' + $maxDelta.I_peak + '`')
    $lines += ('- `max_abs_delta_S_peak` = `' + $maxDelta.S_peak + '`')
    $lines += ('- `max_abs_delta_W_I_mA` = `' + $maxDelta.WI + '`')
    $lines += ('- `max_abs_delta_X_eff` = `' + $maxDelta.X + '`')
    $lines += ('- `max_abs_delta_collapse_defect_vs_T` = `' + $maxDelta.defect + '`')
} else {
    $lines += '- Legacy artifacts unavailable; canonical materialization still complete.'
}
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_P0_effective_observables_values.csv`'
$lines += '- `tables/switching_P0_effective_observables_recipe_parity.csv`'
$lines += '- `tables/switching_P0_effective_observables_numeric_comparison.csv`'
$lines += '- `tables/switching_P0_effective_observables_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) { $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`') }
$lines | Set-Content -Encoding UTF8 $reportPath

Write-Host "Numeric materialization written: $reportPath"

