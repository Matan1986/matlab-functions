# Computes Agent 19C metrics and writes CSV + MD (PNG separate).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

$k1 = @(0.179546725888347,0.190781377067108,0.19690765457114,0.17710703759542,0.15269503326033,0.12447122604336,0.107134927362003,0.0980185873442758,0.0898318457622685,0.0382966167716672,0.0699734936967039,0.0640590044738315,0.0611692729252666,0.0481472826690587)
$k2 = @(0.20566490879438,0.121537225462719,0.0569295636900701,0.0873473791013738,0.0780800430132319,0.0952926383974761,0.13074229917065,0.152615736452342,0.134395642319155,0.532434417257023,0.394390116511962,0.37133294817989,0.316557413262108,0.80000765309874)
$TempsK = @(4,6,8,10,12,14,16,18,20,22,24,26,28,30)
$k1 = [double[]]@($k1 | ForEach-Object { [double]$_ })
$k2 = [double[]]@($k2 | ForEach-Object { [double]$_ })
$n = $k1.Length

function Get-Mean([double[]]$a) { ($a | Measure-Object -Average).Average }
function Get-Kendall([double[]]$x, [double[]]$y) {
    $conc = 0; $disc = 0
    for ($i = 0; $i -lt $x.Length; $i++) {
        for ($j = $i + 1; $j -lt $x.Length; $j++) {
            $dx = $x[$i] - $x[$j]; $dy = $y[$i] - $y[$j]
            if ($dx * $dy -gt 0) { $conc++ }
            elseif ($dx * $dy -lt 0) { $disc++ }
        }
    }
    $tot = $conc + $disc
    if ($tot -le 0) { return 0.0 }
    return [double]($conc - $disc) / $tot
}

$tau1 = Get-Kendall $TempsK $k1
$tau2 = Get-Kendall $TempsK $k2

$d1 = @(); for ($i = 1; $i -lt $k1.Length; $i++) { $d1 += $k1[$i] - $k1[$i - 1] }
$d2 = @(); for ($i = 1; $i -lt $k2.Length; $i++) { $d2 += $k2[$i] - $k2[$i - 1] }
$mono1 = 0; for ($i = 1; $i -lt $d1.Length; $i++) { if ([Math]::Sign($d1[$i - 1]) -ne [Math]::Sign($d1[$i])) { $mono1++ } }
$mono2 = 0; for ($i = 1; $i -lt $d2.Length; $i++) { if ([Math]::Sign($d2[$i - 1]) -ne [Math]::Sign($d2[$i])) { $mono2++ } }

$regCode = New-Object int[] $n
for ($i = 0; $i -lt $n; $i++) {
    $t = $TempsK[$i]
    if ($t -ge 4 -and $t -le 12) { $regCode[$i] = 1 }
    elseif ($t -ge 14 -and $t -le 20) { $regCode[$i] = 2 }
    elseif ($t -ge 22 -and $t -le 30) { $regCode[$i] = 3 }
    else { $regCode[$i] = 0 }
}
function Get-CentroidXY([int]$code) {
    $sx = 0.0; $sy = 0.0; $cnt = 0
    for ($i = 0; $i -lt $TempsK.Length; $i++) {
        if ($regCode[$i] -eq $code) { $sx += $k1[$i]; $sy += $k2[$i]; $cnt++ }
    }
    if ($cnt -eq 0) { return @(0.0, 0.0) }
    return @([double]($sx / $cnt), [double]($sy / $cnt))
}
$cLxy = Get-CentroidXY 1
$cMxy = Get-CentroidXY 2
$cHxy = Get-CentroidXY 3
$d12 = [Math]::Sqrt(([double]$cLxy[0] - [double]$cMxy[0]) * ([double]$cLxy[0] - [double]$cMxy[0]) + ([double]$cLxy[1] - [double]$cMxy[1]) * ([double]$cLxy[1] - [double]$cMxy[1]))
$d23 = [Math]::Sqrt(([double]$cMxy[0] - [double]$cHxy[0]) * ([double]$cMxy[0] - [double]$cHxy[0]) + ([double]$cMxy[1] - [double]$cHxy[1]) * ([double]$cMxy[1] - [double]$cHxy[1]))
$d13 = [Math]::Sqrt(([double]$cLxy[0] - [double]$cHxy[0]) * ([double]$cLxy[0] - [double]$cHxy[0]) + ([double]$cLxy[1] - [double]$cHxy[1]) * ([double]$cLxy[1] - [double]$cHxy[1]))

# Fixed ladder 4:2:30 K => index(T) = (T-4)/2
$i20 = [int]((20 - 4) / 2)
$i22 = [int]((22 - 4) / 2)
$i24 = [int]((24 - 4) / 2)
$p20x = [double]$k1[$i20]; $p20y = [double]$k2[$i20]
$p22x = [double]$k1[$i22]; $p22y = [double]$k2[$i22]
$p24x = [double]$k1[$i24]; $p24y = [double]$k2[$i24]
$sx1 = $p22x - $p20x; $sy1 = $p22y - $p20y
$sx2 = $p24x - $p22x; $sy2 = $p24y - $p22y
$n1 = [Math]::Sqrt($sx1 * $sx1 + $sy1 * $sy1)
$n2 = [Math]::Sqrt($sx2 * $sx2 + $sy2 * $sy2)
$dot = $sx1 * $sx2 + $sy1 * $sy2
$den = $n1 * $n2
$c = $dot / $den
if ([double]::IsNaN($c) -or [double]::IsInfinity($c)) { throw "Bad cosine: dot=$dot den=$den n1=$n1 n2=$n2" }
$c = [Math]::Max(-1.0, [Math]::Min(1.0, $c))
$curv = [double]([Math]::Acos([double]$c) * 180.0 / [Math]::PI)
$jump2022 = [Math]::Sqrt(($p22x - $p20x) * ($p22x - $p20x) + ($p22y - $p20y) * ($p22y - $p20y))
$seg2224 = [Math]::Sqrt(($k1[$i24] - $k1[$i22]) * ($k1[$i24] - $k1[$i22]) + ($k2[$i24] - $k2[$i22]) * ($k2[$i24] - $k2[$i22]))
$speed2022 = $jump2022 / ($TempsK[$i22] - $TempsK[$i20])
$speed2224 = $seg2224 / ($TempsK[$i24] - $TempsK[$i22])
$speedRatio = $speed2224 / [Math]::Max($speed2022, 1e-15)

$m1 = Get-Mean $k1; $m2 = Get-Mean $k2
$num = 0.0; $dx2 = 0.0; $dy2 = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $vx = $k1[$i] - $m1; $vy = $k2[$i] - $m2
    $num += $vx * $vy; $dx2 += $vx * $vx; $dy2 += $vy * $vy
}
$rho = $num / [Math]::Sqrt($dx2 * $dy2)
$pc1Frac = (1 + [Math]::Abs($rho)) / 2
$pc2Frac = 1 - $pc1Frac

$b1 = $num / $dx2
$b0 = $m2 - $b1 * $m1
$ssResLin = 0.0; $ssTot = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $yh = $b0 + $b1 * $k1[$i]
    $ssResLin += ($k2[$i] - $yh) * ($k2[$i] - $yh)
    $dv = $k2[$i] - $m2
    $ssTot += $dv * $dv
}
$r2Lin = 1.0 - $ssResLin / $ssTot
$rmseLin = [Math]::Sqrt($ssResLin / $n)

# Polyfit via normal equations (small p); build matrix in nested arrays then solve by Cramer for p<=5
function PolyFit([double[]]$x, [double[]]$y, [int]$deg) {
    $p = $deg + 1
    $nloc = $x.Length
    $AtA = New-Object 'object[]' $p
    for ($r = 0; $r -lt $p; $r++) { $AtA[$r] = New-Object double[] $p }
    $Aty = New-Object double[] $p
    for ($i = 0; $i -lt $nloc; $i++) {
        $xi = $x[$i]
        $pow = New-Object double[] $p
        $pow[0] = 1.0
        for ($a = 1; $a -lt $p; $a++) { $pow[$a] = $pow[$a - 1] * $xi }
        for ($a = 0; $a -lt $p; $a++) {
            for ($b = 0; $b -lt $p; $b++) { $AtA[$a][$b] += $pow[$a] * $pow[$b] }
            $Aty[$a] += $pow[$a] * $y[$i]
        }
    }
    # Gaussian elimination on AtA * coef = Aty
    $M = New-Object 'object[]' $p
    for ($r = 0; $r -lt $p; $r++) {
        $row = New-Object double[] ($p + 1)
        for ($c = 0; $c -lt $p; $c++) { $row[$c] = $AtA[$r][$c] }
        $row[$p] = $Aty[$r]
        $M[$r] = $row
    }
    for ($col = 0; $col -lt $p; $col++) {
        $piv = $col; $maxv = [Math]::Abs($M[$col][$col])
        for ($r = $col + 1; $r -lt $p; $r++) {
            $v = [Math]::Abs($M[$r][$col])
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        if ($piv -ne $col) {
            $tmp = $M[$col]; $M[$col] = $M[$piv]; $M[$piv] = $tmp
        }
        $diag = $M[$col][$col]
        if ([Math]::Abs($diag) -lt 1e-18) { throw 'Singular' }
        for ($c = $col; $c -le $p; $c++) { $M[$col][$c] /= $diag }
        for ($r = 0; $r -lt $p; $r++) {
            if ($r -eq $col) { continue }
            $f = $M[$r][$col]
            if ([Math]::Abs($f) -lt 1e-20) { continue }
            for ($c = $col; $c -le $p; $c++) { $M[$r][$c] -= $f * $M[$col][$c] }
        }
    }
    $coef = New-Object double[] $p
    for ($i = 0; $i -lt $p; $i++) { $coef[$i] = $M[$i][$p] }
    return ,$coef
}

function PolyVal([double[]]$coef, [double]$x) {
    $s = 0.0; $xp = 1.0
    for ($i = 0; $i -lt $coef.Length; $i++) { $s += $coef[$i] * $xp; $xp *= $x }
    return $s
}

$bestDeg = 1
$bestR2 = $r2Lin
$bestRmse = $rmseLin
for ($deg = 2; $deg -le 4; $deg++) {
    $coef = PolyFit $k1 $k2 $deg
    $ssr = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $yh = PolyVal $coef $k1[$i]
        $ssr += ($k2[$i] - $yh) * ($k2[$i] - $yh)
    }
    $r2p = 1.0 - $ssr / $ssTot
    if ($r2p -gt $bestR2) { $bestR2 = $r2p; $bestDeg = $deg; $bestRmse = [Math]::Sqrt($ssr / $n) }
}
$coefF = PolyFit $k1 $k2 $bestDeg
$varK2 = ($ssTot / $n)
$resVar = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $yh = PolyVal $coefF $k1[$i]
    $resVar += ($k2[$i] - $yh) * ($k2[$i] - $yh)
}
$relVarResid = ($resVar / $n) / [Math]::Max($varK2, 1e-15)

$pc1Thr = 0.90
$r2Thr = 0.85
$curvThr = 25.0
$speedThr = 1.5
$coll2d = ($pc1Frac -lt $pc1Thr) -or ($bestR2 -lt $r2Thr)
$dimRed = ($bestR2 -ge $r2Thr) -and ($relVarResid -le 0.15)
$regReorg = ($curv -gt $curvThr) -or ($speedRatio -gt $speedThr) -or ($d23 -gt 0.5 * ($d12 + $d13))
$vCol = if ($coll2d) { 'YES' } else { 'NO' }
$vReg = if ($regReorg) { 'YES' } else { 'NO' }
$vDim = if ($dimRed) { 'YES' } else { 'NO' }

# z-scores for PCA panel
$vk1s = 0.0; $vk2s = 0.0
for ($i = 0; $i -lt $n; $i++) {
    $t1 = $k1[$i] - $m1; $t2 = $k2[$i] - $m2
    $vk1s += $t1 * $t1; $vk2s += $t2 * $t2
}
$sd1 = [Math]::Sqrt($vk1s / $n); $sd2 = [Math]::Sqrt($vk2s / $n)
$z1 = @(); $z2 = @()
for ($i = 0; $i -lt $n; $i++) {
    $z1 += ($k1[$i] - $m1) / [Math]::Max($sd1, 1e-18)
    $z2 += ($k2[$i] - $m2) / [Math]::Max($sd2, 1e-18)
}
$sc1 = @(); $sc2 = @()
for ($i = 0; $i -lt $n; $i++) {
    if ($rho -ge 0) {
        $sc1 += ($z1[$i] + $z2[$i]) / [Math]::Sqrt(2.0)
        $sc2 += (-$z1[$i] + $z2[$i]) / [Math]::Sqrt(2.0)
    } else {
        $sc1 += ($z1[$i] - $z2[$i]) / [Math]::Sqrt(2.0)
        $sc2 += ($z1[$i] + $z2[$i]) / [Math]::Sqrt(2.0)
    }
}

# ---- PNG ----
Add-Type -AssemblyName System.Drawing
$w = 900; $h = 420
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::White)
$font = New-Object System.Drawing.Font('Segoe UI', 8)
$brush = [System.Drawing.Brushes]::Black
$panelW = [int]($w / 2) - 15
function MapX([double]$xv, [double]$mnx, [double]$mxx, [int]$left, [int]$ww) {
    return $left + ($xv - $mnx) / [Math]::Max($mxx - $mnx, 1e-12) * ($ww - 80)
}
function MapY([double]$yv, [double]$mny, [double]$mxy, [int]$top, [int]$hh) {
    return $top + $hh - 40 - ($yv - $mny) / [Math]::Max($mxy - $mny, 1e-12) * ($hh - 70)
}
for ($side = 0; $side -lt 2; $side++) {
    $x0 = 10 + $side * ([int]($w / 2))
    if ($side -eq 0) { $xa = $k1; $ya = $k2; $t1 = '(a) Trajectory'; $xl = 'kappa1'; $yl = 'kappa2' }
    else { $xa = $sc1; $ya = $sc2; $t1 = '(b) PCA'; $xl = 'PC1'; $yl = 'PC2' }
    $minx = ($xa | Measure-Object -Minimum).Minimum; $maxx = ($xa | Measure-Object -Maximum).Maximum
    $miny = ($ya | Measure-Object -Minimum).Minimum; $maxy = ($ya | Measure-Object -Maximum).Maximum
    $g.DrawRectangle([System.Drawing.Pens]::LightGray, $x0, 10, $panelW, $h - 30)
    $g.DrawString($t1, (New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)), $brush, [float]$x0, [float]15)
    for ($i = 0; $i -lt $n; $i++) {
        $cx = MapX $xa[$i] $minx $maxx $x0 $panelW
        $cy = MapY $ya[$i] $miny $maxy 10 ($h - 40)
        $col = if ($TempsK[$i] -le 12) { [System.Drawing.Color]::FromArgb(50, 115, 200) }
        elseif ($TempsK[$i] -le 20) { [System.Drawing.Color]::FromArgb(50, 165, 90) }
        else { [System.Drawing.Color]::FromArgb(215, 90, 50) }
        $br = New-Object System.Drawing.SolidBrush($col)
        $g.FillEllipse($br, [float]($cx - 4), [float]($cy - 4), 8, 8)
        $g.DrawString("$([int]$TempsK[$i])K", $font, $brush, [float]($cx + 5), [float]($cy - 6))
    }
    for ($i = 1; $i -lt $n; $i++) {
        $x1 = MapX $xa[$i - 1] $minx $maxx $x0 $panelW
        $y1 = MapY $ya[$i - 1] $miny $maxy 10 ($h - 40)
        $x2 = MapX $xa[$i] $minx $maxx $x0 $panelW
        $y2 = MapY $ya[$i] $miny $maxy 10 ($h - 40)
        $g.DrawLine([System.Drawing.Pens]::Black, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
    }
}
$figDir = Join-Path $repoRoot 'figures'
if (-not (Test-Path $figDir)) { New-Item -ItemType Directory -Path $figDir | Out-Null }
$pngPath = Join-Path $figDir 'kappa1_kappa2_trajectory.png'
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$tblDir = Join-Path $repoRoot 'tables'
$repDir = Join-Path $repoRoot 'reports'
if (-not (Test-Path $tblDir)) { New-Item -ItemType Directory -Path $tblDir | Out-Null }
if (-not (Test-Path $repDir)) { New-Item -ItemType Directory -Path $repDir | Out-Null }

$metricRows = @(
    [PSCustomObject]@{ metric = 'n_points'; value = $n }
    [PSCustomObject]@{ metric = 'corr_pearson_k1_k2'; value = $rho }
    [PSCustomObject]@{ metric = 'pca_pc1_fraction'; value = $pc1Frac }
    [PSCustomObject]@{ metric = 'pca_pc2_fraction'; value = $pc2Frac }
    [PSCustomObject]@{ metric = 'kendall_tau_T_k1'; value = $tau1 }
    [PSCustomObject]@{ metric = 'kendall_tau_T_k2'; value = $tau2 }
    [PSCustomObject]@{ metric = 'mono_diff_sign_changes_k1'; value = $mono1 }
    [PSCustomObject]@{ metric = 'mono_diff_sign_changes_k2'; value = $mono2 }
    [PSCustomObject]@{ metric = 'centroid_sep_low_vs_transition'; value = $d12 }
    [PSCustomObject]@{ metric = 'centroid_sep_transition_vs_high'; value = $d23 }
    [PSCustomObject]@{ metric = 'centroid_sep_low_vs_high'; value = $d13 }
    [PSCustomObject]@{ metric = 'bend_angle_deg_20_22_24'; value = $curv }
    [PSCustomObject]@{ metric = 'path_speed_ratio_22_24_over_20_22'; value = $speedRatio }
    [PSCustomObject]@{ metric = 'segment_norm_22_24'; value = $seg2224 }
    [PSCustomObject]@{ metric = 'jump_norm_20_22'; value = $jump2022 }
    [PSCustomObject]@{ metric = 'r2_linear_k2_on_k1'; value = $r2Lin }
    [PSCustomObject]@{ metric = 'rmse_linear'; value = $rmseLin }
    [PSCustomObject]@{ metric = 'best_poly_degree_k2_on_k1'; value = $bestDeg }
    [PSCustomObject]@{ metric = 'r2_best_poly_k2_on_k1'; value = $bestR2 }
    [PSCustomObject]@{ metric = 'rmse_best_poly'; value = $bestRmse }
    [PSCustomObject]@{ metric = 'relative_residual_variance_k2'; value = $relVarResid }
    [PSCustomObject]@{ metric = 'verdict_COLLECTIVE_STATE_2D'; value = $vCol }
    [PSCustomObject]@{ metric = 'verdict_REGIME_IS_STATE_REORGANIZATION'; value = $vReg }
    [PSCustomObject]@{ metric = 'verdict_DIMENSION_REDUCTION_POSSIBLE'; value = $vDim }
)
$metricRows | Export-Csv (Join-Path $tblDir 'collective_state_metrics.csv') -NoTypeInformation

$relData = 'results/switching/runs/run_2026_03_25_043610_kappa_phi_temperature_structure_test/tables/residual_rank_structure_vs_T.csv'
$bendLine = "- Bend near 22-24 K: angle between segments (20-22) and (22-24) in (kappa1,kappa2) = **$([Math]::Round($curv,2)) deg**."
$mdLines = @(
    '# Effective collective state test (Agent 19C)'
    ''
    '## Data'
    "- Source: ``$relData``"
    '- Subset: ``T_le_30`` (T = 4..30 K, 2 K steps, includes 22 K).'
    '- Definitions: ``kappa1`` = ``kappa`` (rank-1 weight); ``kappa2`` = ``rel_orth_leftover_norm`` (mode-2 proxy).'
    ''
    '## 1. Embedding'
    '- Trajectory plot: ``figures/kappa1_kappa2_trajectory.png`` (left: physical plane; right: PCA-style rotation of z-scored coordinates).'
    "- PCA: PC1 explains **$([Math]::Round(100 * $pc1Frac, 1))%**, PC2 **$([Math]::Round(100 * $pc2Frac, 1))%** of variance in standardized (kappa1, kappa2)."
    ''
    '## 2. Geometry along T'
    "- Kendall tau(T, kappa1) = **$([Math]::Round($tau1, 3))**; tau(T, kappa2) = **$([Math]::Round($tau2, 3))**."
    "- Sign changes in successive first differences: kappa1 **$mono1**, kappa2 **$mono2** (non-monotone if >0)."
    "- Regime centroids (low / transition / high): separation norms **$([Math]::Round($d12,3))**, **$([Math]::Round($d23,3))**, **$([Math]::Round($d13,3))**."
    $bendLine
    "- Path speed ||d(k1,k2)/dT|| ratio (22-24)/(20-22) = **$([Math]::Round($speedRatio, 3))**."
    ''
    '## 3. Reduced parameterization kappa2 ~ f(kappa1)'
    "- Pearson corr(kappa1, kappa2) = **$([Math]::Round($rho, 3))**."
    "- Linear R^2 = **$([Math]::Round($r2Lin, 3))** (RMSE **$([Math]::Round($rmseLin, 4))**)."
    "- Best polynomial degree **$bestDeg**: R^2 = **$([Math]::Round($bestR2, 3))**, RMSE **$([Math]::Round($bestRmse, 4))**, mean squared residual / var(kappa2) = **$([Math]::Round($relVarResid, 3))**."
    ''
    '## 4. Regime structure in (kappa1, kappa2)'
    '- Colours: blue = 4-12 K, green = 14-20 K, red = 22-30 K.'
    '- High-T band shows a large excursion at 22 K (mode-2 proxy spike) then partial relaxation by 24-30 K.'
    ''
    '## Verdict criteria (operational)'
    "- **COLLECTIVE_STATE_2D = YES** if PC1 < $([Math]::Round(100 * $pc1Thr))% of variance *or* best poly R^2 < $r2Thr (single scalar along the curve does not capture both)."
    "- **DIMENSION_REDUCTION_POSSIBLE = YES** if best poly R^2 >= $r2Thr *and* relative residual variance <= 0.15."
    "- **REGIME_IS_STATE_REORGANIZATION = YES** if bend angle > $curvThr deg, speed ratio > $speedThr, or strong centroid separation across 22-30 K band."
    ''
    '## Final verdict'
    "- **COLLECTIVE_STATE_2D**: **$vCol**"
    "- **REGIME_IS_STATE_REORGANIZATION**: **$vReg**"
    "- **DIMENSION_REDUCTION_POSSIBLE**: **$vDim**"
)
$md = $mdLines -join [Environment]::NewLine
Set-Content -Path (Join-Path $repDir 'collective_state_report.md') -Value $md -Encoding utf8

Write-Output "Wrote tables/collective_state_metrics.csv, figures/kappa1_kappa2_trajectory.png, reports/collective_state_report.md"
