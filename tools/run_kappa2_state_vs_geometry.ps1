# Agent 19A: kappa2 state vs geometry — read-only CSV merge (PowerShell).
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot

function Get-Mean([double[]]$a) {
    if ($a.Count -eq 0) { return [double]::NaN }
    ($a | Measure-Object -Average).Average
}

function Get-Pearson([double[]]$x, [double[]]$y) {
    $n = [Math]::Min($x.Count, $y.Count)
    if ($n -lt 3) { return [double]::NaN }
    $mx = Get-Mean $x; $my = Get-Mean $y
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $vx = $x[$i] - $mx; $vy = $y[$i] - $my
        $num += $vx * $vy; $dx += $vx * $vx; $dy += $vy * $vy
    }
    if ($dx -le 0 -or $dy -le 0) { return [double]::NaN }
    return $num / [Math]::Sqrt($dx * $dy)
}

function Get-Ranks([double[]]$v) {
    $n = $v.Count
    $idx = 0..($n - 1) | Sort-Object { $v[$_] }
    $r = New-Object double[] $n
    $i = 0
    while ($i -lt $n) {
        $j = $i
        while ($j -lt $n -and ($v[$idx[$j]] -eq $v[$idx[$i]])) { $j++ }
        $avg = (($i + 1) + $j) / 2.0
        for ($k = $i; $k -lt $j; $k++) { $r[$idx[$k]] = $avg }
        $i = $j
    }
    , $r
}

function Get-Spearman([double[]]$x, [double[]]$y) {
    $n = [Math]::Min($x.Count, $y.Count)
    if ($n -lt 3) { return [double]::NaN }
    $rx = Get-Ranks $x
    $ry = Get-Ranks $y
    return (Get-Pearson $rx $ry)
}

function Get-SafeCorr([double[]]$x, [double[]]$y) {
    $m = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt [Math]::Min($x.Count, $y.Count); $i++) {
        if (-not [double]::IsNaN($x[$i]) -and -not [double]::IsNaN($y[$i])) {
            [void]$m.Add(@($x[$i], $y[$i]))
        }
    }
    if ($m.Count -lt 3) { return @{ Pearson = [double]::NaN; Spearman = [double]::NaN; N = $m.Count } }
    $xx = @($m | ForEach-Object { $_[0] }); $yy = @($m | ForEach-Object { $_[1] })
    return @{ Pearson = (Get-Pearson $xx $yy); Spearman = (Get-Spearman $xx $yy); N = $m.Count }
}

function M2-Get([double[,]]$M, [int]$i, [int]$j) { return [double]$M.GetValue($i, $j) }
function M2-Set([double[,]]$M, [int]$i, [int]$j, [double]$v) { [void]$M.SetValue($v, $i, $j) }

function Invert-Matrix([double[,]]$A) {
    $n = $A.GetLength(0)
    $M = New-Object 'double[,]' $n, (2 * $n)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { M2-Set $M $i $j (M2-Get $A $i $j) }
        M2-Set $M $i ($n + $i) 1.0
    }
    for ($col = 0; $col -lt $n; $col++) {
        $piv = $col
        $maxv = [Math]::Abs((M2-Get $M $piv $col))
        for ($r = $col + 1; $r -lt $n; $r++) {
            $v = [Math]::Abs((M2-Get $M $r $col))
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        if ($maxv -lt 1e-15) { throw "Singular matrix" }
        if ($piv -ne $col) {
            for ($c = 0; $c -lt 2 * $n; $c++) {
                $t = M2-Get $M $col $c
                M2-Set $M $col $c (M2-Get $M $piv $c)
                M2-Set $M $piv $c $t
            }
        }
        $d = M2-Get $M $col $col
        for ($c = 0; $c -lt 2 * $n; $c++) { M2-Set $M $col $c ((M2-Get $M $col $c) / $d) }
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $col) { continue }
            $f = M2-Get $M $r $col
            for ($c = 0; $c -lt 2 * $n; $c++) {
                M2-Set $M $r $c ((M2-Get $M $r $c) - $f * (M2-Get $M $col $c))
            }
        }
    }
    $Inv = New-Object 'double[,]' $n, $n
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { M2-Set $Inv $i $j (M2-Get $M $i ($n + $j)) }
    }
    return , $Inv
}

function Solve-Linear([double[,]]$A, [double[]]$b) {
    $Inv = Invert-Matrix $A
    $n = $b.Count
    $x = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $s = 0.0
        for ($j = 0; $j -lt $n; $j++) { $s += (M2-Get $Inv $i $j) * $b[$j] }
        $x[$i] = $s
    }
    return , $x
}

function Invoke-Loocv([double[,]]$X, [double[]]$y) {
    $n = $y.Count
    $p = $X.GetLength(1)
    if ($n -lt $p + 1) { return @{ Rmse = [double]::NaN; Pearson = [double]::NaN } }
    $XtX = New-Object 'double[,]' $p, $p
    $Xty = New-Object double[] $p
    for ($a = 0; $a -lt $p; $a++) {
        for ($b = 0; $b -lt $p; $b++) {
            $s = 0.0
            for ($i = 0; $i -lt $n; $i++) { $s += (M2-Get $X $i $a) * (M2-Get $X $i $b) }
            M2-Set $XtX $a $b $s
        }
        $s2 = 0.0
        for ($i = 0; $i -lt $n; $i++) { $s2 += (M2-Get $X $i $a) * $y[$i] }
        $Xty[$a] = $s2
    }
    $beta = Solve-Linear $XtX $Xty
    $yhat = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $s = 0.0
        for ($a = 0; $a -lt $p; $a++) { $s += (M2-Get $X $i $a) * $beta[$a] }
        $yhat[$i] = $s
    }
    $Xi = Invert-Matrix $XtX
    $h = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $s = 0.0
        for ($a = 0; $a -lt $p; $a++) {
            for ($b = 0; $b -lt $p; $b++) {
                $s += (M2-Get $X $i $a) * (M2-Get $Xi $a $b) * (M2-Get $X $i $b)
            }
        }
        $h[$i] = $s
    }
    $se = 0.0
    $yloo = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $den = 1.0 - $h[$i]
        if ([Math]::Abs($den) -lt 1e-12) { return @{ Rmse = [double]::NaN; Pearson = [double]::NaN } }
        $yloo[$i] = ($yhat[$i] - $h[$i] * $y[$i]) / $den
        $se += ($y[$i] - $yloo[$i]) * ($y[$i] - $yloo[$i])
    }
    $rmse = [Math]::Sqrt($se / $n)
    $rpear = Get-Pearson $y $yloo
    return @{ Rmse = $rmse; Pearson = $rpear }
}

function Build-Design($rlist, $cols) {
    $n = $rlist.Count
    $p = $cols.Count + 1
    $X = New-Object 'double[,]' $n, $p
    for ($i = 0; $i -lt $n; $i++) {
        M2-Set $X $i 0 1.0
        for ($j = 0; $j -lt $cols.Count; $j++) {
            M2-Set $X $i (1 + $j) ([double]$rlist[$i].($cols[$j]))
        }
    }
    return , $X
}

function Filter-Rows($rlist, [string[]]$colnames) {
    @($rlist | Where-Object {
        $ok = $true
        foreach ($c in $colnames) {
            $v = $_.$c
            if ($null -eq $v) { $ok = $false; break }
            try { $d = [double]$v } catch { $ok = $false; break }
            if ([double]::IsNaN($d)) { $ok = $false; break }
        }
        $ok
    })
}

# --- paths ---
$rsPath = Join-Path $Repo 'results\switching\runs\run_2026_03_25_043610_kappa_phi_temperature_structure_test\tables\residual_rank_structure_vs_T.csv'
$ptPath = Join-Path $Repo 'results\switching\runs\run_2026_03_25_013849_pt_robust_minpts7\tables\PT_summary.csv'
$bdPath = Join-Path $Repo 'results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv'
$thrPath = Join-Path $Repo 'results\switching\runs\run_2026_03_24_013519_switching_threshold_residual_structure\tables\switching_threshold_residual_metrics_vs_temperature.csv'
$specPath = Join-Path $Repo 'results\switching\runs\run_2026_03_25_043610_kappa_phi_temperature_structure_test\tables\residual_rank_spectrum.csv'

$rs = Import-Csv $rsPath | Where-Object { $_.subset -eq 'T_le_30' }
$pt = Import-Csv $ptPath
$bd = Import-Csv $bdPath
$thr = Import-Csv $thrPath
$spec = Import-Csv $specPath | Where-Object { $_.subset -eq 'T_le_30' } | Select-Object -First 1

$rows = @()
foreach ($r in $rs) {
    $tk = [double]$r.T_K
    $prow = $pt | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    $brow = $bd | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    $trow = $thr | Where-Object { [double]$_.T_K -eq $tk } | Select-Object -First 1
    $med = [double]::NaN
    if ($brow) {
        $mraw = $brow.median_I_mA
        if ([string]::IsNullOrEmpty($mraw)) {
            $med = [double]$brow.q50_I_mA
        }
        else {
            $med = [double]$mraw
            if ([double]::IsNaN($med)) { $med = [double]$brow.q50_I_mA }
        }
    }
    $gap90_50 = if ($brow) { [double]$brow.q90_I_mA - [double]$brow.q50_I_mA } else { [double]::NaN }
    $gap90_75 = if ($brow) { [double]$brow.q90_I_mA - [double]$brow.q75_I_mA } else { [double]::NaN }
    $row = [ordered]@{
        T_K = $tk
        kappa1 = [double]$r.kappa
        kappa2 = [double]$r.rel_orth_leftover_norm
        I_peak_mA = [double]$r.I_peak_mA
        S_peak = [double]$r.S_peak
        mean_threshold_mA = if ($prow) { [double]$prow.mean_threshold_mA } else { [double]::NaN }
        std_threshold_mA = if ($prow) { [double]$prow.std_threshold_mA } else { [double]::NaN }
        skewness = if ($prow) { [double]$prow.skewness } else { [double]::NaN }
        median_I_use = $med
        gap_q90_q50 = $gap90_50
        gap_q75_q25 = if ($brow) { [double]$brow.iq75_25_mA } else { [double]::NaN }
        gap_q90_q75_proxy = $gap90_75
        skewness_quantile = if ($brow) { [double]$brow.skewness_quantile } else { [double]::NaN }
        asym_q_barrier = if ($brow) { [double]$brow.asym_q75_50_minus_q50_25 } else { [double]::NaN }
        residual_rmse = if ($trow) { [double]$trow.residual_rmse } else { [double]::NaN }
        residual_variance = if ($trow) { [double]$trow.residual_variance } else { [double]::NaN }
        residual_l2 = if ($trow) { [double]$trow.residual_l2 } else { [double]::NaN }
    }
    $row.kappa2_norm_S = $row.kappa2 / [Math]::Max($row.S_peak, 1e-15)
    $row.kappa2_norm_k1 = $row.kappa2 / [Math]::Max($row.kappa1, 1e-15)
    $rows += [pscustomobject]$row
}

$y = @($rows | ForEach-Object { $_.kappa2 })
$predNames = @(
    'I_peak_mA', 'median_I_use', 'gap_q90_q50', 'gap_q75_q25', 'gap_q90_q75_proxy',
    'skewness', 'skewness_quantile', 'asym_q_barrier', 'mean_threshold_mA', 'std_threshold_mA',
    'kappa1', 'residual_rmse', 'residual_variance', 'residual_l2', 'kappa2_norm_S', 'kappa2_norm_k1'
)
$corrOut = @()
foreach ($name in $predNames) {
    $xv = @($rows | ForEach-Object { $_.$name })
    $c = Get-SafeCorr ([double[]]$xv) ([double[]]$y)
    $corrOut += [pscustomobject]@{ analysis_block = 'correlation_vs_kappa2'; name = $name; pearson = $c.Pearson; spearman = $c.Spearman; n = $c.N; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = [double]::NaN }
}

$ip = @($rows | ForEach-Object { $_.I_peak_mA })
$n1 = Get-SafeCorr ([double[]]$y) ([double[]]$ip)
$n2 = Get-SafeCorr (@($rows | ForEach-Object { $_.kappa2_norm_S })) ([double[]]$ip)
$n3 = Get-SafeCorr (@($rows | ForEach-Object { $_.kappa2_norm_k1 })) ([double[]]$ip)
$normOut = @(
    [pscustomobject]@{ analysis_block = 'normalization_vs_I_peak'; name = 'corr(kappa2, I_peak)'; pearson = $n1.Pearson; spearman = $n1.Spearman; n = $n1.N; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = [double]::NaN }
    [pscustomobject]@{ analysis_block = 'normalization_vs_I_peak'; name = 'corr(kappa2/S_peak, I_peak)'; pearson = $n2.Pearson; spearman = $n2.Spearman; n = $n2.N; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = [double]::NaN }
    [pscustomobject]@{ analysis_block = 'normalization_vs_I_peak'; name = 'corr(kappa2/kappa1, I_peak)'; pearson = $n3.Pearson; spearman = $n3.Spearman; n = $n3.N; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = [double]::NaN }
)

$m1 = Filter-Rows $rows @('I_peak_mA')
if ($m1.Count -ge 4) {
    $X1 = Build-Design $m1 @('I_peak_mA')
    $yy = @($m1 | ForEach-Object { $_.kappa2 })
    $lo1 = Invoke-Loocv $X1 $yy
} else { $lo1 = @{ Rmse = [double]::NaN; Pearson = [double]::NaN } }

$m2 = Filter-Rows $rows @('I_peak_mA', 'std_threshold_mA', 'gap_q90_q50')
if ($m2.Count -ge 5) {
    $X2 = Build-Design $m2 @('I_peak_mA', 'std_threshold_mA', 'gap_q90_q50')
    $yy2 = @($m2 | ForEach-Object { $_.kappa2 })
    $lo2 = Invoke-Loocv $X2 $yy2
} else { $lo2 = @{ Rmse = [double]::NaN; Pearson = [double]::NaN } }

$m3 = Filter-Rows $rows @('kappa1', 'std_threshold_mA', 'gap_q90_q50')
if ($m3.Count -ge 5) {
    $X3 = Build-Design $m3 @('kappa1', 'std_threshold_mA', 'gap_q90_q50')
    $yy3 = @($m3 | ForEach-Object { $_.kappa2 })
    $lo3 = Invoke-Loocv $X3 $yy3
} else { $lo3 = @{ Rmse = [double]::NaN; Pearson = [double]::NaN } }

$modelsOut = @(
    [pscustomobject]@{ analysis_block = 'loocv_model'; name = 'kappa2 ~ I_peak'; pearson = [double]::NaN; spearman = [double]::NaN; n = $m1.Count; loocv_rmse = $lo1.Rmse; loocv_pearson = $lo1.Pearson; global_metric_value = [double]::NaN }
    [pscustomobject]@{ analysis_block = 'loocv_model'; name = 'kappa2 ~ I_peak + std + (q90-q50)'; pearson = [double]::NaN; spearman = [double]::NaN; n = $m2.Count; loocv_rmse = $lo2.Rmse; loocv_pearson = $lo2.Pearson; global_metric_value = [double]::NaN }
    [pscustomobject]@{ analysis_block = 'loocv_model'; name = 'kappa2 ~ kappa1 + std + (q90-q50)'; pearson = [double]::NaN; spearman = [double]::NaN; n = $m3.Count; loocv_rmse = $lo3.Rmse; loocv_pearson = $lo3.Pearson; global_metric_value = [double]::NaN }
)

$e1 = [double]$spec.variance_explained_mode1
$e12 = [double]$spec.variance_explained_modes1_plus_2
$g1 = 1 - $e1
$g2 = $e12 - $e1

$globOut = @(
    [pscustomobject]@{ analysis_block = 'global_stack_spectrum_T_le_30'; name = 'energy_outside_rank1_1_minus_E1'; pearson = [double]::NaN; spearman = [double]::NaN; n = [double]::NaN; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = $g1 }
    [pscustomobject]@{ analysis_block = 'global_stack_spectrum_T_le_30'; name = 'energy_mode2_only_E12_minus_E1'; pearson = [double]::NaN; spearman = [double]::NaN; n = [double]::NaN; loocv_rmse = [double]::NaN; loocv_pearson = [double]::NaN; global_metric_value = $g2 }
)

$all = $corrOut + $normOut + $modelsOut + $globOut
$outCsv = Join-Path $Repo 'tables\kappa2_state_vs_geometry.csv'
if (-not (Test-Path (Split-Path $outCsv))) { New-Item -ItemType Directory -Path (Split-Path $outCsv) -Force | Out-Null }
$all | Export-Csv -Path $outCsv -NoTypeInformation -Encoding utf8

# Verdict
$geomKeys = @('I_peak_mA', 'median_I_use', 'gap_q90_q50', 'gap_q75_q25', 'gap_q90_q75_proxy', 'skewness', 'std_threshold_mA')
$stateKeys = @('kappa1', 'residual_rmse', 'residual_variance')
$geomStrength = ($corrOut | Where-Object { $geomKeys -contains $_.name } | ForEach-Object { [Math]::Abs([double]$_.spearman) } | Measure-Object -Maximum).Maximum
$stateStrength = ($corrOut | Where-Object { $stateKeys -contains $_.name } | ForEach-Object { [Math]::Abs([double]$_.spearman) } | Measure-Object -Maximum).Maximum
$spK1 = [double]($corrOut | Where-Object { $_.name -eq 'kappa1' } | Select-Object -ExpandProperty spearman -First 1)
$meanY = Get-Mean $y
$stdK2 = [Math]::Sqrt(($y | ForEach-Object { ($meanY - $_) * ($meanY - $_) } | Measure-Object -Sum).Sum / [Math]::Max(1, ($y.Count - 1)))

$bestRmse = [double]::PositiveInfinity
$bestP = [double]::NaN
foreach ($mo in $modelsOut) {
    $v = [double]$mo.loocv_rmse
    if ([double]::IsNaN($v)) { continue }
    if ($v -lt $bestRmse) { $bestRmse = $v; $bestP = [double]$mo.loocv_pearson }
}
if ([double]::IsPositiveInfinity($bestRmse)) { $bestRmse = [double]::NaN }
$relRmse = if ($stdK2 -gt 0) { $bestRmse / $stdK2 } else { [double]::NaN }

$K_STATE = ($stateStrength -ge 0.45) -or ([Math]::Abs($spK1) -ge 0.45)
$K_GEOM = $geomStrength -ge 0.45
$K_PRED = (($relRmse -lt 0.55) -and (-not [double]::IsNaN($bestP)) -and ([Math]::Abs($bestP) -ge 0.65)) -or ((-not [double]::IsNaN($bestP)) -and ([Math]::Abs($bestP) -ge 0.75))

# PNG
Add-Type -AssemblyName System.Drawing
$W = 900; $H = 700
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$font = New-Object System.Drawing.Font 'Segoe UI', 9
$brush = [System.Drawing.Brushes]::Black
$minT = ($rows | ForEach-Object { $_.T_K } | Measure-Object -Minimum).Minimum
$maxT = ($rows | ForEach-Object { $_.T_K } | Measure-Object -Maximum).Maximum

function Draw-Scatter($g, [float]$gx, [float]$gy, [float]$gw, [float]$gh, [double[]]$xs, [double[]]$ys, [double[]]$tk, [string]$title, [string]$xlab) {
    $pad = 36
    $fx = @(); $fy = @(); $ft = @()
    for ($i = 0; $i -lt [Math]::Min($xs.Count, $ys.Count); $i++) {
        if (-not [double]::IsNaN($xs[$i]) -and -not [double]::IsNaN($ys[$i])) {
            $fx += $xs[$i]; $fy += $ys[$i]; $ft += $tk[$i]
        }
    }
    if ($fx.Count -eq 0) { return }
    $minx = ($fx | Measure-Object -Minimum).Minimum; $maxx = ($fx | Measure-Object -Maximum).Maximum
    $miny = ($fy | Measure-Object -Minimum).Minimum; $maxy = ($fy | Measure-Object -Maximum).Maximum
    if ($maxx -eq $minx) { $maxx = $minx + 1e-6 }
    if ($maxy -eq $miny) { $maxy = $miny + 1e-6 }
    $sf = New-Object System.Drawing.StringFormat
    $rect = [System.Drawing.RectangleF]::new($gx + 4, $gy + 4, $gw - 8, 40)
    [void]$g.DrawString($title, $font, $brush, $rect, $sf)
    for ($i = 0; $i -lt $fx.Count; $i++) {
        $px = [float]($gx + $pad + ($fx[$i] - $minx) / ($maxx - $minx) * ($gw - 2 * $pad))
        $py = [float]($gy + $gh - $pad - ($fy[$i] - $miny) / ($maxy - $miny) * ($gh - 2 * $pad))
        $t = $ft[$i]
        $hue = [int](255 * ($t - $minT) / [Math]::Max(1e-9, ($maxT - $minT)))
        $col = [System.Drawing.Color]::FromArgb(255, 80 + ($hue % 120), 100, 220 - ($hue % 80))
        $sb = New-Object System.Drawing.SolidBrush $col
        [void]$g.FillEllipse($sb, [float]$px - 3, [float]$py - 3, 6, 6)
        $sb.Dispose()
    }
    $rect2 = [System.Drawing.RectangleF]::new($gx + $pad, $gy + $gh - 28, $gw - 2 * $pad, 22)
    [void]$g.DrawString($xlab, $font, $brush, $rect2, $sf)
}

$pw = [int]($W / 2); $ph = [int]($H / 2)
$tk = @($rows | ForEach-Object { $_.T_K })
Draw-Scatter $g 0 0 $pw $ph (@($rows | ForEach-Object { $_.I_peak_mA })) $y $tk 'kappa2 vs I_peak' 'I_peak_mA'
Draw-Scatter $g $pw 0 $pw $ph (@($rows | ForEach-Object { $_.median_I_use })) $y $tk 'kappa2 vs median_I' 'median_I'
Draw-Scatter $g 0 $ph $pw $ph (@($rows | ForEach-Object { $_.gap_q90_q50 })) $y $tk 'kappa2 vs (q90-q50)' 'q90-q50'
Draw-Scatter $g $pw $ph $pw $ph (@($rows | ForEach-Object { $_.kappa1 })) $y $tk 'kappa2 vs kappa1' 'kappa1'

$figPath = Join-Path $Repo 'figures\kappa2_vs_shape.png'
if (-not (Test-Path (Split-Path $figPath))) { New-Item -ItemType Directory -Path (Split-Path $figPath) -Force | Out-Null }
$bmp.Save($figPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$rep = @"
# Kappa2 state vs geometry (Agent 19A)

## Data sources (read-only)

- kappa2 = ``rel_orth_leftover_norm``, subset **T_le_30**: ``$($rsPath.Replace('\','/'))``
- PT summary: ``$($ptPath.Replace('\','/'))``
- Barrier quantiles: ``$($bdPath.Replace('\','/'))``
- Threshold residual per T: ``$($thrPath.Replace('\','/'))``
- Rank spectrum: ``$($specPath.Replace('\','/'))``

## Correlations vs kappa2

$(($corrOut | Sort-Object name | Format-Table -AutoSize | Out-String))

## Normalization vs I_peak

$(($normOut | Format-Table -AutoSize | Out-String))

## LOOCV models

$(($modelsOut | Format-Table -AutoSize | Out-String))

## Globals (stack T_le_30)

- energy_outside_rank1 (1-E1): $g1
- energy_mode2_only (E12-E1): $g2

## Figure

- ``figures/kappa2_vs_shape.png``

## FINAL VERDICT

- **KAPPA2_IS_STATE_LIKE**: $(if ($K_STATE) { 'YES' } else { 'NO' }) (max |Spearman| state block=$([Math]::Round($stateStrength,4)), Sp(kappa1)=$([Math]::Round($spK1,4)))
- **KAPPA2_IS_GEOMETRIC_LIKE**: $(if ($K_GEOM) { 'YES' } else { 'NO' }) (max |Spearman| geometry block=$([Math]::Round($geomStrength,4)))
- **KAPPA2_SIMPLE_PREDICTABLE**: $(if ($K_PRED) { 'YES' } else { 'NO' }) (best LOOCV RMSE=$bestRmse, sigma(k2)=$([Math]::Round($stdK2,6)), ratio=$([Math]::Round($relRmse,4)), Pearson LOO=$bestP)

Notes: q95-q75 uses **q90-q75** proxy (no q95 in barrier CSV). Barrier join is missing at some T; correlations use pairwise-complete ``n``.
"@
$repPath = Join-Path $Repo 'reports\kappa2_state_geometry_report.md'
if (-not (Test-Path (Split-Path $repPath))) { New-Item -ItemType Directory -Path (Split-Path $repPath) -Force | Out-Null }
Set-Content -Path $repPath -Value $rep -Encoding utf8

Write-Host "Wrote $outCsv"
Write-Host "Wrote $figPath"
Write-Host "Wrote $repPath"
