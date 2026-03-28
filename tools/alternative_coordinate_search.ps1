# Alternative coordinate search vs X — LOOCV (read-only CSV inputs).
$ErrorActionPreference = 'Stop'
function Test-Finite([double]$x) {
    return ($x -eq $x) -and -not ([double]::IsInfinity($x))
}

function yLabelFromTarget([string]$tn) {
    switch ($tn) {
        'A_T_interp' { return 'A (interp)' }
        'R_T_interp' { return 'R (interp)' }
        default { return 'kappa' }
    }
}

function Export-ScatterPng([string]$outPath, [double[]]$xs, [double[]]$ys, [string]$xlabel, [string]$ylabel) {
    Add-Type -AssemblyName System.Drawing
    $w = 900; $h = 700
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $padL = 80; $padR = 40; $padT = 50; $padB = 70
    $plotW = $w - $padL - $padR; $plotH = $h - $padT - $padB
    $minx = ($xs | Measure-Object -Minimum).Minimum
    $maxx = ($xs | Measure-Object -Maximum).Maximum
    $miny = ($ys | Measure-Object -Minimum).Minimum
    $maxy = ($ys | Measure-Object -Maximum).Maximum
    if ([math]::Abs($maxx - $minx) -lt 1e-30) { $maxx = $minx + 1e-10 }
    if ([math]::Abs($maxy - $miny) -lt 1e-30) { $maxy = $miny + 1e-10 }
    $penAxis = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 2
    $g.DrawLine($penAxis, $padL, $padT + $plotH, $padL + $plotW, $padT + $plotH)
    $g.DrawLine($penAxis, $padL, $padT, $padL, $padT + $plotH)
    $font = New-Object System.Drawing.Font 'Segoe UI', 14
    $fontSmall = New-Object System.Drawing.Font 'Segoe UI', 10
    $brush = [System.Drawing.Brushes]::Black
    $g.DrawString($xlabel, $font, $brush, [float]($padL + $plotW/2 - 80), [float]($h - 40))
    $g.DrawString($ylabel, $font, $brush, [float]15, [float]($padT + $plotH/2 - 60))
    $brushPt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 114, 189))
    for ($i = 0; $i -lt $xs.Length; $i++) {
        $px = $padL + ($xs[$i] - $minx) / ($maxx - $minx) * $plotW
        $py = $padT + $plotH - ($ys[$i] - $miny) / ($maxy - $miny) * $plotH
        $g.FillEllipse($brushPt, [float]($px - 5), [float]($py - 5), 10.0, 10.0)
    }
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose(); $penAxis.Dispose(); $font.Dispose(); $fontSmall.Dispose(); $brushPt.Dispose()
}

$Repo = Split-Path -Parent $PSScriptRoot
$ts = Get-Date -Format 'yyyy_MM_dd_HHmmss'
$runId = "run_${ts}_alternative_coordinate_search"
$runDir = Join-Path $Repo "results\cross_experiment\runs\$runId"
foreach ($s in @('figures','tables','reports','review')) {
    New-Item -ItemType Directory -Path (Join-Path $runDir $s) -Force | Out-Null
}

$barrierPath = Join-Path $Repo 'results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv'
$kappaPath = Join-Path $Repo 'results\switching\runs\_extract_run_2026_03_24_220314_residual_decomposition\run_2026_03_24_220314_residual_decomposition\tables\kappa_vs_T.csv'
$ptPath = Join-Path $Repo 'results\switching\runs\run_2026_03_25_013849_pt_robust_minpts7\tables\PT_summary.csv'

$bd = Import-Csv $barrierPath
$kapRows = Import-Csv $kappaPath
$kapMap = @{}
foreach ($r in $kapRows) {
    $tk = if ($r.T_K) { [double]$r.T_K } else { [double]$r.T }
    $kapMap[[int]$tk] = [double]$r.kappa
}
$rows = foreach ($row in $bd) {
    $tk = [int][double]$row.T_K
    if (-not $kapMap.ContainsKey($tk)) { continue }
    $row | Add-Member -NotePropertyName 'kappa' -NotePropertyValue $kapMap[$tk] -Force
    $row
}
$ptRows = Import-Csv $ptPath
$ptMap = @{}
foreach ($r in $ptRows) {
    if ([string]::IsNullOrWhiteSpace($r.T_K)) { continue }
    $ptMap[[int][double]$r.T_K] = @{
        m = [double]$r.mean_threshold_mA
        sk = [double]$r.skewness
        cdf = [double]$r.cdf_rmse
    }
}
$rows = foreach ($row in $rows) {
    $tk = [int][double]$row.T_K
    $o = [ordered]@{}
    $row.PSObject.Properties | ForEach-Object { $o[$_.Name] = $_.Value }
    if ($ptMap.ContainsKey($tk)) {
        $o['pt_sum_mean_thr_mA'] = $ptMap[$tk].m
        $o['pt_sum_thr_skewness'] = $ptMap[$tk].sk
        $o['pt_sum_cdf_rmse'] = $ptMap[$tk].cdf
    } else {
        $o['pt_sum_mean_thr_mA'] = [double]::NaN
        $o['pt_sum_thr_skewness'] = [double]::NaN
        $o['pt_sum_cdf_rmse'] = [double]::NaN
    }
    [PSCustomObject]$o
}

$rows = @($rows | Where-Object {
    [int]$_.row_valid -eq 1 -and
    [double]$_.A_T_interp -eq [double]$_.A_T_interp -and
    [double]$_.R_T_interp -eq [double]$_.R_T_interp -and
    [double]$_.X_T_interp -eq [double]$_.X_T_interp -and
    [double]$_.I_peak_mA -eq [double]$_.I_peak_mA -and
    [double]$_.S_peak -eq [double]$_.S_peak -and
    [double]$_.kappa -eq [double]$_.kappa
} | Sort-Object { [double]$_.T_K })

function Corr-Pearson([double[]]$a,[double[]]$b) {
    $n = $a.Length; $ma = ($a | Measure-Object -Average).Average; $mb = ($b | Measure-Object -Average).Average
    $sab = 0.0; $saa = 0.0; $sbb = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $da = $a[$i]-$ma; $db = $b[$i]-$mb
        $sab += $da*$db; $saa += $da*$da; $sbb += $db*$db
    }
    if ($saa -lt 1e-30 -or $sbb -lt 1e-30) { return [double]::NaN }
    return $sab / [math]::Sqrt($saa * $sbb)
}

function Get-AvgRanks([double[]]$x) {
    $n = $x.Length
    $idx = 0..($n-1) | Sort-Object { $x[$_] }
    $r = New-Object double[] $n
    $k = 0
    while ($k -lt $n) {
        $start = $k
        $val = $x[$idx[$k]]
        while ($k -lt $n -and [math]::Abs($x[$idx[$k]] - $val) -lt 1e-15) { $k++ }
        $avg = (($start + 1) + $k) / 2.0
        for ($t = $start; $t -lt $k; $t++) { $r[$idx[$t]] = $avg }
    }
    return $r
}

function Corr-Spearman([double[]]$a,[double[]]$b) {
    Corr-Pearson (Get-AvgRanks $a) (Get-AvgRanks $b)
}

function Loocv-OnePred([double[]]$y,[double[]]$z) {
    $n = $y.Length
    if ($n -lt 3) { return @{ rmse = [double]::NaN; pr = [double]::NaN; sr = [double]::NaN; yhat = $null } }
    $sse = 0.0
    $yh = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $zs = New-Object System.Collections.Generic.List[double]
        $ys = New-Object System.Collections.Generic.List[double]
        for ($j = 0; $j -lt $n; $j++) {
            if ($j -ne $i) { $zs.Add($z[$j]); $ys.Add($y[$j]) }
        }
        $Z = $zs.ToArray(); $Y = $ys.ToArray()
        $mZ = ($Z | Measure-Object -Average).Average
        $mY = ($Y | Measure-Object -Average).Average
        $Szz = 0.0; $Szy = 0.0
        for ($k = 0; $k -lt $Z.Length; $k++) {
            $dz = $Z[$k] - $mZ
            $Szz += $dz * $dz
            $Szy += $dz * ($Y[$k] - $mY)
        }
        if ([math]::Abs($Szz) -lt 1e-18) { return @{ rmse = [double]::NaN; pr = [double]::NaN; sr = [double]::NaN; yhat = $null } }
        $b1 = $Szy / $Szz
        $b0 = $mY - $b1 * $mZ
        $yh[$i] = $b0 + $b1 * $z[$i]
        $sse += [math]::Pow($y[$i] - $yh[$i], 2)
    }
    $rmse = [math]::Sqrt($sse / $n)
    return @{ rmse = $rmse; pr = (Corr-Pearson $y $yh); sr = (Corr-Spearman $y $yh); yhat = $yh }
}

function Det3($a11,$a12,$a13,$a21,$a22,$a23,$a31,$a32,$a33) {
    $a11*($a22*$a33 - $a23*$a32) - $a12*($a21*$a33 - $a23*$a31) + $a13*($a21*$a32 - $a22*$a31)
}

function Solve3x3($A,$b) {
    $a00 = [double]$A.GetValue(0,0); $a01 = [double]$A.GetValue(0,1); $a02 = [double]$A.GetValue(0,2)
    $a10 = [double]$A.GetValue(1,0); $a11 = [double]$A.GetValue(1,1); $a12 = [double]$A.GetValue(1,2)
    $a20 = [double]$A.GetValue(2,0); $a21 = [double]$A.GetValue(2,1); $a22 = [double]$A.GetValue(2,2)
    $b0 = [double]$b[0]; $b1 = [double]$b[1]; $b2 = [double]$b[2]
    $d = [double](Det3 $a00 $a01 $a02 $a10 $a11 $a12 $a20 $a21 $a22)
    if ([math]::Abs($d) -lt 1e-18) { return $null }
    $d0 = [double](Det3 $b0 $a01 $a02 $b1 $a11 $a12 $b2 $a21 $a22)
    $d1 = [double](Det3 $a00 $b0 $a02 $a10 $b1 $a12 $a20 $b2 $a22)
    $d2 = [double](Det3 $a00 $a01 $b0 $a10 $a11 $b1 $a20 $a21 $b2)
    $x0 = $d0 / $d; $x1 = $d1 / $d; $x2 = $d2 / $d
    return ,@($x0, $x1, $x2)
}

function Loocv-TwoPred([double[]]$y,[double[]]$v1,[double[]]$v2) {
    $n = $y.Length
    if ($n -lt 4) { return @{ rmse = [double]::NaN; pr = [double]::NaN; sr = [double]::NaN } }
    $sse = 0.0
    $yh = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $s00=0.0;$s01=0.0;$s02=0.0;$s11=0.0;$s12=0.0;$s22=0.0
        $t0=0.0;$t1=0.0;$t2=0.0
        for ($j = 0; $j -lt $n; $j++) {
            if ($j -eq $i) { continue }
            $x0 = 1.0; $x1 = $v1[$j]; $x2 = $v2[$j]; $yj = $y[$j]
            $s00 += $x0*$x0; $s01 += $x0*$x1; $s02 += $x0*$x2
            $s11 += $x1*$x1; $s12 += $x1*$x2; $s22 += $x2*$x2
            $t0 += $x0*$yj; $t1 += $x1*$yj; $t2 += $x2*$yj
        }
        $A = New-Object 'double[,]' 3, 3
        $A[0,0]=$s00;$A[0,1]=$s01;$A[0,2]=$s02;$A[1,0]=$s01;$A[1,1]=$s11;$A[1,2]=$s12;$A[2,0]=$s02;$A[2,1]=$s12;$A[2,2]=$s22
        $bb = @($t0,$t1,$t2)
        $beta = Solve3x3 $A $bb
        if ($null -eq $beta) { return @{ rmse = [double]::NaN; pr = [double]::NaN; sr = [double]::NaN } }
        $pred = $beta[0] + $beta[1]*$v1[$i] + $beta[2]*$v2[$i]
        $yh[$i] = $pred
        $sse += [math]::Pow($y[$i] - $pred, 2)
    }
    $rmse = [math]::Sqrt($sse / $n)
    return @{ rmse = $rmse; pr = (Corr-Pearson $y $yh); sr = (Corr-Spearman $y $yh) }
}

function Build-Candidates($df) {
    $h = @{}
    $names = @('I_peak_mA','S_peak','kappa','X_T_interp','mean_I_mA','median_I_mA','mode_I_mA',
        'q10_I_mA','q25_I_mA','q50_I_mA','q75_I_mA','q90_I_mA','iq75_25_mA','iq90_10_mA',
        'asym_q75_50_minus_q50_25','tail_ratio_high_over_low','skewness_quantile','cheb_m2_z','cheb_m4_z',
        'moment_I2_weighted','pt_svd_score1','pt_svd_score2','mass_upper_half',
        'pt_sum_mean_thr_mA','pt_sum_thr_skewness','pt_sum_cdf_rmse')
    foreach ($name in $names) {
        $h[$name] = @($df | ForEach-Object { [double]$($_.$name) })
    }
    $Ip = $h['I_peak_mA']; $Sp = $h['S_peak']; $Xv = $h['X_T_interp']; $kap = $h['kappa']
    $h['I_peak_over_S_peak'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $Ip[$i] / $Sp[$i] }
    $h['kappa_over_S_peak'] = for ($i = 0; $i -lt $kap.Length; $i++) { $kap[$i] / $Sp[$i] }
    $h['q90_over_q10'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $h['q90_I_mA'][$i] / $h['q10_I_mA'][$i] }
    $h['q75_over_q25'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $h['q75_I_mA'][$i] / $h['q25_I_mA'][$i] }
    $h['iq90_10_over_iq75_25'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $h['iq90_10_mA'][$i] / $h['iq75_25_mA'][$i] }
    $tr = for ($i = 0; $i -lt $df.Count; $i++) { [math]::Max([double]$df[$i].tail_ratio_high_over_low, 1e-300) }
    $h['log10_tail_ratio'] = $tr | ForEach-Object { [math]::Log10($_) }
    $h['X_times_kappa'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $Xv[$i] * $kap[$i] }
    $h['X_over_kappa'] = for ($i = 0; $i -lt $Ip.Length; $i++) { $Xv[$i] / $kap[$i] }
    foreach ($a in @(-1,0,1)) {
        foreach ($b in @(-1,0,1)) {
            if ($a -eq 0 -and $b -eq 0) { continue }
            $Ia = if ($a -eq 0) { @(for ($i = 0; $i -lt $Ip.Length; $i++) { 1.0 }) } else { $Ip | ForEach-Object { [math]::Pow($_, $a) } }
            $Sb = if ($b -eq 0) { @(for ($i = 0; $i -lt $Sp.Length; $i++) { 1.0 }) } else { $Sp | ForEach-Object { [math]::Pow($_, $b) } }
            $sa = if ($a -eq -1) { 'm1' } elseif ($a -eq 0) { '0' } else { '1' }
            $sb = if ($b -eq -1) { 'm1' } elseif ($b -eq 0) { '0' } else { '1' }
            $nm = "Ip_${sa}_Sp_${sb}"
            $h[$nm] = for ($i = 0; $i -lt $Ip.Length; $i++) { $Ia[$i] * $Sb[$i] }
        }
    }
    return $h
}

function Valid-Name([string]$name,[string]$target) {
    if ($target -eq 'kappa' -and ($name -eq 'kappa' -or $name -like '*kappa*')) { return $false }
    if ($target -eq 'A_T_interp' -and $name -eq 'A_T_interp') { return $false }
    if ($target -eq 'R_T_interp' -and $name -eq 'R_T_interp') { return $false }
    return $true
}

$cand = Build-Candidates $rows
$singles = $cand.Keys | Sort-Object
$primary = @('X_T_interp','I_peak_mA','S_peak','kappa','mean_I_mA','median_I_mA','q50_I_mA',
    'asym_q75_50_minus_q50_25','skewness_quantile','pt_svd_score1','pt_svd_score2',
    'I_peak_over_S_peak','kappa_over_S_peak','log10_tail_ratio','pt_sum_mean_thr_mA')

$metrics = New-Object System.Collections.Generic.List[object]
foreach ($tn in @('A_T_interp','R_T_interp','kappa')) {
    $y = @($rows | ForEach-Object { [double]$_.$tn })
    foreach ($cn in $singles) {
        if (-not (Valid-Name $cn $tn)) { continue }
        $z = $cand[$cn]
        $m = 0..($y.Length-1) | Where-Object { (Test-Finite $y[$_]) -and (Test-Finite $z[$_]) }
        if ($m.Count -lt 3) { continue }
        $yy = @($m | ForEach-Object { $y[$_] }); $zz = @($m | ForEach-Object { $z[$_] })
        $r = Loocv-OnePred $yy $zz
        if (-not (Test-Finite $r.rmse)) { continue }
        $metrics.Add([PSCustomObject]@{ target=$tn; model_type='single'; coordinate=$cn; predictors=$cn; n=$m.Count; loocv_rmse=$r.rmse; pearson_loocv=$r.pr; spearman_loocv=$r.sr })
    }
    $prim2 = @($primary | Where-Object { Valid-Name $_ $tn })
    for ($i = 0; $i -lt $prim2.Count; $i++) {
        for ($j = $i+1; $j -lt $prim2.Count; $j++) {
            $n1 = $prim2[$i]; $n2 = $prim2[$j]
            $v1 = $cand[$n1]; $v2 = $cand[$n2]
            $mm = 0..($y.Length-1) | Where-Object { (Test-Finite $y[$_]) -and (Test-Finite $v1[$_]) -and (Test-Finite $v2[$_]) }
            if ($mm.Count -lt 4) { continue }
            $yy = @($mm | ForEach-Object { $y[$_] })
            $vv1 = @($mm | ForEach-Object { $v1[$_] })
            $vv2 = @($mm | ForEach-Object { $v2[$_] })
            $r = Loocv-TwoPred $yy $vv1 $vv2
            if (-not (Test-Finite $r.rmse)) { continue }
            $lab = "$n1+$n2"
            $metrics.Add([PSCustomObject]@{ target=$tn; model_type='pair'; coordinate=$lab; predictors=$lab; n=$mm.Count; loocv_rmse=$r.rmse; pearson_loocv=$r.pr; spearman_loocv=$r.sr })
        }
    }
}

$metrics | Export-Csv (Join-Path $runDir 'tables\coordinate_candidate_metrics.csv') -NoTypeInformation

$stab = @()
foreach ($tn in @('A_T_interp','R_T_interp','kappa')) {
    $mask = @($rows | ForEach-Object { [double]$_.T_K -ne 22 })
    $subRows = @($rows | Where-Object { [double]$_.T_K -ne 22 })
    $y = @($subRows | ForEach-Object { [double]$_.$tn })
    $z = @($subRows | ForEach-Object { [double]$_.X_T_interp })
    $r = Loocv-OnePred $y $z
    $stab += [PSCustomObject]@{ target=$tn; model='X_T_interp_only'; loocv_rmse_no22K=$r.rmse; pearson_loocv_no22K=$r.pr; spearman_loocv_no22K=$r.sr }
}
$stab | Export-Csv (Join-Path $runDir 'tables\coordinate_stability_no22K.csv') -NoTypeInformation

$bestLines = @(); $beats = 0
foreach ($tn in @('A_T_interp','R_T_interp','kappa')) {
    $sub = $metrics | Where-Object { $_.target -eq $tn -and $_.model_type -eq 'single' }
    $best1 = $sub | Sort-Object loocv_rmse | Select-Object -First 1
    $subp = $metrics | Where-Object { $_.target -eq $tn -and $_.model_type -eq 'pair' }
    $best2 = $subp | Sort-Object loocv_rmse | Select-Object -First 1
    $xrow = $sub | Where-Object { $_.coordinate -eq 'X_T_interp' }
    $xRmse = [double]$xrow.loocv_rmse
    if ([double]$best1.loocv_rmse -lt $xRmse - 1e-12) { $beats++ }
    $bestLines += [PSCustomObject]@{
        target = $tn
        best_single_name = $best1.coordinate
        best_single_loocv_rmse = [double]$best1.loocv_rmse
        X_only_loocv_rmse = $xRmse
        single_beats_X_rmse = ([double]$best1.loocv_rmse -lt $xRmse - 1e-12)
        best_pair_formula = $best2.coordinate
        best_pair_loocv_rmse = [double]$best2.loocv_rmse
        pair_beats_X_rmse = ([double]$best2.loocv_rmse -lt $xRmse - 1e-12)
    }
}
$bestLines | Export-Csv (Join-Path $runDir 'tables\best_coordinate_models.csv') -NoTypeInformation

$verdict = if ($beats -eq 3) { 'YES' } elseif ($beats -gt 0) { 'PARTIAL' } else { 'NO' }

$u = $metrics | Where-Object { $_.model_type -eq 'single' } | Select-Object -ExpandProperty coordinate -Unique
$means = foreach ($coord in $u) {
    $ms = $metrics | Where-Object { $_.model_type -eq 'single' -and $_.coordinate -eq $coord } | Select-Object -ExpandProperty loocv_rmse
    [PSCustomObject]@{ coordinate = $coord; mean_rmse = ($ms | Measure-Object -Average).Average }
}
$bestGlobal = $means | Sort-Object mean_rmse | Select-Object -First 1

# Figures: matplotlib not used — export simple CSV sidecar for best single coords
$figNotes = @()
foreach ($tn in @('A_T_interp','R_T_interp','kappa')) {
    $sub = $metrics | Where-Object { $_.target -eq $tn -and $_.model_type -eq 'single' }
    $best1 = $sub | Sort-Object loocv_rmse | Select-Object -First 1
    $cn = $best1.coordinate
    $stem = if ($tn -eq 'A_T_interp') { 'A_vs_coordinate' } elseif ($tn -eq 'R_T_interp') { 'R_vs_coordinate' } else { 'kappa_vs_coordinate' }
    $xv = $cand[$cn]
    $yv = @($rows | ForEach-Object { [double]$_.$tn })
    $pairs = for ($i = 0; $i -lt $xv.Length; $i++) {
        "{0},{1},{2}" -f $rows[$i].T_K, $xv[$i], $yv[$i]
    }
    @('T_K,x,y') + $pairs | Set-Content (Join-Path $runDir "figures\${stem}_data.csv") -Encoding utf8
    $figNotes += "$stem : best single = $cn (see ${stem}_data.csv for scatter series)"
    $pngPath = Join-Path $runDir "figures\${stem}.png"
    Export-ScatterPng $pngPath $xv $yv $cn (yLabelFromTarget $tn)
}

$pairsAll = $metrics | Where-Object { $_.model_type -eq 'pair' }
$pairNames = $pairsAll | Select-Object -ExpandProperty coordinate -Unique
$bestPairOverall = $null
$bestPairMean = [double]::PositiveInfinity
foreach ($pn in $pairNames) {
    $pr = @($pairsAll | Where-Object { $_.coordinate -eq $pn })
    if ($pr.Count -lt 3) { continue }
    $targetsHit = ($pr | Select-Object -ExpandProperty target -Unique).Count
    if ($targetsHit -lt 3) { continue }
    $m = ($pr | Measure-Object loocv_rmse -Average).Average
    if ($m -lt $bestPairMean) {
        $bestPairMean = $m
        $bestPairOverall = $pn
    }
}
[PSCustomObject]@{ best_two_variable_formula = $bestPairOverall; mean_loocv_rmse_ARk = $bestPairMean } |
    Export-Csv (Join-Path $runDir 'tables\best_two_variable_overall.csv') -NoTypeInformation

$report = @"
# Alternative coordinate search (beyond X)

## Summary

- **Verdict (any single beats X on LOOCV RMSE, all three targets):** $verdict ($beats/3)
- **Best single by mean RMSE across A, R, kappa:** ``$($bestGlobal.coordinate)`` (mean = $($bestGlobal.mean_rmse))

## Figures

PNG scatter (best single per target) and CSV series:

- ``figures/A_vs_coordinate.png`` / ``figures/A_vs_coordinate_data.csv``
- ``figures/R_vs_coordinate.png`` / ``figures/R_vs_coordinate_data.csv``
- ``figures/kappa_vs_coordinate.png`` / ``figures/kappa_vs_coordinate_data.csv``

$($figNotes -join "`n")

## Best two-variable (mean LOOCV RMSE across A, R, kappa)

See ``tables/best_two_variable_overall.csv``.

## Inputs

- ``$barrierPath``
- ``$kappaPath``
- ``$ptPath``

## Run folder

``$runDir``
"@
$report | Set-Content (Join-Path $runDir 'reports\alternative_coordinate_report.md') -Encoding utf8

"{ `"run_id`": `"$runId`", `"experiment`": `"cross_experiment`" }" | Set-Content (Join-Path $runDir 'run_manifest.json')
"alternative_coordinate_search.ps1" | Set-Content (Join-Path $runDir 'log.txt')
'Agent 11' | Set-Content (Join-Path $runDir 'run_notes.txt')
'% snapshot' | Set-Content (Join-Path $runDir 'config_snapshot.m')

Compress-Archive -Path (Join-Path $runDir 'figures'),(Join-Path $runDir 'tables'),(Join-Path $runDir 'reports'),(Join-Path $runDir 'run_manifest.json'),(Join-Path $runDir 'log.txt'),(Join-Path $runDir 'run_notes.txt'),(Join-Path $runDir 'config_snapshot.m') -DestinationPath (Join-Path $runDir 'review\alternative_coordinate_search_bundle.zip') -Force

Write-Host $runDir
Write-Host "VERDICT=$verdict BEST_GLOBAL=$($bestGlobal.coordinate) MEAN_RMSE=$($bestGlobal.mean_rmse)"
