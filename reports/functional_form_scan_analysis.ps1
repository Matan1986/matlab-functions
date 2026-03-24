$ErrorActionPreference = 'Stop'

function New-Key {
    param([double]$expA, [double]$expB, [double]$expC)
    return ('{0:F2}|{1:F2}|{2:F2}' -f $expA, $expB, $expC)
}

function Get-Pearson {
    param([double[]]$xVals, [double[]]$yVals)
    $n = $xVals.Count
    if ($n -lt 2) { return [double]::NaN }
    $mx = ($xVals | Measure-Object -Average).Average
    $my = ($yVals | Measure-Object -Average).Average
    $sx = 0.0; $sy = 0.0; $cov = 0.0
    for ($idx = 0; $idx -lt $n; $idx++) {
        $dx = $xVals[$idx] - $mx
        $dy = $yVals[$idx] - $my
        $cov += $dx * $dy
        $sx += $dx * $dx
        $sy += $dy * $dy
    }
    if ($sx -le 0 -or $sy -le 0) { return [double]::NaN }
    return $cov / [math]::Sqrt($sx * $sy)
}

function Get-Ranks {
    param([double[]]$vals)
    $n = $vals.Count
    $ranks = New-Object double[] $n
    $items = for ($idx = 0; $idx -lt $n; $idx++) {
        [pscustomobject]@{ i = $idx; v = [double]$vals[$idx] }
    }
    $sorted = $items | Sort-Object v, i
    $j = 0
    while ($j -lt $n) {
        $k = $j
        while ($k + 1 -lt $n -and $sorted[$k + 1].v -eq $sorted[$j].v) { $k++ }
        $rank = ($j + $k + 2) / 2.0
        for ($m = $j; $m -le $k; $m++) { $ranks[$sorted[$m].i] = $rank }
        $j = $k + 1
    }
    return $ranks
}

function Get-Spearman {
    param([double[]]$xVals, [double[]]$yVals)
    if ($xVals.Count -lt 2) { return [double]::NaN }
    return (Get-Pearson (Get-Ranks $xVals) (Get-Ranks $yVals))
}

function Get-YSeries {
    param(
        [double[]]$iPeakSeries,
        [double[]]$widthSeries,
        [double[]]$sPeakSeries,
        [double]$expA,
        [double]$expB,
        [double]$expC
    )
    $n = $iPeakSeries.Count
    $outVals = New-Object double[] $n
    for ($idx = 0; $idx -lt $n; $idx++) {
        $outVals[$idx] = [math]::Pow($iPeakSeries[$idx], $expA) / ([math]::Pow($widthSeries[$idx], $expB) * [math]::Pow($sPeakSeries[$idx], $expC))
    }
    return $outVals
}

function Get-PeakTemp {
    param([double[]]$vals, [double[]]$temps)
    $bestIdx = 0
    $bestVal = $vals[0]
    for ($idx = 1; $idx -lt $vals.Count; $idx++) {
        if ($vals[$idx] -gt $bestVal) { $bestVal = $vals[$idx]; $bestIdx = $idx }
    }
    return [double]$temps[$bestIdx]
}

function Get-LooMinCorr {
    param([double[]]$xVals, [double[]]$yVals)
    $n = $xVals.Count
    if ($n -lt 3) {
        return [pscustomobject]@{ looMinPearson = [double]::NaN; looMinSpearman = [double]::NaN }
    }
    $minP = [double]::PositiveInfinity
    $minS = [double]::PositiveInfinity
    for ($dropIdx = 0; $dropIdx -lt $n; $dropIdx++) {
        $xSub = New-Object System.Collections.Generic.List[double]
        $ySub = New-Object System.Collections.Generic.List[double]
        for ($idx = 0; $idx -lt $n; $idx++) {
            if ($idx -eq $dropIdx) { continue }
            [void]$xSub.Add($xVals[$idx])
            [void]$ySub.Add($yVals[$idx])
        }
        $p = Get-Pearson $xSub.ToArray() $ySub.ToArray()
        $s = Get-Spearman $xSub.ToArray() $ySub.ToArray()
        if ($p -lt $minP) { $minP = $p }
        if ($s -lt $minS) { $minS = $s }
    }
    return [pscustomobject]@{ looMinPearson = $minP; looMinSpearman = $minS }
}

function Get-Basic {
    param(
        [double]$expA, [double]$expB, [double]$expC,
        [double[]]$iPeakSeries, [double[]]$widthSeries, [double[]]$sPeakSeries,
        [double[]]$relaxSeries, [double[]]$tempSeries
    )
    $yVals = Get-YSeries $iPeakSeries $widthSeries $sPeakSeries $expA $expB $expC
    $pear = Get-Pearson $yVals $relaxSeries
    $spear = Get-Spearman $yVals $relaxSeries
    $deltaT = [math]::Abs((Get-PeakTemp $yVals $tempSeries) - (Get-PeakTemp $relaxSeries $tempSeries))
    $loo = Get-LooMinCorr $yVals $relaxSeries
    return [pscustomobject]@{
        a = $expA; b = $expB; c = $expC
        pearson_A = $pear
        spearman_A = $spear
        deltaT_peak = $deltaT
        loo_min_pearson = $loo.looMinPearson
        loo_min_spearman = $loo.looMinSpearman
    }
}

function Get-PowerFit {
    param([double[]]$xVals, [double[]]$yVals)
    if ($xVals.Count -lt 2) { return [pscustomobject]@{ beta = [double]::NaN; r2 = [double]::NaN; resid = @(); residRms = [double]::NaN } }
    if (($xVals | Where-Object { $_ -le 0 }).Count -gt 0 -or ($yVals | Where-Object { $_ -le 0 }).Count -gt 0) {
        return [pscustomobject]@{ beta = [double]::NaN; r2 = [double]::NaN; resid = @(); residRms = [double]::NaN }
    }
    $lx = @($xVals | ForEach-Object { [math]::Log($_) })
    $ly = @($yVals | ForEach-Object { [math]::Log($_) })
    $mx = ($lx | Measure-Object -Average).Average
    $my = ($ly | Measure-Object -Average).Average
    $num = 0.0; $den = 0.0
    for ($idx = 0; $idx -lt $lx.Count; $idx++) {
        $dx = $lx[$idx] - $mx
        $num += $dx * ($ly[$idx] - $my)
        $den += $dx * $dx
    }
    if ($den -eq 0) { return [pscustomobject]@{ beta = [double]::NaN; r2 = [double]::NaN; resid = @(); residRms = [double]::NaN } }
    $beta = $num / $den
    $intercept = $my - $beta * $mx
    $scaleC = [math]::Exp($intercept)
    $yMean = ($yVals | Measure-Object -Average).Average
    $ssRes = 0.0; $ssTot = 0.0
    $resid = New-Object double[] $xVals.Count
    for ($idx = 0; $idx -lt $xVals.Count; $idx++) {
        $yhat = $scaleC * [math]::Pow($xVals[$idx], $beta)
        $res = $yVals[$idx] - $yhat
        $resid[$idx] = $res
        $ssRes += $res * $res
        $dy = $yVals[$idx] - $yMean
        $ssTot += $dy * $dy
    }
    $r2 = if ($ssTot -gt 0) { 1.0 - $ssRes / $ssTot } else { [double]::NaN }
    $rms = [math]::Sqrt($ssRes / $xVals.Count)
    return [pscustomobject]@{ beta = $beta; r2 = $r2; resid = $resid; residRms = $rms }
}

function Get-ResidSummary {
    param([double[]]$residVals, [double[]]$tempSeries)
    if ($residVals.Count -lt 2) { return [pscustomobject]@{ corrT = [double]::NaN; signChanges = 0 } }
    $corrT = Get-Pearson $residVals $tempSeries
    $changes = 0
    $prev = 0
    for ($idx = 0; $idx -lt $residVals.Count; $idx++) {
        $sgn = if ($residVals[$idx] -gt 0) { 1 } elseif ($residVals[$idx] -lt 0) { -1 } else { 0 }
        if ($sgn -eq 0) { continue }
        if ($prev -ne 0 -and $sgn -ne $prev) { $changes++ }
        $prev = $sgn
    }
    return [pscustomobject]@{ corrT = $corrT; signChanges = $changes }
}

function Get-PerturbSensitivity {
    param(
        [double]$expA, [double]$expB, [double]$expC, [double]$basePearson,
        [double[]]$iPeakSeries, [double[]]$widthSeries, [double[]]$sPeakSeries,
        [double[]]$relaxSeries, [double[]]$tempSeries
    )
    $eps = 0.05
    $axisDefs = @(
        [pscustomobject]@{ axis = 'a'; sign = 1.0 }, [pscustomobject]@{ axis = 'a'; sign = -1.0 },
        [pscustomobject]@{ axis = 'b'; sign = 1.0 }, [pscustomobject]@{ axis = 'b'; sign = -1.0 },
        [pscustomobject]@{ axis = 'c'; sign = 1.0 }, [pscustomobject]@{ axis = 'c'; sign = -1.0 }
    )
    $deltas = New-Object System.Collections.Generic.List[double]
    foreach ($item in $axisDefs) {
        $a2 = $expA; $b2 = $expB; $c2 = $expC
        if ($item.axis -eq 'a') { $a2 = $expA + ($item.sign * $eps) }
        if ($item.axis -eq 'b') { $b2 = $expB + ($item.sign * $eps) }
        if ($item.axis -eq 'c') { $c2 = $expC + ($item.sign * $eps) }
        if ($a2 -lt 0.5 -or $a2 -gt 2.0 -or $b2 -lt 0.5 -or $b2 -gt 2.0 -or $c2 -lt 0.5 -or $c2 -gt 2.0) { continue }
        $basic = Get-Basic $a2 $b2 $c2 $iPeakSeries $widthSeries $sPeakSeries $relaxSeries $tempSeries
        [void]$deltas.Add([math]::Abs($basic.pearson_A - $basePearson))
    }
    if ($deltas.Count -eq 0) { return [double]::NaN }
    return (($deltas | Measure-Object -Average).Average)
}

function Get-BasicScore {
    param($row)
    $peakScore = [math]::Max(0.0, 1.0 - ($row.deltaT_peak / 10.0))
    return (0.35 * [math]::Abs($row.spearman_A) + 0.30 * [math]::Abs($row.pearson_A) + 0.20 * $row.loo_min_pearson + 0.15 * $peakScore)
}

$mergedPath = 'results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv'
$dimPath = 'results/cross_experiment/runs/run_2026_03_22_091808_dimensionless_constrained_basin_scan/tables/dimensionless_constrained_scan_full.csv'
$stabilityPath = 'reports/stability_basin_report.md'
$agingRPath = 'results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv'

$baseRows = Import-Csv $mergedPath | Sort-Object { [double]$_.T_K }
[double[]]$tempSeries = @($baseRows | ForEach-Object { [double]$_.T_K })
[double[]]$relaxSeries = @($baseRows | ForEach-Object { [double]$_.A_interp })
[double[]]$iPeakSeries = @($baseRows | ForEach-Object { [double]$_.I_peak_mA })
[double[]]$widthSeries = @($baseRows | ForEach-Object { [double]$_.width_mA })
[double[]]$sPeakSeries = @($baseRows | ForEach-Object { [double]$_.S_peak })

$agingRows = Import-Csv $agingRPath | Where-Object { $_.R_tau_FM_over_tau_dip -ne 'NaN' -and $_.R_tau_FM_over_tau_dip -ne '' }
$agingRByT = @{}
foreach ($row in $agingRows) { $agingRByT[[double]$row.Tp] = [double]$row.R_tau_FM_over_tau_dip }

$priorMap = @{}

# Parse 27-point table from stability report
foreach ($line in (Get-Content $stabilityPath)) {
    if ($line -match '^\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|\s*([0-9.]+)\s*\|\s*([\-0-9.]+)\s*\|\s*([\-0-9.]+)\s*\|\s*([\-0-9.]+)\s*\|\s*([\-0-9.]+)\s*\|\s*([\-0-9.]+)\s*\|\s*([0-9]+)\s*\|') {
        $a0 = [double]$matches[1]; $b0 = [double]$matches[2]; $c0 = [double]$matches[3]
        $k = New-Key $a0 $b0 $c0
        $priorMap[$k] = [pscustomobject]@{
            a = $a0; b = $b0; c = $c0
            pearson_A = [double]$matches[4]
            spearman_A = [double]$matches[5]
            deltaT_peak = [double]$matches[6]
            loo_min_pearson = [double]$matches[7]
            loo_min_spearman = [double]$matches[8]
            source = 'reused_stability_27'
        }
    }
}

# Reuse dimensionless constrained points
foreach ($row in (Import-Csv $dimPath)) {
    $a0 = [double]$row.p; $b0 = [double]$row.p; $c0 = [double]$row.c
    $k = New-Key $a0 $b0 $c0
    if (-not $priorMap.ContainsKey($k)) {
        $priorMap[$k] = [pscustomobject]@{
            a = $a0; b = $b0; c = $c0
            pearson_A = [double]$row.pearson
            spearman_A = [double]$row.spearman
            deltaT_peak = [double]$row.DeltaT_peak
            loo_min_pearson = [double]$row.loo_min_pearson
            loo_min_spearman = [double]$row.loo_min_spearman
            source = 'reused_dimless_121'
        }
    }
}

$coarseVals = @(0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0)
$coarseMap = @{}
$coarseReuse = 0
$coarseCompute = 0
foreach ($a0 in $coarseVals) {
    foreach ($b0 in $coarseVals) {
        foreach ($c0 in $coarseVals) {
            $k = New-Key $a0 $b0 $c0
            if ($priorMap.ContainsKey($k)) {
                $coarseMap[$k] = $priorMap[$k]
                $coarseReuse++
            }
            else {
                $m = Get-Basic $a0 $b0 $c0 $iPeakSeries $widthSeries $sPeakSeries $relaxSeries $tempSeries
                $coarseMap[$k] = [pscustomobject]@{
                    a = $m.a; b = $m.b; c = $m.c
                    pearson_A = $m.pearson_A
                    spearman_A = $m.spearman_A
                    deltaT_peak = $m.deltaT_peak
                    loo_min_pearson = $m.loo_min_pearson
                    loo_min_spearman = $m.loo_min_spearman
                    source = 'computed_coarse_extension'
                }
                $coarseCompute++
            }
        }
    }
}

$coarseRanked = @($coarseMap.Values | ForEach-Object {
    [pscustomobject]@{
        a = $_.a; b = $_.b; c = $_.c
        pearson_A = $_.pearson_A; spearman_A = $_.spearman_A
        deltaT_peak = $_.deltaT_peak
        loo_min_pearson = $_.loo_min_pearson; loo_min_spearman = $_.loo_min_spearman
        source = $_.source
        score_basic = Get-BasicScore $_
    }
} | Sort-Object score_basic -Descending)

$seedCount = 8
$seedRows = @($coarseRanked | Select-Object -First $seedCount)
$refineMap = @{}
$refineCompute = 0
foreach ($seed in $seedRows) {
    for ($da = -0.15; $da -le 0.1501; $da += 0.05) {
        for ($db = -0.15; $db -le 0.1501; $db += 0.05) {
            for ($dc = -0.15; $dc -le 0.1501; $dc += 0.05) {
                $a1 = [math]::Round($seed.a + $da, 2)
                $b1 = [math]::Round($seed.b + $db, 2)
                $c1 = [math]::Round($seed.c + $dc, 2)
                if ($a1 -lt 0.5 -or $a1 -gt 2.0 -or $b1 -lt 0.5 -or $b1 -gt 2.0 -or $c1 -lt 0.5 -or $c1 -gt 2.0) { continue }
                $k = New-Key $a1 $b1 $c1
                if ($coarseMap.ContainsKey($k) -or $refineMap.ContainsKey($k)) { continue }
                $m = Get-Basic $a1 $b1 $c1 $iPeakSeries $widthSeries $sPeakSeries $relaxSeries $tempSeries
                $refineMap[$k] = [pscustomobject]@{
                    a = $m.a; b = $m.b; c = $m.c
                    pearson_A = $m.pearson_A
                    spearman_A = $m.spearman_A
                    deltaT_peak = $m.deltaT_peak
                    loo_min_pearson = $m.loo_min_pearson
                    loo_min_spearman = $m.loo_min_spearman
                    source = 'computed_refine_extension'
                }
                $refineCompute++
            }
        }
    }
}

$allMap = @{}
foreach ($pair in $coarseMap.GetEnumerator()) { $allMap[$pair.Key] = $pair.Value }
foreach ($pair in $refineMap.GetEnumerator()) { $allMap[$pair.Key] = $pair.Value }

$allRanked = @($allMap.Values | ForEach-Object {
    [pscustomobject]@{
        a = $_.a; b = $_.b; c = $_.c
        pearson_A = $_.pearson_A; spearman_A = $_.spearman_A
        deltaT_peak = $_.deltaT_peak
        loo_min_pearson = $_.loo_min_pearson; loo_min_spearman = $_.loo_min_spearman
        source = $_.source
        score_basic = Get-BasicScore $_
    }
} | Sort-Object score_basic -Descending)

$diagKeySet = New-Object System.Collections.Generic.HashSet[string]
foreach ($row in ($allRanked | Select-Object -First 25)) { [void]$diagKeySet.Add((New-Key $row.a $row.b $row.c)) }
[void]$diagKeySet.Add((New-Key 1.0 1.0 1.0))
foreach ($row in $allRanked) {
    if ([math]::Abs($row.a - 1.0) -le 0.15 -and [math]::Abs($row.b - 1.0) -le 0.15 -and [math]::Abs($row.c - 1.0) -le 0.15) {
        [void]$diagKeySet.Add((New-Key $row.a $row.b $row.c))
    }
}
# Add explicit off-basin probes for failure-mode characterization.
$misalignProbe = $allRanked | Where-Object { $_.deltaT_peak -ge 4 } | Select-Object -First 1
if ($null -ne $misalignProbe) { [void]$diagKeySet.Add((New-Key $misalignProbe.a $misalignProbe.b $misalignProbe.c)) }
$unstableProbe = $allRanked | Where-Object { $_.loo_min_pearson -lt 0.94 } | Select-Object -First 1
if ($null -ne $unstableProbe) { [void]$diagKeySet.Add((New-Key $unstableProbe.a $unstableProbe.b $unstableProbe.c)) }
foreach ($probe in @(
    [pscustomobject]@{ a = 2.0; b = 2.0; c = 2.0 },
    [pscustomobject]@{ a = 2.0; b = 0.5; c = 2.0 },
    [pscustomobject]@{ a = 0.5; b = 2.0; c = 0.5 },
    [pscustomobject]@{ a = 2.0; b = 2.0; c = 0.5 }
)) {
    $kProbe = New-Key $probe.a $probe.b $probe.c
    if ($allMap.ContainsKey($kProbe)) { [void]$diagKeySet.Add($kProbe) }
}

$diagRows = @()
foreach ($k in $diagKeySet) {
    $base = $allMap[$k]
    $yVals = Get-YSeries $iPeakSeries $widthSeries $sPeakSeries $base.a $base.b $base.c
    $fit = Get-PowerFit $yVals $relaxSeries
    $residInfo = Get-ResidSummary $fit.resid $tempSeries

    $ovY = New-Object System.Collections.Generic.List[double]
    $ovR = New-Object System.Collections.Generic.List[double]
    for ($idx = 0; $idx -lt $tempSeries.Count; $idx++) {
        $tp = [double]$tempSeries[$idx]
        if ($agingRByT.ContainsKey($tp)) {
            [void]$ovY.Add($yVals[$idx])
            [void]$ovR.Add([double]$agingRByT[$tp])
        }
    }
    $corrRP = [double]::NaN
    $corrRS = [double]::NaN
    if ($ovY.Count -ge 3) {
        $corrRP = Get-Pearson $ovY.ToArray() $ovR.ToArray()
        $corrRS = Get-Spearman $ovY.ToArray() $ovR.ToArray()
    }

    $pert = Get-PerturbSensitivity $base.a $base.b $base.c $base.pearson_A $iPeakSeries $widthSeries $sPeakSeries $relaxSeries $tempSeries
    $peakScore = [math]::Max(0.0, 1.0 - ($base.deltaT_peak / 10.0))
    $agingTerm = if ([double]::IsNaN($corrRP)) { 0.0 } else { [math]::Abs($corrRP) }
    $scoreFinal = (
        0.28 * [math]::Abs($base.spearman_A) +
        0.25 * [math]::Abs($base.pearson_A) +
        0.17 * $fit.r2 +
        0.12 * $base.loo_min_pearson +
        0.10 * $peakScore +
        0.08 * $agingTerm
    )

    $diagRows += [pscustomobject]@{
        a = $base.a; b = $base.b; c = $base.c
        source = $base.source
        pearson_A = $base.pearson_A; spearman_A = $base.spearman_A
        deltaT_peak = $base.deltaT_peak
        loo_min_pearson = $base.loo_min_pearson; loo_min_spearman = $base.loo_min_spearman
        beta = $fit.beta
        power_r2 = $fit.r2
        resid_rms = $fit.residRms
        resid_corr_T = $residInfo.corrT
        resid_sign_changes = $residInfo.signChanges
        corr_R_pearson = $corrRP
        corr_R_spearman = $corrRS
        R_overlap_n = $ovY.Count
        perturb_sens_0p05 = $pert
        score_final = $scoreFinal
    }
}

$diagRanked = @($diagRows | Sort-Object score_final -Descending)
$top10 = @($diagRanked | Select-Object -First 10)

$xKey = New-Key 1.0 1.0 1.0
$xBasic = $allMap[$xKey]
$xDiag = $diagRows | Where-Object { (New-Key $_.a $_.b $_.c) -eq $xKey } | Select-Object -First 1

$xRankAll = -1
for ($rankIdx = 0; $rankIdx -lt $allRanked.Count; $rankIdx++) {
    $r = $allRanked[$rankIdx]
    if ((New-Key $r.a $r.b $r.c) -eq $xKey) {
        $xRankAll = $rankIdx + 1
        break
    }
}

$best = $allRanked[0]
$nearBasin = @($allRanked | Where-Object {
    [math]::Abs($_.spearman_A) -ge ([math]::Abs($best.spearman_A) - 0.01) -and
    [math]::Abs($_.pearson_A) -ge ([math]::Abs($best.pearson_A) - 0.01) -and
    $_.deltaT_peak -le 2 -and
    $_.loo_min_pearson -ge ($best.loo_min_pearson - 0.01)
})

$xClass = ''
if ($xRankAll -eq 1) { $xClass = 'optimal' }
elseif ($xRankAll -le 20 -and $xBasic.score_basic -ge ($best.score_basic - 0.01)) { $xClass = 'near-optimal' }
elseif ($nearBasin.Count -ge 20 -and $xBasic.deltaT_peak -le 2) { $xClass = 'in a broad basin' }
else { $xClass = 'outside strongest basin core' }

$misalign = $diagRows | Where-Object { $_.deltaT_peak -ge 4 } | Sort-Object score_final -Descending | Select-Object -First 1
$agingBreak = $diagRows | Where-Object { $_.R_overlap_n -ge 3 -and (-not [double]::IsNaN($_.corr_R_pearson)) -and [math]::Abs($_.corr_R_pearson) -lt 0.85 } | Sort-Object score_final -Descending | Select-Object -First 1
$instability = $diagRows | Where-Object { $_.perturb_sens_0p05 -gt 0.01 -or $_.loo_min_pearson -lt 0.94 } | Sort-Object score_final -Descending | Select-Object -First 1
$degraded = $diagRows | Where-Object { $_.power_r2 -lt 0.93 -or [math]::Abs($_.resid_corr_T) -gt 0.4 } | Sort-Object score_final -Descending | Select-Object -First 1

$coarseCsv = 'reports/functional_form_scan_coarse_extended.csv'
$refineCsv = 'reports/functional_form_scan_refined_extended.csv'
$diagCsv = 'reports/functional_form_scan_diagnostics.csv'
$reportPath = 'reports/functional_form_scan_report.md'

$coarseRanked | Export-Csv -NoTypeInformation -Encoding UTF8 $coarseCsv
@($refineMap.Values | ForEach-Object {
    [pscustomobject]@{
        a = $_.a; b = $_.b; c = $_.c
        pearson_A = $_.pearson_A; spearman_A = $_.spearman_A
        deltaT_peak = $_.deltaT_peak
        loo_min_pearson = $_.loo_min_pearson; loo_min_spearman = $_.loo_min_spearman
        source = $_.source
        score_basic = Get-BasicScore $_
    }
} | Sort-Object score_basic -Descending) | Export-Csv -NoTypeInformation -Encoding UTF8 $refineCsv
$diagRanked | Export-Csv -NoTypeInformation -Encoding UTF8 $diagCsv

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Functional Form Scan Report')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Scope and constraints')
[void]$sb.AppendLine('- Reused aligned table only: `results/cross_experiment/runs/run_2026_03_13_082753_switching_relaxation_bridge_robustness_a/tables/merged_relaxation_switching_table.csv`.')
[void]$sb.AppendLine('- Reused aging R(T) where available: `results/aging/runs/run_2026_03_14_074613_aging_clock_ratio_analysis/tables/table_clock_ratio.csv` (`R_tau_FM_over_tau_dip`).')
[void]$sb.AppendLine('- No raw data recomputation and no new observables were created.')
[void]$sb.AppendLine('- Existing scans reused first: 27-point local basin + 121-point constrained basin.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Scan design (coarse-to-fine)')
[void]$sb.AppendLine('- Family: `Y_{a,b,c}(T) = I_peak(T)^a / (w(T)^b * S_peak(T)^c)`.')
[void]$sb.AppendLine('- Domain: `a,b,c in [0.5, 2]`.')
[void]$sb.AppendLine(('- Coarse: 343 points (`step=0.25`), reused={0}, newly computed={1}.' -f $coarseReuse, $coarseCompute))
[void]$sb.AppendLine(('- Refine: around top {0} seeds (`delta=+-0.15`, `step=0.05`), newly computed={1}.' -f $seedCount, $refineCompute))
[void]$sb.AppendLine(('- Total unique candidates (basic metrics): {0}.' -f $allMap.Count))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Top candidates (ranked)')
[void]$sb.AppendLine('| Rank | a | b | c | Pearson(A,Y) | Spearman(A,Y) | beta | power R^2 | |DeltaT| K | corr(Y,R) Pearson | LOO min Pearson | perturb sens |')
[void]$sb.AppendLine('|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
$rank = 1
foreach ($row in $top10) {
    [void]$sb.AppendLine(('| {0} | {1:N2} | {2:N2} | {3:N2} | {4:N6} | {5:N6} | {6:N4} | {7:N6} | {8:N2} | {9:N6} | {10:N6} | {11:N6} |' -f $rank, $row.a, $row.b, $row.c, $row.pearson_A, $row.spearman_A, $row.beta, $row.power_r2, $row.deltaT_peak, $row.corr_R_pearson, $row.loo_min_pearson, $row.perturb_sens_0p05))
    $rank++
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Canonical X = (1,1,1)')
[void]$sb.AppendLine(('- X rank in full scanned set: {0}/{1}.' -f $xRankAll, $allMap.Count))
[void]$sb.AppendLine(('- X basic metrics: Pearson={0:N6}, Spearman={1:N6}, |DeltaT|={2:N2} K, LOO min Pearson={3:N6}.' -f $xBasic.pearson_A, $xBasic.spearman_A, $xBasic.deltaT_peak, $xBasic.loo_min_pearson))
if ($null -ne $xDiag) {
    [void]$sb.AppendLine(('- X scaling/aging/stability: beta={0:N4}, power R^2={1:N6}, corr(Y,R) Pearson={2:N6} (n={3}), perturb sensitivity={4:N6}.' -f $xDiag.beta, $xDiag.power_r2, $xDiag.corr_R_pearson, $xDiag.R_overlap_n, $xDiag.perturb_sens_0p05))
}
[void]$sb.AppendLine(('- X classification: **{0}**.' -f $xClass))
[void]$sb.AppendLine(('- Broad near-best basin size: {0} candidates.' -f $nearBasin.Count))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Failure modes of alternatives')
if ($null -ne $misalign) {
    [void]$sb.AppendLine(('- Misalignment: `(a,b,c)=({0:N2},{1:N2},{2:N2})`, |DeltaT|={3:N2} K.' -f $misalign.a, $misalign.b, $misalign.c, $misalign.deltaT_peak))
}
if ($null -ne $agingBreak) {
    [void]$sb.AppendLine(('- Aging breakdown: `(a,b,c)=({0:N2},{1:N2},{2:N2})`, corr(Y,R) Pearson={3:N6} (n={4}).' -f $agingBreak.a, $agingBreak.b, $agingBreak.c, $agingBreak.corr_R_pearson, $agingBreak.R_overlap_n))
}
if ($null -ne $instability) {
    [void]$sb.AppendLine(('- Instability: `(a,b,c)=({0:N2},{1:N2},{2:N2})`, perturb sensitivity={3:N6}, LOO min Pearson={4:N6}.' -f $instability.a, $instability.b, $instability.c, $instability.perturb_sens_0p05, $instability.loo_min_pearson))
}
if ($null -ne $degraded) {
    [void]$sb.AppendLine(('- Degraded scaling: `(a,b,c)=({0:N2},{1:N2},{2:N2})`, power R^2={3:N6}, corr(T,resid)={4:N6}.' -f $degraded.a, $degraded.b, $degraded.c, $degraded.power_r2, $degraded.resid_corr_T))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Verdict')
$preferred = ($xRankAll -le 10) -or ($xClass -eq 'near-optimal')
if ($preferred -and $nearBasin.Count -ge 20) {
    [void]$sb.AppendLine('X is structurally preferred as a canonical representative, but not uniquely optimal: it lies in a broad high-quality basin.')
}
elseif ($preferred) {
    [void]$sb.AppendLine('X is structurally preferred and near-optimal in this family.')
}
else {
    [void]$sb.AppendLine('X is not uniquely preferred; multiple parameterizations are effectively equivalent or better on the scanned criteria.')
}

Set-Content -Path $reportPath -Value $sb.ToString() -Encoding UTF8
Write-Output ('WROTE_REPORT=' + (Resolve-Path $reportPath).Path)
Write-Output ('WROTE_COARSE=' + (Resolve-Path $coarseCsv).Path)
Write-Output ('WROTE_REFINE=' + (Resolve-Path $refineCsv).Path)
Write-Output ('WROTE_DIAG=' + (Resolve-Path $diagCsv).Path)
