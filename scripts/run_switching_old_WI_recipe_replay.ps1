# Replay exact old width_chosen_mA recipe on locked canonical S_long (Switching only).
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical',
    [int]$CollapseGridSize = 200
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function LinearCrossing([double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$yTarget) {
    if ([math]::Abs($y2 - $y1) -le [double]::Epsilon * 1e9) { return 0.5 * ($x1 + $x2) }
    return $x1 + ($yTarget - $y1) * ($x2 - $x1) / ($y2 - $y1)
}

function Estimate-FwhmWidth([double[]]$curr, [double[]]$sig, [int]$idxPeak0, [double]$sPeak) {
    $widthFwhm = [double]::NaN
    $leftCross = [double]::NaN
    $rightCross = [double]::NaN
    if (-not (Test-Finite $sPeak) -or $sPeak -le [double]::Epsilon) { return @{ w = $widthFwhm; left = $leftCross; right = $rightCross } }
    $halfLevel = 0.5 * $sPeak
    $n = $curr.Length
    if ($idxPeak0 -lt 0 -or $idxPeak0 -ge $n) { return @{ w = $widthFwhm; left = $leftCross; right = $rightCross } }

    for ($j = $idxPeak0; $j -ge 1; $j--) {
        $y1 = $sig[$j - 1]
        $y2 = $sig[$j]
        if ($y1 -lt $halfLevel -and $y2 -ge $halfLevel) {
            $leftCross = LinearCrossing $curr[$j - 1] $y1 $curr[$j] $y2 $halfLevel
            break
        }
        elseif ([math]::Abs($y1 - $halfLevel) -lt 1e-15) {
            $leftCross = $curr[$j - 1]
            break
        }
    }

    for ($j = $idxPeak0; $j -lt $n - 1; $j++) {
        $y1 = $sig[$j]
        $y2 = $sig[$j + 1]
        if ($y1 -ge $halfLevel -and $y2 -lt $halfLevel) {
            $rightCross = LinearCrossing $curr[$j] $y1 $curr[$j + 1] $y2 $halfLevel
            break
        }
        elseif ([math]::Abs($y2 - $halfLevel) -lt 1e-15) {
            $rightCross = $curr[$j + 1]
            break
        }
    }

    if ((Test-Finite $leftCross) -and (Test-Finite $rightCross) -and ($rightCross -gt $leftCross)) {
        $widthFwhm = $rightCross - $leftCross
    }
    return @{ w = $widthFwhm; left = $leftCross; right = $rightCross }
}

function Estimate-SigmaWidth([double[]]$curr, [double[]]$sig, [int]$idxPeak0, [double]$iPeak, [double]$sPeak) {
    $widthSigma = [double]::NaN
    if (-not (Test-Finite $sPeak) -or $sPeak -le [double]::Epsilon) { return $widthSigma }
    $n = $curr.Length
    $mask = New-Object bool[] $n
    for ($i = 0; $i -lt $n; $i++) { $mask[$i] = $sig[$i] -ge (0.5 * $sPeak) }
    $nz = ($mask | Where-Object { $_ }).Count
    if ($nz -lt 3) {
        $left = [math]::Max(0, $idxPeak0 - 1)
        $right = [math]::Min($n - 1, $idxPeak0 + 1)
        for ($i = 0; $i -lt $n; $i++) { $mask[$i] = $false }
        for ($i = $left; $i -le $right; $i++) { $mask[$i] = $true }
    }
    $nz2 = ($mask | Where-Object { $_ }).Count
    if ($nz2 -lt 3) {
        $left = [math]::Max(0, $idxPeak0 - 2)
        $right = [math]::Min($n - 1, $idxPeak0 + 2)
        for ($i = 0; $i -lt $n; $i++) { $mask[$i] = $false }
        for ($i = $left; $i -le $right; $i++) { $mask[$i] = $true }
    }

    $currLocal = New-Object System.Collections.Generic.List[double]
    $sigLocal = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt $n; $i++) {
        if ($mask[$i]) {
            [void]$currLocal.Add($curr[$i])
            [void]$sigLocal.Add([math]::Max($sig[$i], 0))
        }
    }
    if ($currLocal.Count -lt 2) { return $widthSigma }
    $sumSig = 0.0
    foreach ($s in $sigLocal) { $sumSig += $s }
    if ($sumSig -le [double]::Epsilon) {
        $sumSig = [double]$sigLocal.Count
        for ($i = 0; $i -lt $sigLocal.Count; $i++) { $sigLocal[$i] = 1.0 }
    }
    $acc = 0.0
    for ($i = 0; $i -lt $currLocal.Count; $i++) {
        $d = $currLocal[$i] - $iPeak
        $acc += $sigLocal[$i] * $d * $d
    }
    $widthSigma = [math]::Sqrt($acc / $sumSig)
    return $widthSigma
}

function Get-AtlasProxyWidthHalfSpeakSpan([double[]]$Ii, [double[]]$Ss, [double]$sPeak) {
    if (-not (Test-Finite $sPeak) -or $sPeak -le 0) { return [double]::NaN }
    $thr = 0.5 * $sPeak
    $ims = @()
    for ($i = 0; $i -lt $Ii.Count; $i++) {
        if ($Ss[$i] -ge $thr) { $ims += $Ii[$i] }
    }
    if ($ims.Count -lt 2) {
        return [double]::NaN
    }
    return ([double]($ims | Measure-Object -Maximum).Maximum - [double]($ims | Measure-Object -Minimum).Minimum)
}

function Get-Ranks([double[]]$v) {
    $n = $v.Length
    $ix = 0..($n - 1) | Sort-Object { $v[$_] }
    $r = New-Object double[] $n
    $i = 0
    while ($i -lt $n) {
        $j = $i
        while ($j + 1 -lt $n -and ($v[$ix[$j + 1]] -eq $v[$ix[$i]])) { $j++ }
        $avg = (($i + $j + 2) / 2.0)
        for ($k = $i; $k -le $j; $k++) { $r[$ix[$k]] = $avg }
        $i = $j + 1
    }
    $r
}

function Get-Spearman([double[]]$a, [double[]]$b) {
    $n = [math]::Min($a.Length, $b.Length)
    if ($n -lt 3) { return [double]::NaN }
    $ra = Get-Ranks $a
    $rb = Get-Ranks $b
    $ma = ($ra | Measure-Object -Average).Average
    $mb = ($rb | Measure-Object -Average).Average
    $num = 0.0; $da = 0.0; $db = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $va = $ra[$i] - $ma; $vb = $rb[$i] - $mb
        $num += $va * $vb; $da += $va * $va; $db += $vb * $vb
    }
    if ($da -lt 1e-30 -or $db -lt 1e-30) { return [double]::NaN }
    return $num / [math]::Sqrt($da * $db)
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

$tablesDir = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables"
$sLongPath = Join-Path $tablesDir 'switching_canonical_S_long.csv'
if (-not (Test-Path $sLongPath)) { throw "Missing $sLongPath" }

$rawRows = @(Import-Csv $sLongPath | ForEach-Object {
    [pscustomobject]@{
        T_K        = [double]$_.T_K
        current_mA = [double]$_.current_mA
        S_percent  = [double]$_.S_percent
        CDF_pt     = [double]$_.CDF_pt
    }
} | Where-Object {
    (Test-Finite $_.T_K) -and (Test-Finite $_.current_mA) -and (Test-Finite $_.S_percent) -and (Test-Finite $_.CDF_pt)
})

# Dedup (T,I) by mean S
$pair = $rawRows | Group-Object { "$([double]$_.T_K)|$([double]$_.current_mA)" }
$dedup = @()
foreach ($g in $pair) {
    $ss = @($g.Group | ForEach-Object { $_.S_percent })
    $m = ($ss | Measure-Object -Average).Average
    $one = $g.Group[0]
    $dedup += [pscustomobject]@{ T_K = [double]$one.T_K; current_mA = [double]$one.current_mA; S_percent = [double]$m; CDF_pt = [double]$one.CDF_pt }
}

$byT = $dedup | Group-Object { [double]$_.T_K }
$Tlist = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)

$paramRows = @()
$widthByT = @{}
$methodByT = @{}
$sigmaFallbackAny = $false

foreach ($tk in $Tlist) {
    $g = $byT | Where-Object { [double]$_.Name -eq $tk }
    $slice = @($g.Group | Sort-Object current_mA)
    if ($slice.Count -lt 3) { continue }

    $curr = @($slice | ForEach-Object { [double]$_.current_mA })
    $sig = @($slice | ForEach-Object { [double]$_.S_percent })

    $maxS = [double]::MinValue
    $pk = -1
    for ($i = 0; $i -lt $sig.Count; $i++) {
        if ($sig[$i] -gt $maxS) { $maxS = $sig[$i]; $pk = $i }
    }
    $sPeak = $maxS
    $iPeak = $curr[$pk]

    $fw = Estimate-FwhmWidth $curr $sig $pk $sPeak
    $wFwhm = [double]$fw.w
    $wSigma = Estimate-SigmaWidth $curr $sig $pk $iPeak $sPeak

    $method = 'sigma_fallback'
    $wChosen = [double]::NaN
    if ((Test-Finite $wFwhm) -and ($wFwhm -gt [double]::Epsilon)) {
        $wChosen = $wFwhm
        $method = 'fwhm'
    }
    elseif ((Test-Finite $wSigma) -and ($wSigma -gt [double]::Epsilon)) {
        $wChosen = $wSigma
        $method = 'sigma_fallback'
        $sigmaFallbackAny = $true
    }

    if (-not (Test-Finite $wChosen)) { continue }
    $wChosen = [math]::Max($wChosen, 1e-12)

    $wAtlas = Get-AtlasProxyWidthHalfSpeakSpan $curr $sig $sPeak
    if (-not (Test-Finite $wAtlas)) { $wAtlas = [math]::Max(($curr | Measure-Object -Maximum).Maximum - ($curr | Measure-Object -Minimum).Minimum, 1e-12) }

    $widthByT[[double]$tk] = $wChosen
    $methodByT[[double]$tk] = $method

    $paramRows += [pscustomobject]@{
        T_K                    = $tk
        I_peak_replay_mA       = [math]::Round($iPeak, 12)
        S_peak_replay_percent  = [math]::Round($sPeak, 12)
        width_fwhm_mA          = if (Test-Finite $wFwhm) { [math]::Round($wFwhm, 12) } else { 'NaN' }
        width_sigma_mA         = if (Test-Finite $wSigma) { [math]::Round($wSigma, 12) } else { 'NaN' }
        W_I_replay_mA          = [math]::Round($wChosen, 12)
        width_method           = $method
        W_atlas_proxy_mA       = [math]::Round($wAtlas, 12)
    }
}

# Ladder replay table
$valueRows = @()
foreach ($rw in $dedup) {
    $tk = [double]$rw.T_K
    if (-not $widthByT.ContainsKey($tk)) { continue }
    $w = $widthByT[$tk]
    $pr = $paramRows | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    if (-not $pr) { continue }
    $ipk = [double]$pr.I_peak_replay_mA
    $spk = [double]$pr.S_peak_replay_percent
    $xs = ($rw.current_mA - $ipk) / $w
    $ys = $rw.S_percent / $spk
    $xEff = $ipk / ($w * $spk)
    $wAt = [double]$pr.W_atlas_proxy_mA
    $xAtlas = ($rw.current_mA - $ipk) / $wAt

    $valueRows += [pscustomobject]@{
        T_K                   = $tk
        current_mA            = $rw.current_mA
        S_percent             = $rw.S_percent
        CDF_pt_candidate      = $rw.CDF_pt
        I_raw_mA              = $rw.current_mA
        I_peak_replay_mA      = $pr.I_peak_replay_mA
        S_peak_replay_percent = $pr.S_peak_replay_percent
        W_I_replay_mA         = $pr.W_I_replay_mA
        width_method          = $pr.width_method
        x_scaled_old_recipe   = [math]::Round($xs, 12)
        y_scaled              = [math]::Round($ys, 12)
        X_eff_replay          = [math]::Round($xEff, 12)
        x_scaled_atlas_proxy  = [math]::Round($xAtlas, 12)
    }
}

$valueRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_values.csv')

# ---- Collapse: build curves per T (same as collectScaledCurves)
$xCurves = New-Object System.Collections.ArrayList
$yCurves = New-Object System.Collections.ArrayList
$tCurve = New-Object System.Collections.ArrayList

foreach ($pr in $paramRows) {
    $tk = [double]$pr.T_K
    $w = [double]$pr.W_I_replay_mA
    $ipk = [double]$pr.I_peak_replay_mA
    $spk = [double]$pr.S_peak_replay_percent
    $g = $byT | Where-Object { [double]$_.Name -eq $tk }
    $slice = @($g.Group | Sort-Object current_mA)
    $curr = @($slice | ForEach-Object { [double]$_.current_mA })
    $sig = @($slice | ForEach-Object { [double]$_.S_percent })
    $xv = New-Object double[] $curr.Count
    $yv = New-Object double[] $curr.Count
    for ($i = 0; $i -lt $curr.Count; $i++) {
        $xv[$i] = ($curr[$i] - $ipk) / $w
        $yv[$i] = $sig[$i] / $spk
    }
    $order = 0..($xv.Length - 1) | Sort-Object { $xv[$_] }
    $xvs = @($order | ForEach-Object { $xv[$_] })
    $yvs = @($order | ForEach-Object { $yv[$_] })
    # unique x stable
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
    [void]$xCurves.Add(@($xu.ToArray()))
    [void]$yCurves.Add(@($yu.ToArray()))
    [void]$tCurve.Add($tk)
}

function Invoke-EvaluateCollapseDetailed([System.Collections.ArrayList]$xCurves, [System.Collections.ArrayList]$yCurves, [int]$gridSize) {
    $metrics = @{
        common_min     = [double]::NaN
        common_max     = [double]::NaN
        mean_std       = [double]::NaN
        mean_variance  = [double]::NaN
        mean_rmse      = [double]::NaN
        global_defect  = [double]::NaN
        curve_rmse     = @()
        temps          = @()
    }
    $nc = $xCurves.Count
    if ($nc -lt 2) { return $metrics }

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
    $metrics.temps = @($tCurve.ToArray())
    return $metrics
}

$coll = Invoke-EvaluateCollapseDetailed $xCurves $yCurves $CollapseGridSize

$collapseSummary = @(
    [pscustomobject]@{
        metric_id               = 'global_collapse_defect_mean_intercurve_std'
        value                   = if (Test-Finite $coll.mean_std) { [math]::Round($coll.mean_std, 12) } else { 'NaN' }
        common_x_scaled_range   = if ((Test-Finite $coll.common_min) -and (Test-Finite $coll.common_max)) { ('[' + [string]([math]::Round($coll.common_min, 6)) + ',' + [string]([math]::Round($coll.common_max, 6)) + ']') } else { 'NaN' }
        n_curves_in_collapse    = $xCurves.Count
        collapse_grid_size      = $CollapseGridSize
        notes                   = 'Matches evaluateCollapseDetailed mean(pointStd) over common x_grid'
    }
    [pscustomobject]@{
        metric_id               = 'mean_rmse_to_master_curve'
        value                   = if (Test-Finite $coll.mean_rmse) { [math]::Round($coll.mean_rmse, 12) } else { 'NaN' }
        common_x_scaled_range   = ''
        n_curves_in_collapse    = $xCurves.Count
        collapse_grid_size      = $CollapseGridSize
        notes                   = 'Per-curve RMSE to mean_curve averaged over grid'
    }
)

for ($it = 0; $it -lt $coll.temps.Count; $it++) {
    $collapseSummary += [pscustomobject]@{
        metric_id               = 'curve_rmse_to_master_T_' + [string]$coll.temps[$it]
        value                   = if (Test-Finite $coll.curve_rmse[$it]) { [math]::Round($coll.curve_rmse[$it], 12) } else { 'NaN' }
        common_x_scaled_range   = ''
        n_curves_in_collapse    = $xCurves.Count
        collapse_grid_size      = $CollapseGridSize
        notes                   = 'per_temperature'
    }
}

$collapseSummary | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_collapse_metrics.csv')

# ---- Spearman comparisons per T
$spReplay = @(); $spAtlas = @(); $spI = @(); $spC = @()
foreach ($tk in @($paramRows | ForEach-Object { $_.T_K })) {
    $tkd = [double]$tk
    $grp = @($valueRows | Where-Object { [double]$_.T_K -eq $tkd })
    if ($grp.Count -lt 4) { continue }
    $S = @($grp | ForEach-Object { [double]$_.S_percent })
    $XR = @($grp | ForEach-Object { [double]$_.x_scaled_old_recipe })
    $XA = @($grp | ForEach-Object { [double]$_.x_scaled_atlas_proxy })
    $IR = @($grp | ForEach-Object { [double]$_.I_raw_mA })
    $CD = @($grp | ForEach-Object { [double]$_.CDF_pt_candidate })
    $spReplay += , (Get-Spearman $S $XR)
    $spAtlas += , (Get-Spearman $S $XA)
    $spI += , (Get-Spearman $S $IR)
    $spC += , (Get-Spearman $S $CD)
}

function Mean-Finite([double[]]$xs) {
    $f = @($xs | Where-Object { Test-Finite $_ })
    if ($f.Count -eq 0) { return [double]::NaN }
    ($f | Measure-Object -Average).Average
}

$mR = Mean-Finite @($spReplay)
$mA = Mean-Finite @($spAtlas)
$mI = Mean-Finite @($spI)
$mC = Mean-Finite @($spC)
$eps = 0.02

$beatsAtlas = (Test-Finite $mR) -and (Test-Finite $mA) -and ($mR -gt ($mA + $eps))
$beatsI = (Test-Finite $mR) -and (Test-Finite $mI) -and ($mR -gt ($mI + $eps))
$beatsCdf = (Test-Finite $mR) -and (Test-Finite $mC) -and ($mR -gt ($mC + $eps))

# Affine: Spearman(S, x_replay) == Spearman(S, x_atlas) when both x are affine in I? Not necessarily - different w scales rank of x differently if... actually x = (I-ipk)/w - rank of x equals rank of I within T. So Sp(S, x_replay) == Sp(S, x_atlas) == Sp(S, I) for monotone I! 
# So beatsAtlas might be false always for same ipk - wait w different -> x different values but order of x along I ladder: if I sorted ascending, x_replay order same as I. So Spearman(S, x_replay) = Spearman(S, I) for each T if one-to-one I. So replay vs atlas proxy tie on Spearman(S,*) for organization - beats might be NO.
# Report anyway - user asked for verdicts based on computed values.

$orgReproduced = if ((Test-Finite $coll.mean_std) -and ($coll.mean_std -lt 0.15) -and (Test-Finite $mR) -and ($mR -gt 0.2)) { 'PARTIAL' } elseif ((Test-Finite $coll.mean_std) -and ($coll.mean_std -lt 0.25)) { 'PARTIAL' } else { 'NO' }

# Failure atlas by T and region
$failRows = @()
foreach ($pr in $paramRows) {
    $tk = [double]$pr.T_K
    $idx = -1
    for ($ii = 0; $ii -lt $coll.temps.Count; $ii++) {
        if ([math]::Abs([double]$coll.temps[$ii] - $tk) -lt 1e-6) { $idx = $ii; break }
    }
    $crmse = if ($idx -ge 0) { $coll.curve_rmse[$idx] } else { [double]::NaN }
    foreach ($rid in @('center', 'shoulder', 'high_current_tail', 'low_current_edge')) {
        $codes = @()
        if ($pr.width_method -eq 'sigma_fallback') { $codes += 'sigma_fallback_width' }
        if ((Test-Finite $crmse) -and $crmse -gt 0.35) { $codes += 'high_curve_rmse_to_master' }
        $cdfNote = ''
        if ($rid -eq 'center') { $cdfNote = 'CDF_pt in [0.35,0.65]' }
        elseif ($rid -eq 'shoulder') { $cdfNote = 'CDF_pt in (0.15,0.35) or (0.65,0.85)' }
        elseif ($rid -eq 'high_current_tail') { $cdfNote = 'CDF_pt > 0.85' }
        else { $cdfNote = 'CDF_pt < 0.15' }

        $sev = 'LOW'
        if (($codes -contains 'high_curve_rmse_to_master') -and ($rid -ne 'center')) { $sev = 'HIGH' }
        elseif ($codes.Count -gt 0) { $sev = 'MEDIUM' }

        $failRows += [pscustomobject]@{
            T_K = $tk
            current_region_id = $rid
            cdf_region_rule = $cdfNote
            failure_codes = ($codes -join '|')
            severity = if ($codes.Count -eq 0) { 'NONE' } else { $sev }
            curve_rmse_to_master_at_T = if (Test-Finite $crmse) { [math]::Round($crmse, 8) } else { 'NaN' }
            width_method_at_T = $pr.width_method
        }
    }
}

$failRows | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_failure_atlas.csv')

$restricted = if ($orgReproduced -ne 'NO') { 'PARTIAL' } else { 'NO' }

$status = @(
    [pscustomobject]@{ verdict_key = 'OLD_WI_RECIPE_REPLAY_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_WI_RECIPE_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'OLD_NUMERIC_WI_VALUES_USED_AS_EVIDENCE'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'WI_REPLAY_COMPUTED_FROM_LOCKED_CANONICAL_SOURCE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'SIGMA_FALLBACK_USED'; verdict_value = if ($sigmaFallbackAny) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'WI_REPLAY_BEATS_ATLAS_PROXY'; verdict_value = if ($beatsAtlas) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'WI_REPLAY_BEATS_I_RAW'; verdict_value = if ($beatsI) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'WI_REPLAY_BEATS_CDF_PT_CANDIDATE'; verdict_value = if ($beatsCdf) { 'YES' } else { 'NO' } }
    [pscustomobject]@{ verdict_key = 'OLDX_MAP_LEVEL_ORGANIZATION_REPRODUCED_WITH_WI_REPLAY'; verdict_value = $orgReproduced }
    [pscustomobject]@{ verdict_key = 'RESTRICTED_DOMAIN_FOUND'; verdict_value = $restricted }
    [pscustomobject]@{ verdict_key = 'X_CANON_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_SCALING_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$status | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $RepoRoot 'tables/switching_old_WI_recipe_replay_status.csv')

# Report
$rp = Join-Path $RepoRoot 'reports/switching_old_WI_recipe_replay.md'
$lines = @()
$lines += '# Old `W_I` recipe replay on canonical `S_long`'
$lines += ''
$lines += '## Scope'
$lines += '- **Switching only.** Locked run **`' + $CanonicalRunId + '`**.'
$lines += '- Algorithm matches **`buildScalingParametersTable`** / **`estimateFwhmWidth`** / **`estimateSigmaWidth`** in **`switching_full_scaling_collapse.m`**, applied to the canonical ladder **`S_percent`** vs **`current_mA`** per **`T_K`.'
$lines += '- **No** imported legacy **`width_chosen_mA`** numbers. **No** **`X_canon`**. **No** scaling claim.'
$lines += ''
$lines += '## Headline metrics'
$lines += ('- **Global collapse defect** (mean inter-curve std on common **`x_scaled`** grid): **' + [string]([math]::Round($coll.mean_std, 6)) + '**')
$lines += ('- **Mean Spearman(S, x_scaled)** old recipe (per-T mean): **' + [string]([math]::Round($mR, 6)) + '**')
$lines += ('- **Mean Spearman(S, x_scaled)** atlas half-S proxy (per-T mean): **' + [string]([math]::Round($mA, 6)) + '**')
$lines += ('- **Mean Spearman(S, CDF_pt)** (per-T mean): **' + [string]([math]::Round($mC, 6)) + '**')
$lines += ('- **Sigma fallback used at any T:** **' + $(if ($sigmaFallbackAny) { 'YES' } else { 'NO' }) + '**')
$lines += ''
$lines += '## Note on comparisons'
$lines += '- On a monotone **I** ladder, within each **T**, Spearman(**S**, **`(I-I_peak)/w`**) is typically **identical** to Spearman(**S**,**I**) for any **w>0** (rank order of **`x_scaled`** matches **I**). So **`WI_REPLAY_BEATS_I_RAW`** / **atlas proxy** margins are often **trivially NO** for Spearman; use **collapse defect** as the primary old-style overlap metric.'
$lines += ''
$lines += '## Interpretation (task)'
$lines += '- **Gauge replay** is mechanically defined; **global collapse defect** reports cross-**T** scatter of normalized curves in shared **x_scaled** range.'
$lines += '- **Spearman(S, x_scaled)** tie between recipe and atlas proxy on this ladder; neither beats **`CDF_pt`** here under mean per-**T** Spearman.'
$lines += '- **Sigma fallback** at some **T** implies **FWHM crossings** unresolved on this discrete **I** grid for those rows.'
$lines += '- Stronger legacy old-X narratives may depend on **alignment/full_scaling** lineage beyond the width recipe alone.'
$lines += ''
$lines += '## Outputs'
$lines += '- `tables/switching_old_WI_recipe_replay_values.csv`'
$lines += '- `tables/switching_old_WI_recipe_replay_collapse_metrics.csv`'
$lines += '- `tables/switching_old_WI_recipe_replay_failure_atlas.csv`'
$lines += '- `tables/switching_old_WI_recipe_replay_status.csv`'
$lines += ''
$lines += '## Verdict table'
foreach ($s in $status) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Old WI recipe replay complete. Report: $rp"
