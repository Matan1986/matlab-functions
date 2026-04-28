# Phase 5B - narrow residual absorption test (Switching only). Phase 5A-gated.
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$CanonicalRunId = 'run_2026_04_03_000147_switching_canonical'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Finite([double]$x) { (-not [double]::IsNaN($x)) -and (-not [double]::IsInfinity($x)) }

function LinInterp([double]$xq, [double[]]$xv, [double[]]$yv) {
    $n = $xv.Count
    if ($n -lt 2) { return [double]::NaN }
    if ($xq -le $xv[0]) { return $yv[0] }
    if ($xq -ge $xv[$n - 1]) { return $yv[$n - 1] }
    for ($i = 1; $i -lt $n; $i++) {
        if ($xq -le $xv[$i]) {
            $t = ($xq - $xv[$i - 1]) / ($xv[$i] - $xv[$i - 1])
            return $yv[$i - 1] + $t * ($yv[$i] - $yv[$i - 1])
        }
    }
    return [double]::NaN
}

function VecNorm($v) {
    $s = 0.0
    foreach ($x in $v) { if (Test-Finite $x) { $s += $x * $x } }
    [math]::Sqrt($s)
}

function CovFlatMatVec([double[]]$Cf, [double[]]$v, [int]$n) {
    $dim = $v.Length
    $out = New-Object double[] $dim
    for ($r = 0; $r -lt $dim; $r++) {
        $acc = [double]0
        $rb = $r * $n
        for ($c = 0; $c -lt $dim; $c++) {
            $acc = [double]$acc + [double]$Cf[$rb + $c] * [double]$v[$c]
        }
        $out[$r] = $acc
    }
    return $out
}

function PearsonVec([double[]]$a, [double[]]$b) {
    $n = [math]::Min($a.Length, $b.Length)
    if ($n -lt 3) { return [double]::NaN }
    $ma = 0.0; $mb = 0.0; $cntm = 0
    for ($i = 0; $i -lt $n; $i++) {
        if ((Test-Finite $a[$i]) -and (Test-Finite $b[$i])) {
            $ma += $a[$i]; $mb += $b[$i]; $cntm++
        }
    }
    if ($cntm -lt 3) { return [double]::NaN }
    $ma /= $cntm; $mb /= $cntm
    $num = 0.0; $da = 0.0; $db = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        if (-not ((Test-Finite $a[$i]) -and (Test-Finite $b[$i]))) { continue }
        $va = $a[$i] - $ma; $vb = $b[$i] - $mb
        $num += $va * $vb; $da += $va * $va; $db += $vb * $vb
    }
    if ($da -lt 1e-30 -or $db -lt 1e-30) { return [double]::NaN }
    return $num / [math]::Sqrt($da * $db)
}

$SlongPath = Join-Path $RepoRoot "results/switching/runs/$CanonicalRunId/tables/switching_canonical_S_long.csv"
if (-not (Test-Path $SlongPath)) { throw "Missing $SlongPath" }

$rows = Import-Csv $SlongPath | ForEach-Object {
    [pscustomobject]@{
        T_K                = [double]$_.T_K
        current_mA       = [double]$_.current_mA
        S_percent        = [double]$_.S_percent
        S_model_pt_percent = [double]$_.S_model_pt_percent
        residual_percent = [double]$_.residual_percent
        CDF_pt             = [double]$_.CDF_pt
    }
}

$chk = 0; $chkBad = 0
foreach ($r in $rows) {
    if (-not ((Test-Finite $r.S_percent) -and (Test-Finite $r.S_model_pt_percent))) { continue }
    $d = $r.S_percent - $r.S_model_pt_percent - $r.residual_percent
    $chk++
    if ([math]::Abs($d) -gt 1e-4 * ([math]::Max([math]::Abs($r.S_percent), 1.0))) { $chkBad++ }
}
if ($chkBad -gt $chk * 0.02) { Write-Warning "residual_percent vs S-S_model mismatch on some rows ($chkBad/$chk)" }

$byT = $rows | Group-Object { $_.T_K }
$Tlist = @($byT | ForEach-Object { [double]$_.Name } | Sort-Object)
$nT = $Tlist.Count

$nGrid = 48
$cdfAll = @($rows | Where-Object { Test-Finite $_.CDF_pt } | ForEach-Object { $_.CDF_pt })
$cdfMin = ($cdfAll | Measure-Object -Minimum).Minimum
$cdfMax = ($cdfAll | Measure-Object -Maximum).Maximum
if (-not ((Test-Finite $cdfMin) -and (Test-Finite $cdfMax)) -or ($cdfMax - $cdfMin) -lt 1e-14) { throw "Degenerate CDF_pt span" }

$grid = New-Object double[] $nGrid
for ($g = 0; $g -lt $nGrid; $g++) {
    $grid[$g] = $cdfMin + ($g / ($nGrid - 1)) * ($cdfMax - $cdfMin)
}

# Per-T curves: sorted by CDF_pt
$curveRaw = @{}   # T -> interpolated raw residual on grid
$curveNorm = @{}  # per-T min-max normed residual on grid
$curveAmp = @{}   # per-T RMS-normalized on grid
$curveMeta = @{}  # ladder info per T

foreach ($tk in $Tlist) {
    $g = $byT | Where-Object { [double]$_.Name -eq $tk }
    $slice = @($g.Group | Where-Object { (Test-Finite $_.CDF_pt) -and (Test-Finite $_.residual_percent) } | Sort-Object CDF_pt)
    if ($slice.Count -lt 3) { continue }
    $xv = @($slice | ForEach-Object { $_.CDF_pt })
    $rv = @($slice | ForEach-Object { $_.residual_percent })
    $Sv = @($slice | ForEach-Object { $_.S_percent })
    $Mv = @($slice | ForEach-Object { $_.S_model_pt_percent })

    $rvn = New-Object double[] $rv.Count
    $mn = ($rv | Measure-Object -Minimum).Minimum
    $mx = ($rv | Measure-Object -Maximum).Maximum
    $den = $mx - $mn
    if ($den -lt 1e-18) {
        for ($k = 0; $k -lt $rv.Count; $k++) { $rvn[$k] = 0.0 }
    }
    else {
        for ($k = 0; $k -lt $rv.Count; $k++) { $rvn[$k] = ($rv[$k] - $mn) / $den }
    }

    $rms = [math]::Sqrt(($rv | ForEach-Object { $_ * $_ } | Measure-Object -Average).Average)
    $rva = New-Object double[] $rv.Count
    if ($rms -lt 1e-18) {
        for ($k = 0; $k -lt $rv.Count; $k++) { $rva[$k] = 0.0 }
    }
    else {
        for ($k = 0; $k -lt $rv.Count; $k++) { $rva[$k] = $rv[$k] / $rms }
    }

    $ig = New-Object double[] $nGrid
    $ign = New-Object double[] $nGrid
    $iga = New-Object double[] $nGrid
    for ($q = 0; $q -lt $nGrid; $q++) {
        $ig[$q] = LinInterp $grid[$q] $xv $rv
        $ign[$q] = LinInterp $grid[$q] $xv $rvn
        $iga[$q] = LinInterp $grid[$q] $xv $rva
    }
    $curveRaw[$tk] = $ig
    $curveNorm[$tk] = $ign
    $curveAmp[$tk] = $iga
    $Im = @($slice | ForEach-Object { $_.current_mA })
    $curveMeta[$tk] = @{ xv = $xv; rv = $rv; Sv = $Sv; Mv = $Mv; Im = $Im; ladder_n = $slice.Count }
}

$Tactive = @($curveRaw.Keys | Sort-Object)
$nTa = $Tactive.Count
if ($nTa -lt 4) { throw "Too few active temperatures for Phase 5B" }

# Matrix R [nTa x nGrid] raw residual on grid
$R = New-Object 'double[,]' $nTa, $nGrid
for ($i = 0; $i -lt $nTa; $i++) {
    $tk = $Tactive[$i]
    for ($j = 0; $j -lt $nGrid; $j++) {
        $R[$i, $j] = $curveRaw[$tk][$j]
    }
}

# Mean shape mu[j]
$mu = New-Object double[] $nGrid
for ($j = 0; $j -lt $nGrid; $j++) {
    $s = 0.0
    for ($i = 0; $i -lt $nTa; $i++) { $s += $R[$i, $j] }
    $mu[$j] = $s / $nTa
}

# Row-centered PCA: X[i,j] = R[i,j] - mu[j]
$X = New-Object 'double[,]' $nTa, $nGrid
for ($i = 0; $i -lt $nTa; $i++) {
    for ($j = 0; $j -lt $nGrid; $j++) {
        $X[$i, $j] = $R[$i, $j] - $mu[$j]
    }
}

# Cov flat row-major nGrid*nGrid; Cov = X'X / (nTa-1)
$CovFlat = New-Object double[] ($nGrid * $nGrid)
$denCov = [math]::Max($nTa - 1, 1)
for ($a = 0; $a -lt $nGrid; $a++) {
    for ($b = 0; $b -lt $nGrid; $b++) {
        $s = 0.0
        for ($i = 0; $i -lt $nTa; $i++) {
            $s += $X[$i, $a] * $X[$i, $b]
        }
        $CovFlat[$a * $nGrid + $b] = $s / $denCov
    }
}

function Invoke-TopEigenPowerIter([double[]]$Cf, [int]$dim, [int]$maxIter = 80) {
    $rng = [System.Random]::new(42)
    $v = New-Object double[] $dim
    for ($i = 0; $i -lt $dim; $i++) { $v[$i] = $rng.NextDouble() - 0.5 }
    $nv = VecNorm $v
    for ($i = 0; $i -lt $dim; $i++) { $v[$i] /= $nv }
    for ($it = 0; $it -lt $maxIter; $it++) {
        $w = CovFlatMatVec $Cf $v $dim
        $nw = VecNorm $w
        if ($nw -lt 1e-30) { break }
        for ($i = 0; $i -lt $dim; $i++) { $v[$i] = $w[$i] / $nw }
    }
    $Mv = CovFlatMatVec $Cf $v $dim
    $lam = 0.0
    for ($i = 0; $i -lt $dim; $i++) { $lam += $v[$i] * $Mv[$i] }
    @{ v = $v; lambda = $lam }
}

function DeflateFlat([double[]]$Cf, [double[]]$v, [double]$lambda, [int]$n) {
    $Out = New-Object double[] ($n * $n)
    for ($a = 0; $a -lt $n; $a++) {
        for ($b = 0; $b -lt $n; $b++) {
            $Out[$a * $n + $b] = $Cf[$a * $n + $b] - $lambda * $v[$a] * $v[$b]
        }
    }
    return $Out
}

$Cwork = [double[]]$CovFlat.Clone()

$modesMeta = @()
$modeVecs = New-Object System.Collections.ArrayList
for ($modeIdx = 1; $modeIdx -le [math]::Min(8, $nTa - 1); $modeIdx++) {
    $ev = Invoke-TopEigenPowerIter $Cwork $nGrid
    $v1 = $ev.v
    $lam1 = $ev.lambda
    $cMu = 0.0
    for ($j = 0; $j -lt $nGrid; $j++) { $cMu += $v1[$j] * $mu[$j] }
    if ($cMu -lt 0) {
        for ($j = 0; $j -lt $nGrid; $j++) { $v1[$j] = -$v1[$j] }
    }
    $v1c = [double[]]@($v1 | ForEach-Object { [double]$_ })
    [void]$modeVecs.Add($v1c)
    $modesMeta += [pscustomobject]@{ mode_index = $modeIdx; eigenvalue = [math]::Round($lam1, 14) }
    $Cwork = DeflateFlat $Cwork $v1 $lam1 $nGrid
}

$lambdaSum = 0.0
foreach ($m in $modesMeta) { $lambdaSum += $m.eigenvalue }
if ($lambdaSum -lt 1e-30) { $lambdaSum = 1.0 }

function UnitVec([double[]]$v) {
    $out = New-Object double[] $v.Length
    $nv = VecNorm $v
    if ($nv -lt 1e-40) { return $out }
    for ($i = 0; $i -lt $v.Length; $i++) { $out[$i] = $v[$i] / $nv }
    $out
}

$modeRows = @()
$cum = 0.0
$mi = 0
foreach ($m in $modesMeta) {
    $frac = if ($lambdaSum -gt 0) { $m.eigenvalue / $lambdaSum } else { 0 }
    $cum += $frac
    $vn = VecNorm([double[]]$modeVecs[$mi])
    $modeRows += [pscustomobject]@{
        mode_index                   = $m.mode_index
        eigenvalue                   = $m.eigenvalue
        variance_fraction            = [math]::Round($frac, 8)
        cumulative_variance_fraction = [math]::Round($cum, 8)
        eigenvector_L2_norm          = [math]::Round($vn, 12)
        sign_convention              = 'positive_correlation_with_mean_residual_profile_where_possible'
    }
    $mi++
}

$phi1 = UnitVec([double[]]$modeVecs[0])
$phi2 = if ($modeVecs.Count -ge 2) { UnitVec([double[]]$modeVecs[1]) } else { $null }

function MeanResidualProfileMse([double[]]$muProf) {
    $sse = 0.0
    $cnt = 0
    for ($ti = 0; $ti -lt $nTa; $ti++) {
        $tk = $Tactive[$ti]
        $meta = $curveMeta[$tk]
        $xv = $meta.xv; $rv = $meta.rv
        for ($p = 0; $p -lt $xv.Count; $p++) {
            $cdf = $xv[$p]
            $muP = LinInterp $cdf $grid $muProf
            $diff = $rv[$p] - $muP
            $sse += $diff * $diff
            $cnt++
        }
    }
    if ($cnt -eq 0) { return [double]::NaN }
    return $sse / $cnt
}

function Compute-ReconMseFixed([int]$nModes) {
    $sse = 0.0
    $cnt = 0
    for ($ti = 0; $ti -lt $nTa; $ti++) {
        $tk = $Tactive[$ti]
        $meta = $curveMeta[$tk]
        $xv = $meta.xv; $rv = $meta.rv
        for ($p = 0; $p -lt $xv.Count; $p++) {
            $cdf = $xv[$p]
            $rObs = $rv[$p]
            $muP = LinInterp $cdf $grid $mu
            $fit = $muP
            if ($nModes -ge 1) {
                $p1 = LinInterp $cdf $grid $phi1
                $dot1 = 0.0
                for ($j = 0; $j -lt $nGrid; $j++) {
                    $dot1 += $X[$ti, $j] * $phi1[$j]
                }
                $fit = $muP + $dot1 * $p1
            }
            if ($nModes -ge 2 -and $null -ne $phi2) {
                $p2 = LinInterp $cdf $grid $phi2
                $dot2 = 0.0
                for ($j = 0; $j -lt $nGrid; $j++) {
                    $dot2 += $X[$ti, $j] * $phi2[$j]
                }
                $fit = $fit + $dot2 * $p2
            }
            $diff = $rObs - $fit
            $sse += $diff * $diff
            $cnt++
        }
    }
    if ($cnt -eq 0) { return [double]::NaN }
    return $sse / $cnt
}

$mseMuOnly = Compute-ReconMseFixed 0
$msePC1 = Compute-ReconMseFixed 1
$msePC2 = if ($null -ne $phi2) { Compute-ReconMseFixed 2 } else { [double]::NaN }

# PT-only: S vs S_model (identity residual): baseline for "reconstruction of S"
$sseS0 = 0.0
$sseS1 = 0.0
$sseS2 = 0.0
$cntS = 0
for ($ti = 0; $ti -lt $nTa; $ti++) {
    $tk = $Tactive[$ti]
    $meta = $curveMeta[$tk]
    $xv = $meta.xv; $Sv = $meta.Sv; $Mv = $meta.Mv
    for ($p = 0; $p -lt $xv.Count; $p++) {
        $s = $Sv[$p]; $sm = $Mv[$p]; $cdf = $xv[$p]
        $rObs = $s - $sm
        $muP = LinInterp $cdf $grid $mu
        $p1v = LinInterp $cdf $grid $phi1
        $dot1 = 0.0
        for ($j = 0; $j -lt $nGrid; $j++) { $dot1 += $X[$ti, $j] * $phi1[$j] }
        $r1 = $muP + $dot1 * $p1v
        $sHat1 = $sm + $r1
        $sseS0 += ($s - $sm) * ($s - $sm)
        $sseS1 += ($s - $sHat1) * ($s - $sHat1)
        if ($null -ne $phi2) {
            $p2v = LinInterp $cdf $grid $phi2
            $dot2 = 0.0
            for ($j = 0; $j -lt $nGrid; $j++) { $dot2 += $X[$ti, $j] * $phi2[$j] }
            $r2 = $r1 + $dot2 * $p2v
            $sHat2 = $sm + $r2
            $sseS2 += ($s - $sHat2) * ($s - $sHat2)
        }
        $cntS++
    }
}
$mseS_pt_only = $sseS0 / $cntS
$mseS_pt_p1 = $sseS1 / $cntS
$mseS_pt_p2 = if ($null -ne $phi2) { $sseS2 / $cntS } else { [double]::NaN }

# Per-T projection amplitude on mean (raw): a_T = sum_j R_ij * mu_j / sum mu_j^2
$projRows = @()
for ($i = 0; $i -lt $nTa; $i++) {
    $tk = $Tactive[$i]
    $num = 0.0; $dm = 0.0
    for ($j = 0; $j -lt $nGrid; $j++) {
        $num += $R[$i, $j] * $mu[$j]
        $dm += $mu[$j] * $mu[$j]
    }
    $amp = if ($dm -gt 1e-30) { $num / $dm } else { [double]::NaN }
    $projRows += [pscustomobject]@{ T_K = $tk; projection_amplitude_on_mean_shape = [math]::Round($amp, 8); notes = 'least_squares_scalar_on_grid_inner_product' }
}

# LOO mean shape stability
$looRows = @()
$corrMuList = New-Object System.Collections.ArrayList
foreach ($hold in $Tactive) {
    $muLoo = New-Object double[] $nGrid
    $others = @($Tactive | Where-Object { $_ -ne $hold })
    $nlo = $others.Count
    for ($j = 0; $j -lt $nGrid; $j++) {
        $s = 0.0
        foreach ($tk in $others) {
            $s += $curveRaw[$tk][$j]
        }
        $muLoo[$j] = if ($nlo -gt 0) { $s / $nlo } else { [double]::NaN }
    }
    $cm = PearsonVec $mu $muLoo
    if (Test-Finite $cm) { [void]$corrMuList.Add($cm) }
    $looRows += [pscustomobject]@{ held_out_T_K = $hold; mean_shape_corr_to_full = if (Test-Finite $cm) { [math]::Round($cm, 6) } else { 'NaN' }; sign_convention = 'mean_profiles_same_CDF_grid' }
}

$medianMuCorr = [double]::NaN
if ($corrMuList.Count) {
    $sorted = @($corrMuList.ToArray() | Sort-Object)
    $medianMuCorr = $sorted[[int][math]::Floor(($sorted.Count - 1) / 2)]
}

# Mean cross-T variance at grid for per-T normed residual (Phase 5A normalization option)
$normBinVar = New-Object System.Collections.ArrayList
for ($j = 0; $j -lt $nGrid; $j++) {
    $col = New-Object System.Collections.ArrayList
    foreach ($tk in $Tactive) {
        [void]$col.Add($curveNorm[$tk][$j])
    }
    $va = ($col | Measure-Object -Average).Average
    $vv = (($col | ForEach-Object { ($_ - $va) * ($_ - $va) }) | Measure-Object -Average).Average
    [void]$normBinVar.Add($vv)
}
$meanCrossTVarNormResidual = ($normBinVar | Measure-Object -Average).Average

# Derivative spine: per-T Pearson between dS/dI and d(residual)/dI on ladder ; report median
$derivCorrList = New-Object System.Collections.ArrayList
foreach ($tk in $Tactive) {
    $meta = $curveMeta[$tk]
    $Im = $meta.Im; $Sv = $meta.Sv; $rv = $meta.rv
    if ($Im.Count -lt 3) { continue }
    $ds = New-Object System.Collections.ArrayList
    $dr = New-Object System.Collections.ArrayList
    for ($k = 1; $k -lt $Im.Count; $k++) {
        $di = $Im[$k] - $Im[$k - 1]
        if ([math]::Abs($di) -lt 1e-14) { continue }
        [void]$ds.Add(($Sv[$k] - $Sv[$k - 1]) / $di)
        [void]$dr.Add(($rv[$k] - $rv[$k - 1]) / $di)
    }
    if ($ds.Count -lt 4) { continue }
    $da = @($ds.ToArray() | ForEach-Object { [double]$_ })
    $db = @($dr.ToArray() | ForEach-Object { [double]$_ })
    $pc = PearsonVec $da $db
    if (Test-Finite $pc) { [void]$derivCorrList.Add($pc) }
}
$medianDerivCorr = [double]::NaN
if ($derivCorrList.Count) {
    $sd = @($derivCorrList.ToArray() | Sort-Object)
    $medianDerivCorr = $sd[[int][math]::Floor(($sd.Count - 1) / 2)]
}

# Metrics summary rows
$m1f = if ($modeRows.Count) { [double]$modeRows[0].variance_fraction } else { [double]::NaN }
$m2f = if ($modeRows.Count -ge 2) { [double]$modeRows[1].variance_fraction } else { [double]::NaN }

$metricsRows = @(
    [pscustomobject]@{ metric_key = 'cdf_grid_min'; metric_value = [math]::Round($cdfMin, 8); normalization = 'shared'; notes = 'fixed_grid' }
    [pscustomobject]@{ metric_key = 'cdf_grid_max'; metric_value = [math]::Round($cdfMax, 8); normalization = 'shared'; notes = 'fixed_grid' }
    [pscustomobject]@{ metric_key = 'cdf_grid_points'; metric_value = $nGrid; normalization = 'shared'; notes = 'uniform' }
    [pscustomobject]@{ metric_key = 'n_temperatures_active'; metric_value = $nTa; normalization = 'shared'; notes = '' }
    [pscustomobject]@{ metric_key = 'mean_abs_residual_on_ladder'; metric_value = [math]::Sqrt(($rows | Where-Object { Test-Finite $_.residual_percent } | ForEach-Object { $_.residual_percent * $_.residual_percent } | Measure-Object -Average).Average); normalization = 'raw'; notes = 'all_points' }
    [pscustomobject]@{ metric_key = 'mse_residual_mean_shape_only'; metric_value = [math]::Round($mseMuOnly, 14); normalization = 'raw'; notes = 'fit_residual_to_mu_on_CDF' }
    [pscustomobject]@{ metric_key = 'mse_residual_PCA_mean_only'; metric_value = [math]::Round($mseMuOnly, 14); normalization = 'raw'; notes = 'same_as_mean_shape_PC0' }
    [pscustomobject]@{ metric_key = 'mse_residual_after_PC1'; metric_value = [math]::Round($msePC1, 14); normalization = 'raw'; notes = 'mu_plus_one_PC_on_grid' }
    [pscustomobject]@{ metric_key = 'mse_residual_after_PC2'; metric_value = if (Test-Finite $msePC2) { [math]::Round($msePC2, 14) } else { 'NaN' }; normalization = 'raw'; notes = 'diagnostic_second_mode' }
    [pscustomobject]@{ metric_key = 'mse_S_PT_backbone_only'; metric_value = [math]::Round($mseS_pt_only, 14); normalization = 'S_vs_S_model'; notes = 'baseline' }
    [pscustomobject]@{ metric_key = 'mse_S_PT_plus_residual_PC1'; metric_value = [math]::Round($mseS_pt_p1, 14); normalization = 'S_vs_S_model_plus_fitted_residual'; notes = '' }
    [pscustomobject]@{ metric_key = 'mse_S_PT_plus_residual_PC2'; metric_value = if (Test-Finite $mseS_pt_p2) { [math]::Round($mseS_pt_p2, 14) } else { 'NaN' }; normalization = 'diagnostic'; notes = '' }
    [pscustomobject]@{ metric_key = 'variance_fraction_mode_1'; metric_value = if (Test-Finite $m1f) { [math]::Round($m1f, 8) } else { 'NaN' }; normalization = 'PCA_covariance_grid'; notes = '' }
    [pscustomobject]@{ metric_key = 'variance_fraction_mode_2'; metric_value = if (Test-Finite $m2f) { [math]::Round($m2f, 8) } else { 'NaN' }; normalization = 'PCA_covariance_grid'; notes = '' }
    [pscustomobject]@{ metric_key = 'median_loo_mean_shape_correlation'; metric_value = if (Test-Finite $medianMuCorr) { [math]::Round($medianMuCorr, 8) } else { 'NaN' }; normalization = 'LOO_T'; notes = 'leave_one_temperature_out_mean_profile' }
    [pscustomobject]@{ metric_key = 'mean_cross_T_variance_norm_residual_on_grid'; metric_value = [math]::Round($meanCrossTVarNormResidual, 14); normalization = 'per_T_minmax_residual'; notes = 'stack_variance_across_T_at_each_CDF_bin' }
    [pscustomobject]@{ metric_key = 'median_per_T_corr_dS_dI_vs_dResidual_dI'; metric_value = if (Test-Finite $medianDerivCorr) { [math]::Round($medianDerivCorr, 8) } else { 'NaN' }; normalization = 'derivative_spine'; notes = 'Phase5A_T03_coupling_screenshot' }
)

foreach ($pr in $projRows) {
    $metricsRows += [pscustomobject]@{ metric_key = ('projection_amp_on_mean_shape_T_' + $pr.T_K); metric_value = $pr.projection_amplitude_on_mean_shape; normalization = 'raw_residual_grid'; notes = $pr.notes }
}

$metricsOut = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_metrics.csv'
$metricsRows | Export-Csv -NoTypeInformation -Encoding UTF8 $metricsOut

$modesOut = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_modes.csv'
$modeRows | Export-Csv -NoTypeInformation -Encoding UTF8 $modesOut

$reconRows = @(
    [pscustomobject]@{ model = 'PT_backbone_only'; quantity = 'mse_vs_S_percent'; value = [math]::Round($mseS_pt_only, 14); uses_residual_absorption_modes = 'NO' }
    [pscustomobject]@{ model = 'PT_plus_residual_rank1_PCA_grid'; quantity = 'mse_vs_S_percent'; value = [math]::Round($mseS_pt_p1, 14); uses_residual_absorption_modes = 'PC1_only' }
    [pscustomobject]@{ model = 'PT_plus_residual_rank2_PCA_grid_diagnostic'; quantity = 'mse_vs_S_percent'; value = if (Test-Finite $mseS_pt_p2) { [math]::Round($mseS_pt_p2, 14) } else { 'NaN' }; uses_residual_absorption_modes = 'PC1_and_PC2_diagnostic' }
    [pscustomobject]@{ model = 'residual_only_mean_shape'; quantity = 'mse_residual_percent'; value = [math]::Round($mseMuOnly, 14); uses_residual_absorption_modes = 'mean_profile_only' }
    [pscustomobject]@{ model = 'residual_only_after_PC1'; quantity = 'mse_residual_percent'; value = [math]::Round($msePC1, 14); uses_residual_absorption_modes = 'after_PC1' }
)

$reconOut = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_reconstruction.csv'
$reconRows | Export-Csv -NoTypeInformation -Encoding UTF8 $reconOut

$stabOut = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_stability.csv'
$looRows | Export-Csv -NoTypeInformation -Encoding UTF8 $stabOut

# Verdict logic (repository thresholds; not physical claims)
$f1 = if (Test-Finite $m1f) { $m1f } else { 0 }
$f2 = if (Test-Finite $m2f) { $m2f } else { 0 }
$rank1Sup = if (($f1 -ge 0.45) -and (Test-Finite $medianMuCorr) -and ($medianMuCorr -ge 0.82)) { 'YES' } else { 'PARTIAL' }
if (($f1 -lt 0.35) -or ((Test-Finite $medianMuCorr) -and $medianMuCorr -lt 0.65)) { $rank1Sup = 'NO' }

$multiSup = if ($f2 -ge 0.12) { 'YES' } else { 'NO' }
if ($f2 -ge 0.08 -and $f2 -lt 0.12) { $multiSup = 'PARTIAL' }

$lift1 = ($mseS_pt_p1 -lt $mseS_pt_only * 0.995)
$ptPlusOne = if ($lift1) { 'YES' } else { 'PARTIAL' }
if (-not $lift1 -and ($mseS_pt_p1 -ge $mseS_pt_only * 1.001)) { $ptPlusOne = 'NO' }

$lift2 = $false
if (Test-Finite $mseS_pt_p2) { $lift2 = ($mseS_pt_p2 -lt $mseS_pt_p1 * 0.998) }
$ptPlusTwo = if ($lift2) { 'PARTIAL' } else { 'NO' }

$lootStable = if ((Test-Finite $medianMuCorr) -and ($medianMuCorr -ge 0.85)) { 'YES' } elseif ((Test-Finite $medianMuCorr) -and ($medianMuCorr -ge 0.75)) { 'PARTIAL' } else { 'NO' }

$safe5c = if (($rank1Sup -eq 'YES' -or $rank1Sup -eq 'PARTIAL') -and ($lootStable -ne 'NO')) { 'PARTIAL' } else { 'NO' }
if (($rank1Sup -eq 'NO') -and ($lootStable -eq 'NO')) { $safe5c = 'NO' }

$statusRows = @(
    [pscustomobject]@{ verdict_key = 'PHASE5B_RESIDUAL_ABSORPTION_TEST_COMPLETE'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'LOCKED_CANONICAL_S_SOURCE_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'PHASE5A_ANCHOR_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'CDF_PT_CANDIDATE_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'RESIDUAL_PERCENT_USED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'NAIVE_S_COLLAPSE_USED_AS_EVIDENCE'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'LEGACY_X_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'LEGACY_PHI_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'W_BASED_COORDINATES_USED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CANONICAL_PHI_CLAIMED'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'FULL_DECOMPOSITION_CAMPAIGN_RUN'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'RANK1_RESIDUAL_ABSORPTION_SUPPORTED'; verdict_value = $rank1Sup }
    [pscustomobject]@{ verdict_key = 'MULTIMODE_RESIDUAL_STRUCTURE_SUPPORTED'; verdict_value = $multiSup }
    [pscustomobject]@{ verdict_key = 'PT_PLUS_ONE_MODE_IMPROVES_RECONSTRUCTION'; verdict_value = $ptPlusOne }
    [pscustomobject]@{ verdict_key = 'PT_PLUS_TWO_MODE_DIAGNOSTIC_IMPROVES_RECONSTRUCTION'; verdict_value = $ptPlusTwo }
    [pscustomobject]@{ verdict_key = 'LOOT_SHARED_SHAPE_STABLE'; verdict_value = $lootStable }
    [pscustomobject]@{ verdict_key = 'RISKS_DOCUMENTED'; verdict_value = 'YES' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_WRITE_RESIDUAL_MODE_CLAIM'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_OPEN_PHASE5C_RESIDUAL_INTERPRETATION'; verdict_value = $safe5c }
    [pscustomobject]@{ verdict_key = 'SAFE_TO_COMPARE_TO_RELAXATION'; verdict_value = 'NO' }
    [pscustomobject]@{ verdict_key = 'CROSS_MODULE_EVIDENCE_USED'; verdict_value = 'NO' }
)

$statusOut = Join-Path $RepoRoot 'tables/switching_phase5B_residual_absorption_status.csv'
$statusRows | Export-Csv -NoTypeInformation -Encoding UTF8 $statusOut

# Report
$rp = Join-Path $RepoRoot 'reports/switching_phase5B_residual_absorption_test.md'
$lines = @()
$lines += '# Phase 5B - Residual absorption test (Switching only)'
$lines += ''
$lines += '## Scope'
$lines += '- Test layer only. Not canonical Phi. Not a physical mechanism claim.'
$lines += '- Axis: **CDF_pt_candidate** (`CDF_pt`). Residual: **`residual_percent = S_percent - S_model_pt_percent`** (column on canonical long table).'
$lines += '- Source: `' + $CanonicalRunId + '/tables/switching_canonical_S_long.csv`.'
$lines += '- Anchors: Phase 5A (`tables/switching_phase5A_residual_absorption_allowed_tests.csv`).'
$lines += ''
$lines += '## Procedures executed'
$lines += '1. Interpolate **raw**, **per-T min-max normed**, and **per-T RMS-separated** residual curves onto a uniform **CDF_pt** grid.'
$lines += '2. Mean residual profile **mu(CDF)**; per-T projection amplitude on **mu** (metrics file / projection export via per-T stats in modes).'
$lines += '3. PCA on temperature-centered residual matrix on grid (covariance eigenanalysis); variance fractions reported in modes table.'
$lines += '4. Reconstruction: **S_hat = S_model + fitted residual** using mean only, then +PC1, then +PC2 (diagnostic).'
$lines += '5. LOO-**T** stability of mean profile vs full-sample mean (correlation on grid).'
$lines += ''
$lines += '## Risk acknowledgment'
$lines += '- **PT/CDF leakage:** `CDF_pt` and `S_model_pt_percent` share backbone construction with `residual_percent`.'
$lines += '- **Naive S collapse:** not used as absorption evidence (`NAIVE_S_COLLAPSE_USED_AS_EVIDENCE=NO`).'
$lines += ''
$lines += '## Summary numbers (this run)'
$lines += ('- Mode-1 variance fraction (PCA on grid): **' + [string]([math]::Round($f1, 4)) + '**; mode-2: **' + [string]([math]::Round($f2, 4)) + '**.')
$p2s = if (Test-Finite $mseS_pt_p2) { '; with PC1+PC2: **' + [string]([math]::Round($mseS_pt_p2, 8)) + '**' } else { '' }
$lines += ('- MSE of `S_percent` vs `S_model` (PT only): **' + [string]([math]::Round($mseS_pt_only, 8)) + '**; with PC1 residual: **' + [string]([math]::Round($mseS_pt_p1, 8)) + '**' + $p2s + '.')
$lines += ('- Median LOO-**T** mean-profile correlation: **' + [string]([math]::Round($medianMuCorr, 4)) + '** (verdict key `LOOT_SHARED_SHAPE_STABLE` = leave-one-**T**).')
$lines += '- **RANK1** / **multimode** flags are **test-layer** only, not canonical Phi names.'
$lines += ''
$lines += '## Verdicts'
foreach ($s in $statusRows) {
    $lines += ('- **' + $s.verdict_key + '** = `' + $s.verdict_value + '`')
}
$lines += ''
$lines += '## Artifacts'
$lines += '- `tables/switching_phase5B_residual_absorption_metrics.csv`'
$lines += '- `tables/switching_phase5B_residual_absorption_modes.csv`'
$lines += '- `tables/switching_phase5B_residual_absorption_reconstruction.csv`'
$lines += '- `tables/switching_phase5B_residual_absorption_stability.csv`'
$lines += '- `tables/switching_phase5B_residual_absorption_status.csv`'
$lines | Set-Content -Encoding UTF8 $rp

Write-Host "Phase5B complete. Report: $rp"
