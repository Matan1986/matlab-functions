# Apples-to-apples old-style collapse on canonical W_I replay with transition cutoff ~31.5 K.
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [double]$TransitionCutoff_K = 31.5,
    [double]$T22Nominal_K = 22.0,
    [int]$CollapseGridSize = 200,
    [double]$LegacyFullScalingChosenDefect = 0.0760344051730165,
    [double]$LegacyMatchAbsTolerance = 0.03,
    # 22 K stays in PRIMARY_T_LT_31P5. Sensitivity run (exclude 22 K) only if dominant vs other primary-domain Ts:
    [double]$T22DominantMedianRatio = 1.2
)

$ErrorActionPreference = 'Stop'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function Get-MedianFinite([double[]]$xs) {
    $a = @($xs | Where-Object { Test-Finite $_ } | Sort-Object)
    if ($a.Count -eq 0) { return [double]::NaN }
    $m = [math]::Floor($a.Count / 2)
    if (($a.Count % 2) -eq 1) { return [double]$a[$m] }
    return 0.5 * ([double]$a[$m - 1] + [double]$a[$m])
}

function Test-T22DominantInternalOutlierPrimary {
    param(
        $coll,
        [double]$t22Nominal,
        [double]$medianRatioThreshold
    )
    $n = $coll.temps.Length
    $t22Idx = -1
    for ($i = 0; $i -lt $n; $i++) {
        if ([math]::Abs([double]$coll.temps[$i] - $t22Nominal) -lt 0.25) { $t22Idx = $i; break }
    }
    if ($t22Idx -lt 0) { return @{ dominant = $false; rank = 0; t22_rmse = [double]::NaN; median_rmse_other_primary = [double]::NaN } }

    $t22Rmse = [double]$coll.curve_rmse[$t22Idx]
    $otherRmses = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $n; $i++) {
        if ([math]::Abs([double]$coll.temps[$i] - $t22Nominal) -lt 0.25) { continue }
        [void]$otherRmses.Add([double]$coll.curve_rmse[$i])
    }
    $medOthers = Get-MedianFinite @($otherRmses.ToArray())

    $pairs = @()
    for ($i = 0; $i -lt $n; $i++) {
        $pairs += [pscustomobject]@{ T_K = [double]$coll.temps[$i]; rmse = [double]$coll.curve_rmse[$i] }
    }
    $sorted = @($pairs | Sort-Object { $_.rmse } -Descending)
    $rank = 0
    for ($r = 0; $r -lt $sorted.Count; $r++) {
        if ([math]::Abs($sorted[$r].T_K - $t22Nominal) -lt 0.25) { $rank = $r + 1; break }
    }

    # Dominant = worst among primary-domain curves, OR second-worst while still >= ratio * median(other primary RMSE)
    $dominant = ($rank -eq 1) -or (
        ($rank -eq 2) -and (Test-Finite $t22Rmse) -and (Test-Finite $medOthers) -and ($medOthers -gt 1e-15) -and ($t22Rmse -ge ($medianRatioThreshold * $medOthers))
    )
    return @{ dominant = $dominant; rank = $rank; t22_rmse = $t22Rmse; median_rmse_other_primary = $medOthers }
}

function Interp1Linear([double[]]$x, [double[]]$y, [double]$xq) {
    $n = $x.Length
    if ($n -lt 2) { return [double]::NaN }
    if ($xq -le $x[0]) { return $y[0] }
    if ($xq -ge $x[$n - 1]) { return $y[$n - 1] }
    for ($i = 1; $i -lt $n; $i++) {
        if ($xq -le $x[$i]) {
            $t = ($xq - $x[$i - 1]) / ($x[$i] - $x[$i - 1])
            return $y[$i - 1] + $t * ($y[$i] - $y[$i - 1])
        }
    }
    return [double]::NaN
}

function Invoke-EvaluateCollapseDetailed {
    param(
        [System.Collections.ArrayList]$xCurves,
        [System.Collections.ArrayList]$yCurves,
        [double[]]$temps,
        [int]$gridSize
    )
    $metrics = @{
        common_min    = [double]::NaN
        common_max    = [double]::NaN
        mean_std      = [double]::NaN
        mean_variance = [double]::NaN
        mean_rmse     = [double]::NaN
        global_defect = [double]::NaN
        curve_rmse    = @()
        temps         = @()
    }
    $nc = $xCurves.Count
    if ($nc -lt 2) { return $metrics }
    if ($temps.Length -ne $nc) { throw "temps length mismatch" }

    $xMins = @(); $xMaxs = @()
    for ($i = 0; $i -lt $nc; $i++) {
        $xc = $xCurves[$i]
        if ($xc.Count -lt 2) { return $metrics }
        $xMins += , ($xc | Measure-Object -Minimum).Minimum
        $xMaxs += , ($xc | Measure-Object -Maximum).Maximum
    }
    $xLo = [double]($xMins | Measure-Object -Maximum).Maximum
    $xHi = [double]($xMaxs | Measure-Object -Minimum).Minimum
    if (-not ((Test-Finite $xLo) -and (Test-Finite $xHi)) -or ($xLo -ge $xHi)) { return $metrics }

    $xGrid = New-Object double[] $gridSize
    for ($g = 0; $g -lt $gridSize; $g++) {
        $xGrid[$g] = $xLo + ($g / ($gridSize - 1)) * ($xHi - $xLo)
    }

    $Ygrid = New-Object 'double[,]' $nc, $gridSize
    for ($it = 0; $it -lt $nc; $it++) {
        $xv = $xCurves[$it]
        $yv = $yCurves[$it]
        for ($k = 0; $k -lt $gridSize; $k++) {
            $Ygrid[$it, $k] = Interp1Linear $xv $yv $xGrid[$k]
        }
    }

    $meanCurve = New-Object double[] $gridSize
    $pointStd = New-Object double[] $gridSize
    for ($k = 0; $k -lt $gridSize; $k++) {
        $vals = New-Object System.Collections.Generic.List[double]
        for ($it = 0; $it -lt $nc; $it++) {
            $v = $Ygrid[$it, $k]
            if (Test-Finite $v) { [void]$vals.Add($v) }
        }
        if ($vals.Count -eq 0) {
            $meanCurve[$k] = [double]::NaN
            $pointStd[$k] = [double]::NaN
            continue
        }
        $meanCurve[$k] = ($vals | Measure-Object -Average).Average
        if ($vals.Count -ge 2) {
            $sumSq = 0.0
            foreach ($vv in $vals) { $sumSq += ($vv - $meanCurve[$k]) * ($vv - $meanCurve[$k]) }
            $pointStd[$k] = [math]::Sqrt($sumSq / ($vals.Count - 1))
        }
        else { $pointStd[$k] = 0.0 }
    }

    $curveRmse = New-Object double[] $nc
    for ($it = 0; $it -lt $nc; $it++) {
        $sse = 0.0
        $cnt = 0
        for ($k = 0; $k -lt $gridSize; $k++) {
            if (-not (Test-Finite $Ygrid[$it, $k])) { continue }
            if (-not (Test-Finite $meanCurve[$k])) { continue }
            $d = $Ygrid[$it, $k] - $meanCurve[$k]
            $sse += $d * $d
            $cnt++
        }
        $curveRmse[$it] = if ($cnt -gt 0) { [math]::Sqrt($sse / $cnt) } else { [double]::NaN }
    }

    $pst = @($pointStd | Where-Object { Test-Finite $_ })
    $meanStd = if ($pst.Count -gt 0) { ($pst | Measure-Object -Average).Average } else { [double]::NaN }
    $meanVar = if ($pst.Count -gt 0) { ($pst | ForEach-Object { $_ * $_ } | Measure-Object -Average).Average } else { [double]::NaN }
    $meanRmse = ($curveRmse | Where-Object { Test-Finite $_ } | Measure-Object -Average).Average

    $metrics.common_min = $xLo
    $metrics.common_max = $xHi
    $metrics.mean_std = $meanStd
    $metrics.mean_variance = $meanVar
    $metrics.mean_rmse = $meanRmse
    $metrics.global_defect = $meanStd
    $metrics.curve_rmse = $curveRmse
    $metrics.temps = $temps
    return $metrics
}

function Build-CurveSetsFromReplayValues([object[]]$allRows) {
    $byT = $allRows | Group-Object { [double]$_.T_K }
    $xCurves = New-Object System.Collections.ArrayList
    $yCurves = New-Object System.Collections.ArrayList
    $tList = New-Object System.Collections.Generic.List[double]
    $meta = @{}

    foreach ($g in ($byT | Sort-Object { [double]$_.Name })) {
        $tk = [double]$g.Name
        $slice = @($g.Group | Sort-Object { [double]$_.x_scaled_old_recipe })
        $xvs = @($slice | ForEach-Object { [double]$_.x_scaled_old_recipe })
        $yvs = @($slice | ForEach-Object { [double]$_.y_scaled })
        $xu = New-Object System.Collections.Generic.List[double]
        $yu = New-Object System.Collections.Generic.List[double]
        for ($i = 0; $i -lt $xvs.Count; $i++) {
            if ($xu.Count -eq 0 -or [math]::Abs($xvs[$i] - $xu[$xu.Count - 1]) -gt 1e-12) {
                [void]$xu.Add($xvs[$i]); [void]$yu.Add($yvs[$i])
            }
            else {
                $yu[$yu.Count - 1] = $yvs[$i]
            }
        }
        if ($xu.Count -lt 2) { continue }
        $wm = ($slice | Select-Object -First 1).width_method
        $meta[$tk] = @{
            x_min = ($xu.ToArray() | Measure-Object -Minimum).Minimum
            x_max = ($xu.ToArray() | Measure-Object -Maximum).Maximum
            width_method = [string]$wm
        }
        [void]$xCurves.Add(@($xu.ToArray()))
        [void]$yCurves.Add(@($yu.ToArray()))
        [void]$tList.Add($tk)
    }
    return @{
        xCurves = $xCurves
        yCurves = $yCurves
        temps   = $tList.ToArray()
        meta    = $meta
    }
}

function Select-CurveSubset($bundle, [scriptblock]$pred) {
    $nx = New-Object System.Collections.ArrayList
    $ny = New-Object System.Collections.ArrayList
    $nt = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $bundle.temps.Length; $i++) {
        $tk = $bundle.temps[$i]
        if (& $pred $tk) {
            [void]$nx.Add($bundle.xCurves[$i])
            [void]$ny.Add($bundle.yCurves[$i])
            [void]$nt.Add($tk)
        }
    }
    return @{
        xCurves = $nx
        yCurves = $ny
        temps   = $nt.ToArray()
    }
}

$valuesPath = Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_values.csv'
if (-not (Test-Path $valuesPath)) { throw "Missing $valuesPath - run scripts/run_switching_old_WI_recipe_replay.ps1 first" }

$rows = @(Import-Csv $valuesPath | ForEach-Object {
    [pscustomobject]@{
        T_K                  = [double]$_.T_K
        x_scaled_old_recipe  = [double]$_.x_scaled_old_recipe
        y_scaled             = [double]$_.y_scaled
        width_method         = [string]$_.width_method
    }
} | Where-Object { (Test-Finite $_.T_K) -and (Test-Finite $_.x_scaled_old_recipe) -and (Test-Finite $_.y_scaled) })

$fullBundle = Build-CurveSetsFromReplayValues $rows

# --- Per-T support table
$supportRows = @()
foreach ($tk in $fullBundle.temps) {
    $m = $fullBundle.meta[$tk]
    $is22 = ([math]::Abs($tk - $T22Nominal_K) -lt 0.25)
    $aboveTr = ($tk -gt $TransitionCutoff_K)
    $inPrimary = ($tk -lt $TransitionCutoff_K)
    $interpret = if ($aboveTr) {
        'above_transition_diagnostic_only_not_primary'
    }
    elseif ($is22) {
        'primary_domain_included_like_other_lowT_T22_crossover_nominal_only'
    }
    else {
        'primary_domain'
    }
    $supportRows += [pscustomobject]@{
        T_K = $tk
        x_curve_min = [math]::Round([double]$m.x_min, 8)
        x_curve_max = [math]::Round([double]$m.x_max, 8)
        width_method_at_T = $m.width_method
        above_transition_T_gt_cutoff = $(if ($aboveTr) { 'YES' } else { 'NO' })
        in_primary_domain_T_lt_cutoff = $(if ($inPrimary) { 'YES' } else { 'NO' })
        T22_nominal_crossover_tag = $(if ($is22) { 'YES' } else { 'NO' })
        domain_interpretation = $interpret
    }
}
$supportRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_apples_to_apples_support_by_T.csv')

function Run-Variant([string]$variantId, [string]$description, [string]$role, $subBundle) {
    $coll = Invoke-EvaluateCollapseDetailed $subBundle.xCurves $subBundle.yCurves $subBundle.temps $CollapseGridSize
    $top = @()
    for ($i = 0; $i -lt $coll.temps.Length; $i++) {
        $top += [pscustomobject]@{ T_K = $coll.temps[$i]; rmse = [double]$coll.curve_rmse[$i] }
    }
    $topSorted = @($top | Sort-Object { $_.rmse } -Descending | Select-Object -First 5)
    return [pscustomobject]@{
        variant_id             = $variantId
        description            = $description
        role                   = $role
        transition_cutoff_K    = $TransitionCutoff_K
        n_curves               = $subBundle.xCurves.Count
        common_x_scaled_min    = if (Test-Finite $coll.common_min) { [math]::Round($coll.common_min, 8) } else { [double]::NaN }
        common_x_scaled_max    = if (Test-Finite $coll.common_max) { [math]::Round($coll.common_max, 8) } else { [double]::NaN }
        mean_intercurve_std    = if (Test-Finite $coll.mean_std) { [math]::Round($coll.mean_std, 10) } else { [double]::NaN }
        mean_rmse_to_master    = if (Test-Finite $coll.mean_rmse) { [math]::Round($coll.mean_rmse, 10) } else { [double]::NaN }
        collapse_grid_size     = $CollapseGridSize
        top_1_T_K              = if ($topSorted.Count -ge 1) { $topSorted[0].T_K } else { '' }
        top_1_curve_rmse       = if ($topSorted.Count -ge 1) { [math]::Round($topSorted[0].rmse, 8) } else { '' }
        top_2_T_K              = if ($topSorted.Count -ge 2) { $topSorted[1].T_K } else { '' }
        top_2_curve_rmse       = if ($topSorted.Count -ge 2) { [math]::Round($topSorted[1].rmse, 8) } else { '' }
        top_3_T_K              = if ($topSorted.Count -ge 3) { $topSorted[2].T_K } else { '' }
        top_3_curve_rmse       = if ($topSorted.Count -ge 3) { [math]::Round($topSorted[2].rmse, 8) } else { '' }
        _coll                  = $coll
        _topSorted             = $topSorted
    }
}

$vFull = Run-Variant 'FULL_ALL_T' 'All ladder temperatures (diagnostic reference for replay)' 'diagnostic_reference' $(
    Select-CurveSubset $fullBundle { param($t) $true }
)

$vPrimary = Run-Variant 'PRIMARY_T_LT_31P5' 'Primary collapse domain: T_K < cutoff (includes 22 K; excludes only T > 31.5 K)' 'primary' $(
    Select-CurveSubset $fullBundle { param($t) $t -lt $TransitionCutoff_K }
)

$t22Dom = Test-T22DominantInternalOutlierPrimary -coll $vPrimary._coll -t22Nominal $T22Nominal_K -medianRatioThreshold $T22DominantMedianRatio
$vPrimaryEx22 = $null
if ($t22Dom.dominant) {
    $vPrimaryEx22 = Run-Variant 'PRIMARY_T_LT_31P5_EXCL_T22_SENSITIVITY' 'Sensitivity only: primary domain minus 22 K (run because 22 K was a dominant internal outlier in PRIMARY_T_LT_31P5)' 'sensitivity_exclude_T22' $(
        Select-CurveSubset $fullBundle { param($t) ($t -lt $TransitionCutoff_K) -and ([math]::Abs($t - $T22Nominal_K) -gt 0.25) }
    )
}

$variants = @($vFull, $vPrimary)
if ($vPrimaryEx22) { $variants += $vPrimaryEx22 }
$fullStd = [double]($vFull.mean_intercurve_std)
$primaryStd = [double]($vPrimary.mean_intercurve_std)

foreach ($v in $variants) {
    $mis = [double]($v.mean_intercurve_std)
    $delta = if ((Test-Finite $fullStd) -and (Test-Finite $mis)) { $mis - $fullStd } else { [double]::NaN }
    Add-Member -InputObject $v -NotePropertyName delta_mean_std_vs_FULL_ALL_T -NotePropertyValue $(if (Test-Finite $delta) { [math]::Round($delta, 10) } else { 'NaN' }) -Force
    $legD = $mis - $LegacyFullScalingChosenDefect
    Add-Member -InputObject $v -NotePropertyName delta_vs_legacy_full_scaling_chosen_defect -NotePropertyValue $(if (Test-Finite $mis) { [math]::Round($legD, 10) } else { 'NaN' }) -Force
}

$exportVariants = @()
foreach ($v in $variants) {
    $exportVariants += [pscustomobject]@{
        variant_id                                  = $v.variant_id
        description                                 = $v.description
        role                                        = $v.role
        transition_cutoff_K                         = $v.transition_cutoff_K
        n_curves                                    = $v.n_curves
        common_x_scaled_range                       = if ((Test-Finite $v.common_x_scaled_min) -and (Test-Finite $v.common_x_scaled_max)) { ('[' + [string]$v.common_x_scaled_min + ',' + [string]$v.common_x_scaled_max + ']') } else { 'NaN' }
        mean_intercurve_std                         = $v.mean_intercurve_std
        mean_rmse_to_master                         = $v.mean_rmse_to_master
        collapse_grid_size                          = $v.collapse_grid_size
        top_1_T_K                                   = $v.top_1_T_K
        top_1_curve_rmse                            = $v.top_1_curve_rmse
        top_2_T_K                                   = $v.top_2_T_K
        top_2_curve_rmse                            = $v.top_2_curve_rmse
        top_3_T_K                                   = $v.top_3_T_K
        top_3_curve_rmse                            = $v.top_3_curve_rmse
        delta_mean_std_vs_FULL_ALL_T               = $v.delta_mean_std_vs_FULL_ALL_T
        delta_vs_legacy_full_scaling_chosen_defect  = $v.delta_vs_legacy_full_scaling_chosen_defect
        legacy_full_scaling_chosen_reference_defect = $LegacyFullScalingChosenDefect
    }
}
$exportVariants | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_apples_to_apples_variants.csv')

# --- Failure by T (long)
$failRows = @()
foreach ($v in $variants) {
    $coll = $v._coll
    for ($i = 0; $i -lt $coll.temps.Length; $i++) {
        $tk = $coll.temps[$i]
        $dn = if ($tk -gt $TransitionCutoff_K) {
            'above_transition_diagnostic_only_not_equivalent_to_T22'
        }
        elseif ([math]::Abs($tk - $T22Nominal_K) -lt 0.25) {
            'primary_domain_T22_included_crossover_nominal_tag_only'
        }
        else {
            'primary_domain'
        }
        $failRows += [pscustomobject]@{
            variant_id           = $v.variant_id
            T_K                  = $tk
            curve_rmse_to_master = if (Test-Finite $coll.curve_rmse[$i]) { [math]::Round($coll.curve_rmse[$i], 10) } else { 'NaN' }
            domain_note          = $dn
        }
    }
}
$failRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_apples_to_apples_failure_by_T.csv')

# --- Verdicts
$excludedReduces = (Test-Finite $fullStd) -and (Test-Finite $primaryStd) -and ($primaryStd -lt $fullStd - 1e-12)
$matchLegacy = (Test-Finite $primaryStd) -and ([math]::Abs($primaryStd - $LegacyFullScalingChosenDefect) -le $LegacyMatchAbsTolerance)

# T22 outlier in PRIMARY when 22 is in domain: rank among PRIMARY_T_LT_31P5
$t22Row = $failRows | Where-Object { $_.variant_id -eq 'PRIMARY_T_LT_31P5' -and ([math]::Abs([double]$_.T_K - $T22Nominal_K) -lt 0.25) } | Select-Object -First 1
$primaryFails = @($failRows | Where-Object { $_.variant_id -eq 'PRIMARY_T_LT_31P5' } | ForEach-Object { [pscustomobject]@{ T_K = [double]$_.T_K; rmse = [double]$_.curve_rmse_to_master } } | Sort-Object rmse -Descending)
$t22Rank = 0
for ($ri = 0; $ri -lt $primaryFails.Count; $ri++) {
    if ([math]::Abs($primaryFails[$ri].T_K - $T22Nominal_K) -lt 0.25) { $t22Rank = $ri + 1; break }
}
$t22RemainsOutlier = ($t22Rank -ge 1) -and ($t22Rank -le 3)

# Non-reproduction: do not claim YES unless primary still wildly off legacy with matched domain
$realNonRepro = (Test-Finite $primaryStd) -and ($primaryStd -gt ($LegacyFullScalingChosenDefect + 0.08))

$sensRan = [bool]$vPrimaryEx22
$status = @(
    [pscustomobject]@{ verdict_key = 'TRANSITION_CUTOFF_31P5K_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'ABOVE_TRANSITION_T_EXCLUDED_FROM_PRIMARY_COLLAPSE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'EXCLUDING_ABOVE_TRANSITION_REDUCES_DEFECT'; verdict_value = if ($excludedReduces) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'PRIMARY_DOMAIN_COLLAPSE_MATCHES_LEGACY_DEFECT'; verdict_value = if ($matchLegacy) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'T22_REMAINS_PRIMARY_DOMAIN_OUTLIER'; verdict_value = if ($t22RemainsOutlier) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'T22_EXCLUSION_SENSITIVITY_VARIANT_RAN'; verdict_value = if ($sensRan) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'T22_EXCLUSION_SENSITIVITY_SKIPPED_NOT_DOMINANT_INTERNAL_OUTLIER'; verdict_value = if (-not $sensRan) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'REAL_CANONICAL_NON_REPRODUCTION_CONFIRMED'; verdict_value = if ($realNonRepro) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_collapse_apples_to_apples_status.csv')

# --- Report
$rp = Join-Path $RepoRoot 'reports/switching_old_collapse_apples_to_apples_replay.md'
$lines = @()
$lines += '# Old-collapse apples-to-apples replay with transition cutoff'
$lines += ''
$lines += '## Domain rule'
$lines += ('- Transition temperature taken as **~' + [string]$TransitionCutoff_K + ' K**.')
$lines += '- **Primary collapse metrics** use **`T_K < ' + [string]$TransitionCutoff_K + '`** only (**22 K** is included; it is **not** lumped with above-transition temperatures).'
$lines += '- **`T_K > ' + [string]$TransitionCutoff_K + '`** (here **32 K**, **34 K**) are **diagnostic-only**, not evidence against primary-domain collapse.'
$lines += ''
$lines += '## 22 K sensitivity'
$lines += ('- **Exclude-22-K variant** runs **only if** **22 K** is a **dominant internal outlier** within **`PRIMARY_T_LT_31P5`** (worst RMSE among primary-domain curves, or second-worst with RMSE >= **' + [string]$T22DominantMedianRatio + ' x** median RMSE of other primary curves).')
if ($sensRan) {
    $lines += '- **Sensitivity ran** (`T22_EXCLUSION_SENSITIVITY_VARIANT_RAN = YES`): see variant **`PRIMARY_T_LT_31P5_EXCL_T22_SENSITIVITY`**.'
}
else {
    $lines += '- **Sensitivity skipped** (`T22_EXCLUSION_SENSITIVITY_SKIPPED_NOT_DOMINANT_INTERNAL_OUTLIER = YES`): **22 K** did not meet the dominance rule; primary headline remains **`PRIMARY_T_LT_31P5`** only.'
}
$lines += ('- **22 K internal-outlier check (within primary only):** rank **' + [string]$t22Dom.rank + '** by curve RMSE (1 = worst), **t22_rmse=' + [string]([math]::Round([double]$t22Dom.t22_rmse, 8)) + '**, median RMSE other primary **' + [string]([math]::Round([double]$t22Dom.median_rmse_other_primary, 8)) + '**, **dominant=' + [string]$t22Dom.dominant + '**.' )
$lines += ''
$lines += '## Variant summary'
foreach ($ev in $exportVariants) {
    $lines += ('- **`' + $ev.variant_id + '`** (`' + $ev.role + '`): **n=' + [string]$ev.n_curves + '**, mean_intercurve_std **' + [string]$ev.mean_intercurve_std + '**, mean RMSE **' + [string]$ev.mean_rmse_to_master + '**, common **`' + $ev.common_x_scaled_range + '`**; top RMSE Ts **' + [string]$ev.top_1_T_K + '** / **' + [string]$ev.top_2_T_K + '** / **' + [string]$ev.top_3_T_K + '**.')
}
$lines += ''
$lines += '## Comparison to legacy `full_scaling_chosen`'
$lines += ('- Reference **`mean_intercurve_std`** from legacy table **`full_scaling_chosen`**: **~' + [string]$LegacyFullScalingChosenDefect + '** (not identical common support vs canonical replay).')
$lines += ('- Primary-domain replay (**`PRIMARY_T_LT_31P5`**): **' + [string]$vPrimary.mean_intercurve_std + '** (delta **' + [string]$vPrimary.delta_vs_legacy_full_scaling_chosen_defect + '**).')
if ($sensRan) {
    $lines += ''
    $lines += '## Exclude-22-K sensitivity (conditional)'
    $lines += '- Compare **`PRIMARY_T_LT_31P5`** (22 K **included**) to **`PRIMARY_T_LT_31P5_EXCL_T22_SENSITIVITY`** to quantify how much **22 K** pulls the primary defect when it was flagged as dominant.'
    $lines += ''
}
$lines += '## Outputs'
$lines += '- `tables/switching_old_collapse_apples_to_apples_variants.csv`'
$lines += '- `tables/switching_old_collapse_apples_to_apples_support_by_T.csv`'
$lines += '- `tables/switching_old_collapse_apples_to_apples_failure_by_T.csv`'
$lines += '- `tables/switching_old_collapse_apples_to_apples_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Apples-to-apples collapse replay written: $rp"
