# Agent 22D fallback: build trajectory table,figure,and report (no MATLAB / no Python on PATH).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$structPath = Join-Path $repoRoot 'tables\alpha_structure.csv'
$decPath = Join-Path $repoRoot 'tables\alpha_decomposition.csv'
$outCsv = Join-Path $repoRoot 'tables\alpha_res_vs_trajectory.csv'
$outPng = Join-Path $repoRoot 'figures\alpha_res_vs_delta_theta.png'
$outMd = Join-Path $repoRoot 'reports\alpha_res_trajectory_report.md'

foreach ($d in @('tables','figures','reports')) {
    $p = Join-Path $repoRoot $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

function Get-Double($x) {
    if ($null -eq $x -or $x -eq '' -or $x -eq 'NaN') { return [double]::NaN }
    return [double]$x
}

function New-Ones([int]$n) {
    $o = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $o[$i] = 1.0 }
    return ,$o
}

function Unwrap-Rad([double[]]$a) {
    $n = $a.Length
    $u = New-Object double[] $n
    $u[0] = $a[0]
    $twopi = 2.0 * [math]::PI
    for ($i = 1; $i -lt $n; $i++) {
        $d = $a[$i] - $u[$i - 1]
        $d = $d - $twopi * [math]::Round($d / $twopi)
        $u[$i] = $u[$i - 1] + $d
    }
    return ,$u
}

function MovMean-Shrink([double[]]$x,[int]$w) {
    $n = $x.Length
    $o = New-Object double[] $n
    $hw = [math]::Floor($w / 2)
    for ($i = 0; $i -lt $n; $i++) {
        $lo = [math]::Max(0,$i - $hw)
        $hi = [math]::Min($n - 1,$i + $hw)
        $s = 0.0; $c = 0
        for ($j = $lo; $j -le $hi; $j++) { $s += $x[$j]; $c++ }
        $o[$i] = $s / $c
    }
    return ,$o
}

function Mat-Get([double[,]]$M,[int]$r,[int]$c) { return [double]$M.GetValue($r,$c) }
function Mat-Set([double[,]]$M,[int]$r,[int]$c,[double]$v) { $M.SetValue($v,$r,$c) }

function Invert-Matrix([double[,]]$A) {
    $n = $A.GetLength(0)
    $M = New-Object 'double[,]' $n,(2 * $n)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { Mat-Set $M $i $j (Mat-Get $A $i $j) }
        Mat-Set $M $i ($n + $i) 1.0
    }
    for ($pivCol = 0; $pivCol -lt $n; $pivCol++) {
        $piv = $pivCol
        $maxv = [math]::Abs((Mat-Get $M $pivCol $pivCol))
        for ($r = $pivCol + 1; $r -lt $n; $r++) {
            $v = [math]::Abs((Mat-Get $M $r $pivCol))
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        if ($maxv -lt 1e-14) { throw 'singular' }
        if ($piv -ne $pivCol) {
            for ($c = 0; $c -lt 2 * $n; $c++) {
                $tmp = Mat-Get $M $pivCol $c
                Mat-Set $M $pivCol $c (Mat-Get $M $piv $c)
                Mat-Set $M $piv $c $tmp
            }
        }
        $pv = Mat-Get $M $pivCol $pivCol
        for ($c = 0; $c -lt 2 * $n; $c++) { Mat-Set $M $pivCol $c ((Mat-Get $M $pivCol $c) / $pv) }
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -ne $pivCol) {
                $f = Mat-Get $M $r $pivCol
                for ($c = 0; $c -lt 2 * $n; $c++) {
                    Mat-Set $M $r $c ((Mat-Get $M $r $c) - $f * (Mat-Get $M $pivCol $c))
                }
            }
        }
    }
    $Inv = New-Object 'double[,]' $n,$n
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { Mat-Set $Inv $i $j (Mat-Get $M $i ($n + $j)) }
    }
    return ,$Inv
}

function Ols-LoocvReport([string]$name,[double[]]$y,[object[]]$Xcols) {
    $n = $y.Length
    $pc = $Xcols.Length
    if ($n -lt $pc) {
        return [pscustomobject]@{ model = $name; n = $n; loocv_rmse = [double]::NaN; pearson_y_yhat = [double]::NaN; spearman_y_yhat = [double]::NaN; max_leverage = [double]::NaN }
    }
    $X = New-Object 'double[,]' $n,$pc
    for ($c = 0; $c -lt $pc; $c++) {
        for ($r = 0; $r -lt $n; $r++) { Mat-Set $X $r $c $Xcols[$c][$r] }
    }
    $XtX = New-Object 'double[,]' $pc,$pc
    for ($i = 0; $i -lt $pc; $i++) {
        for ($j = 0; $j -lt $pc; $j++) {
            $s = 0.0
            for ($r = 0; $r -lt $n; $r++) { $s += (Mat-Get $X $r $i) * (Mat-Get $X $r $j) }
            Mat-Set $XtX $i $j $s
        }
    }
    $Xty = New-Object double[] $pc
    for ($i = 0; $i -lt $pc; $i++) {
        $s = 0.0
        for ($r = 0; $r -lt $n; $r++) { $s += (Mat-Get $X $r $i) * $y[$r] }
        $Xty[$i] = $s
    }
    try {
        $Xi = Invert-Matrix $XtX
    } catch {
        return [pscustomobject]@{ model = $name; n = $n; loocv_rmse = [double]::NaN; pearson_y_yhat = [double]::NaN; spearman_y_yhat = [double]::NaN; max_leverage = [double]::NaN }
    }
    $beta = New-Object double[] $pc
    for ($i = 0; $i -lt $pc; $i++) {
        $s = 0.0
        for ($j = 0; $j -lt $pc; $j++) { $s += (Mat-Get $Xi $i $j) * $Xty[$j] }
        $beta[$i] = $s
    }
    $yhat = New-Object double[] $n
    for ($r = 0; $r -lt $n; $r++) {
        $s = 0.0
        for ($c = 0; $c -lt $pc; $c++) { $s += (Mat-Get $X $r $c) * $beta[$c] }
        $yhat[$r] = $s
    }
    $e = New-Object double[] $n
    for ($r = 0; $r -lt $n; $r++) { $e[$r] = $y[$r] - $yhat[$r] }
    $Hat = New-Object 'double[,]' $n,$n
    for ($rr = 0; $rr -lt $n; $rr++) {
        for ($ss = 0; $ss -lt $n; $ss++) {
            $v = 0.0
            for ($i = 0; $i -lt $pc; $i++) {
                for ($j = 0; $j -lt $pc; $j++) {
                    $v += (Mat-Get $X $rr $i) * (Mat-Get $Xi $i $j) * (Mat-Get $X $ss $j)
                }
            }
            Mat-Set $Hat $rr $ss $v
        }
    }
    $sse = 0.0
    $maxh = 0.0
    for ($rr = 0; $rr -lt $n; $rr++) {
        $h = Mat-Get $Hat $rr $rr
        if ($h -gt $maxh) { $maxh = $h }
        $loo = $e[$rr] / [math]::Max(1.0 - $h,1e-12)
        $sse += $loo * $loo
    }
    $rmse = [math]::Sqrt($sse / $n)
    $pear = Pearson $y $yhat
    $spear = Spearman $y $yhat
    return [pscustomobject]@{ model = $name; n = $n; loocv_rmse = $rmse; pearson_y_yhat = $pear; spearman_y_yhat = $spear; max_leverage = $maxh }
}

function Pearson([double[]]$a,[double[]]$b) {
    $n = $a.Length
    $ma = 0.0; $mb = 0.0
    for ($i = 0; $i -lt $n; $i++) { $ma += $a[$i]; $mb += $b[$i] }
    $ma /= $n; $mb /= $n
    $sab = 0.0; $saa = 0.0; $sbb = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $da = $a[$i] - $ma; $db = $b[$i] - $mb
        $sab += $da * $db; $saa += $da * $da; $sbb += $db * $db
    }
    if ($saa -lt 1e-30 -or $sbb -lt 1e-30) { return [double]::NaN }
    return $sab / [math]::Sqrt($saa * $sbb)
}

function Spearman([double[]]$a,[double[]]$b) {
    $n = $a.Length
    $idxA = 0..($n - 1) | Sort-Object { $a[$_] }
    $idxB = 0..($n - 1) | Sort-Object { $b[$_] }
    $ra = New-Object double[] $n
    $rb = New-Object double[] $n
    for ($k = 0; $k -lt $n; $k++) {
        $ra[$idxA[$k]] = $k + 1
        $rb[$idxB[$k]] = $k + 1
    }
    return (Pearson $ra $rb)
}

function Loocv-NaiveMean([double[]]$y) {
    $n = $y.Length
    if ($n -lt 2) { return [double]::NaN }
    $err = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $s = 0.0; $c = 0
        for ($j = 0; $j -lt $n; $j++) {
            if ($j -ne $i) { $s += $y[$j]; $c++ }
        }
        $mu = $s / $c
        $d = $y[$i] - $mu
        $err += $d * $d
    }
    return [math]::Sqrt($err / $n)
}

# --- Load and merge
$S = Import-Csv $structPath
$D = Import-Csv $decPath
$decByT = @{}
foreach ($r in $D) { $decByT[$r.T_K] = $r }
$rows = New-Object System.Collections.Generic.List[object]
foreach ($r in $S) {
    if (-not $decByT.ContainsKey($r.T_K)) { continue }
    $dr = $decByT[$r.T_K]
    $ar = Get-Double $dr.alpha_res
    if ([double]::IsNaN($ar)) { continue }
    [void]$rows.Add([pscustomobject]@{
            T_K       = [double]$r.T_K
            kappa1    = Get-Double $r.kappa1
            kappa2    = Get-Double $r.kappa2
            alpha_res = $ar
        })
}
$rows = $rows | Sort-Object T_K
$n = $rows.Count
if ($n -lt 4) { throw "Too few rows for trajectory analysis." }

$T = New-Object double[] $n
$k1 = New-Object double[] $n
$k2 = New-Object double[] $n
$ares = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    $T[$i] = $rows[$i].T_K
    $k1[$i] = $rows[$i].kappa1
    $k2[$i] = $rows[$i].kappa2
    $ares[$i] = $rows[$i].alpha_res
}

$theta = New-Object double[] $n
$rr = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    $theta[$i] = [math]::Atan2($k2[$i],$k1[$i])
    $rr[$i] = [math]::Sqrt($k1[$i] * $k1[$i] + $k2[$i] * $k2[$i])
}
$thu = Unwrap-Rad $theta

$dtheta = New-Object double[] $n
$dk1 = New-Object double[] $n
$dk2 = New-Object double[] $n
$dT = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    if ($i -eq 0) {
        $dtheta[$i] = [double]::NaN; $dk1[$i] = [double]::NaN; $dk2[$i] = [double]::NaN; $dT[$i] = [double]::NaN
    }
    else {
        $dtheta[$i] = $thu[$i] - $thu[$i - 1]
        $dk1[$i] = $k1[$i] - $k1[$i - 1]
        $dk2[$i] = $k2[$i] - $k2[$i - 1]
        $dT[$i] = $T[$i] - $T[$i - 1]
    }
}

$ds = New-Object double[] $n
$kcurve = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    if ($i -eq 0) { $ds[$i] = [double]::NaN; $kcurve[$i] = [double]::NaN }
    else {
        $ds[$i] = [math]::Sqrt($dk1[$i] * $dk1[$i] + $dk2[$i] * $dk2[$i])
        $kcurve[$i] = [math]::Abs($dtheta[$i]) / [math]::Max($dT[$i],[double]::Epsilon)
    }
}

$wl = [math]::Min(9,[math]::Max(3,2 * [math]::Floor($n / 2) - 1))
if ($wl % 2 -eq 0) { $wl-- }
$ths = MovMean-Shrink $thu $wl

$dthsm = New-Object double[] $n
for ($i = 0; $i -lt $n; $i++) {
    if ($i -eq 0) { $dthsm[$i] = [double]::NaN }
    else { $dthsm[$i] = $ths[$i] - $ths[$i - 1] }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('T_K,kappa1,kappa2,alpha_res,theta_rad,r,theta_unwrapped_rad,delta_theta_rad,theta_smoothed_unwrapped_rad,delta_theta_smoothed_rad,kappa_curve,ds_step,delta_T_K')
for ($i = 0; $i -lt $n; $i++) {
    [void]$sb.AppendLine(('{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12}' -f @(
                $T[$i],$k1[$i],$k2[$i],$ares[$i],$theta[$i],$rr[$i],$thu[$i],
                $dtheta[$i],$ths[$i],$dthsm[$i],$kcurve[$i],$ds[$i],$dT[$i])))
}
[System.IO.File]::WriteAllText($outCsv,$sb.ToString(),[System.Text.UTF8Encoding]::new($false))

function Subset-Ols([string]$name,[double[]]$aresAll,[int[]]$idx,[object[]]$PredCols) {
    $m = $idx.Count
    $y = New-Object double[] $m
    for ($k = 0; $k -lt $m; $k++) { $y[$k] = $aresAll[$idx[$k]] }
    $Xb = New-Object System.Collections.ArrayList
    [void]$Xb.Add((New-Ones $m))
    foreach ($pc in $PredCols) {
        $pfull = [double[]]$pc
        $col = New-Object double[] $m
        for ($k = 0; $k -lt $m; $k++) { $col[$k] = $pfull[$idx[$k]] }
        [void]$Xb.Add($col)
    }
    return Ols-LoocvReport $name $y @($Xb.ToArray())
}

$idxD = [System.Collections.Generic.List[int]]::new()
for ($i = 0; $i -lt $n; $i++) { if (-not [double]::IsNaN($dtheta[$i])) { [void]$idxD.Add($i) } }
$idxSm = [System.Collections.Generic.List[int]]::new()
for ($i = 0; $i -lt $n; $i++) { if (-not [double]::IsNaN($dthsm[$i])) { [void]$idxSm.Add($i) } }
$idxK = [System.Collections.Generic.List[int]]::new()
for ($i = 0; $i -lt $n; $i++) { if (-not [double]::IsNaN($kcurve[$i])) { [void]$idxK.Add($i) } }
$idxDs = [System.Collections.Generic.List[int]]::new()
for ($i = 0; $i -lt $n; $i++) { if (-not [double]::IsNaN($ds[$i])) { [void]$idxDs.Add($i) } }
$idxBoth = [System.Collections.Generic.List[int]]::new()
for ($i = 0; $i -lt $n; $i++) {
    if (-not [double]::IsNaN($dtheta[$i]) -and -not [double]::IsNaN($ds[$i])) { [void]$idxBoth.Add($i) }
}

$traj = @()
$traj += Subset-Ols 'alpha_res ~ delta_theta_rad' $ares $idxD.ToArray() (,$dtheta)
$traj += Subset-Ols 'alpha_res ~ delta_theta_smoothed_rad' $ares $idxSm.ToArray() (,$dthsm)
$traj += Subset-Ols 'alpha_res ~ kappa_curve' $ares $idxK.ToArray() (,$kcurve)
$traj += Subset-Ols 'alpha_res ~ ds_step' $ares $idxDs.ToArray() (,$ds)
$traj += Subset-Ols 'alpha_res ~ delta_theta_rad + ds_step' $ares $idxBoth.ToArray() @($dtheta,$ds)

$state = @()
$state += Ols-LoocvReport 'alpha_res ~ kappa1' $ares @((New-Ones $n),$k1)
$state += Ols-LoocvReport 'alpha_res ~ kappa2' $ares @((New-Ones $n),$k2)
$state += Ols-LoocvReport 'alpha_res ~ theta_rad' $ares @((New-Ones $n),$theta)
$state += Ols-LoocvReport 'alpha_res ~ r' $ares @((New-Ones $n),$rr)
$state += Ols-LoocvReport 'alpha_res ~ theta_rad + r' $ares @((New-Ones $n),$theta,$rr)

$loocvNaive = Loocv-NaiveMean $ares
$ma = 0.0
for ($i = 0; $i -lt $n; $i++) { $ma += $ares[$i] }
$ma /= $n
$sigY = 0.0
for ($i = 0; $i -lt $n; $i++) { $sigY += ($ares[$i] - $ma) * ($ares[$i] - $ma) }
$sigY = [math]::Sqrt($sigY / [math]::Max(1,$n - 1))

$bestT = $traj | Where-Object { $null -ne $_ -and -not [double]::IsNaN($_.loocv_rmse) } | Sort-Object loocv_rmse | Select-Object -First 1
$bestS = $state | Where-Object { $null -ne $_ -and -not [double]::IsNaN($_.loocv_rmse) } | Sort-Object loocv_rmse | Select-Object -First 1
$bestUni = $traj[0..3] | Where-Object { $null -ne $_ -and -not [double]::IsNaN($_.loocv_rmse) } | Sort-Object loocv_rmse | Select-Object -First 1
$featNames = @{
    'alpha_res ~ delta_theta_rad'            = 'delta_theta_rad'
    'alpha_res ~ delta_theta_smoothed_rad'   = 'delta_theta_smoothed_rad'
    'alpha_res ~ kappa_curve'                = 'kappa_curve'
    'alpha_res ~ ds_step'                    = 'ds_step'
}
$bestFeat = $featNames[$bestUni.model]
if (-not $bestFeat) { $bestFeat = 'none' }

$trajectoryBeats = ($bestT.loocv_rmse -lt $bestS.loocv_rmse - 1e-12)
$pred = ($bestT.loocv_rmse -lt $loocvNaive) -and (
    (([math]::Abs($bestT.pearson_y_yhat) -ge 0.35 -and [math]::Abs($bestT.spearman_y_yhat) -ge 0.3) -or ([math]::Abs($bestT.pearson_y_yhat) -ge 0.45))
)
$flagDep = if ($pred) { 'YES' } else { 'NO' }
$flagBeats = if ($trajectoryBeats) { 'YES' } else { 'NO' }

Add-Type -AssemblyName System.Drawing
function Get-TColor([double]$t,[double]$t0,[double]$t1) {
    $u = [math]::Max(0,[math]::Min(1,($t - $t0) / [math]::Max($t1 - $t0,1e-9)))
    $r = [byte](255 * $u)
    $b = [byte](255 * (1 - $u))
    $g = [byte](100 + 100 * (1 - [math]::Abs($u - 0.5) * 2))
    return [Drawing.Color]::FromArgb(255,$r,$g,$b)
}

$bmp = New-Object Drawing.Bitmap 800,600
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([Drawing.Color]::White)
$pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(180,180,180),[float]1.5)
$font = New-Object Drawing.Font('Arial',11)
$brush = [Drawing.Brushes]::Black

$xs = [System.Collections.Generic.List[double]]::new()
$ys = [System.Collections.Generic.List[double]]::new()
$tc = [System.Collections.Generic.List[double]]::new()
for ($i = 0; $i -lt $n; $i++) {
    if (-not [double]::IsNaN($dtheta[$i])) {
        [void]$xs.Add($dtheta[$i])
        [void]$ys.Add($ares[$i])
        [void]$tc.Add($T[$i])
    }
}
$minX = ($xs | Measure-Object -Minimum).Minimum; $maxX = ($xs | Measure-Object -Maximum).Maximum
$minY = ($ys | Measure-Object -Minimum).Minimum; $maxY = ($ys | Measure-Object -Maximum).Maximum
$padX = 0.1 * [math]::Max([math]::Abs($maxX - $minX),1e-9)
$padY = 0.1 * [math]::Max([math]::Abs($maxY - $minY),1e-9)
$minX -= $padX; $maxX += $padX; $minY -= $padY; $maxY += $padY

$mx = 80; $my = 50; $mw = 800 - 160; $mh = 600 - 100
$tmin = ($tc | Measure-Object -Minimum).Minimum; $tmax = ($tc | Measure-Object -Maximum).Maximum
for ($k = 0; $k -lt $xs.Count; $k++) {
    $col = Get-TColor $tc[$k] $tmin $tmax
    $br = New-Object Drawing.SolidBrush $col
    $px = $mx + ($xs[$k] - $minX) / ($maxX - $minX) * $mw
    $py = $my + $mh - ($ys[$k] - $minY) / ($maxY - $minY) * $mh
    $g.FillEllipse($br,[float]($px - 4),[float]($py - 4),[float]8,[float]8)
}
for ($k = 0; $k -lt ($xs.Count - 1); $k++) {
    $px0 = $mx + ($xs[$k] - $minX) / ($maxX - $minX) * $mw
    $py0 = $my + $mh - ($ys[$k] - $minY) / ($maxY - $minY) * $mh
    $px1 = $mx + ($xs[$k + 1] - $minX) / ($maxX - $minX) * $mw
    $py1 = $my + $mh - ($ys[$k + 1] - $minY) / ($maxY - $minY) * $mh
    $g.DrawLine($pen,[float]$px0,[float]$py0,[float]$px1,[float]$py1)
}
$g.DrawString('Delta theta (rad)',$font,$brush,300,560)
$g.DrawString([char]0x03B1 + 'res',$font,$brush,20,280)
$bmp.Save($outPng,[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

$lines = @"
# Alpha residual vs kappa trajectory (Agent 22D)

**Note:** Built by ``tools/build_alpha_res_trajectory_outputs.ps1`` (fallback when MATLAB/Python are unavailable). Smoothing: centered moving average (window $wl).

## Inputs
"@
$lines += "`n- ``$($structPath.Replace('\','/'))``"
$lines += "`n- ``$($decPath.Replace('\','/'))``"
$lines += "`n`n## Univariate correlations (trajectory features)"
$feat = @('delta_theta_rad','delta_theta_smoothed_rad','kappa_curve','ds_step')
$featv = @($dtheta,$dthsm,$kcurve,$ds)
for ($u = 0; $u -lt 4; $u++) {
    $xv = $featv[$u]
    $m = 0..($n - 1) | Where-Object { -not [double]::IsNaN($xv[$_]) -and -not [double]::IsNaN($ares[$_]) }
    if ($m.Count -ge 3) {
        $xa = New-Object double[] $m.Count
        $ya = New-Object double[] $m.Count
        for ($q = 0; $q -lt $m.Count; $q++) {
            $xa[$q] = $xv[$m[$q]]
            $ya[$q] = $ares[$m[$q]]
        }
        $rp = Pearson $xa $ya
        $rs = Spearman $xa $ya
        $lines += "`n- ``$($feat[$u])``: Pearson $rp,Spearman $rs"
    }
}
$lines += "`n`n## Trajectory models (OLS + LOOCV)"
$lines += "`n`nTrajectory fits use rows with finite trajectory features (typically n = $($n - 1) when the first T has no forward difference). State models use all n = $n temperatures."
foreach ($r in $traj) { $lines += "`n- $($r.model): n=$($r.n) LOOCV=$($r.loocv_rmse) Pearson=$($r.pearson_y_yhat) Spearman=$($r.spearman_y_yhat)" }
$lines += "`n`n## State baseline models"
foreach ($r in $state) { $lines += "`n- $($r.model): n=$($r.n) LOOCV=$($r.loocv_rmse)" }
$lines += "`n`n## Final flags"
$lines += "`n- **ALPHA_RES_DEPENDS_ON_TRAJECTORY** = **$flagDep**"
$lines += "`n- **BEST_TRAJECTORY_FEATURE** = **$bestFeat**"
$lines += "`n- **TRAJECTORY_BEATS_STATE** = **$flagBeats**"
$lines += "`n- Best trajectory model: $($bestT.model) (LOOCV $($bestT.loocv_rmse))"
$lines += "`n- Best state model: $($bestS.model) (LOOCV $($bestS.loocv_rmse))"
$lines += "`n- LOOCV naive mean: $loocvNaive; std(alpha_res): $sigY"
$lines += "`n`n*Auto-generated by tools/build_alpha_res_trajectory_outputs.ps1*"
[System.IO.File]::WriteAllText($outMd,$lines,[System.Text.UTF8Encoding]::new($false))

Write-Host "Wrote $outCsv"
Write-Host "Wrote $outPng"
Write-Host "Wrote $outMd"
Write-Host "ALPHA_RES_DEPENDS_ON_TRAJECTORY = $flagDep"
Write-Host "BEST_TRAJECTORY_FEATURE = $bestFeat"
Write-Host "TRAJECTORY_BEATS_STATE = $flagBeats"
