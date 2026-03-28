# Agent 20B: alpha = kappa2/kappa1 vs PT geometry (numeric; mirrors analysis/run_alpha_from_pt_agent20b.m)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent

$alphaPath = Join-Path $repo 'tables\alpha_structure.csv'
$ptMatrixPath = Join-Path $repo 'results\switching\runs\run_2026_03_25_013356_pt_robust_canonical\tables\PT_matrix.csv'
$ptSummaryPath = Join-Path $repo 'results\switching\runs\run_2026_03_25_013356_pt_robust_canonical\tables\PT_summary.csv'
$outCsv = Join-Path $repo 'tables\alpha_from_PT.csv'
$outRep = Join-Path $repo 'reports\alpha_from_PT_report.md'
$cult = [Globalization.CultureInfo]::InvariantCulture

function Q-Disc($I, $pn, [double]$u) {
    $I = [double[]]@($I)
    $pn = [double[]]@($pn)
    $c = New-Object 'double[]' $pn.Length
    $s = 0.0
    for ($k = 0; $k -lt $pn.Length; $k++) { $s += $pn[$k]; $c[$k] = $s }
    if ($u -le $c[0]) { return [double]$I[0] }
    if ($u -ge $c[-1]) { return [double]$I[-1] }
    $idx = 0
    for ($k = 0; $k -lt $c.Length; $k++) { if ($c[$k] -ge $u) { $idx = $k; break } }
    if ($idx -le 0) { return [double]$I[0] }
    $c0 = $c[$idx - 1]; $c1 = $c[$idx]
    if ($c1 -le $c0) { return [double]$I[$idx] }
    $t = ($u - $c0) / ($c1 - $c0)
    return [double]$I[$idx - 1] + $t * ([double]$I[$idx] - [double]$I[$idx - 1])
}

function Get-PTObs($I, $pRaw) {
    $I = [double[]]@($I)
    $pRaw = [double[]]@($pRaw)
    $sum = 0.0; foreach ($v in $pRaw) { $sum += $v }
    if ($sum -le 0) { return $null }
    $pn = New-Object double[] $pRaw.Length
    for ($i = 0; $i -lt $pRaw.Length; $i++) { $pn[$i] = $pRaw[$i] / $sum }
    $mu = 0.0; for ($i = 0; $i -lt $I.Length; $i++) { $mu += $pn[$i] * $I[$i] }
    $q25 = Q-Disc $I $pn 0.25
    $q50 = Q-Disc $I $pn 0.50
    $q75 = Q-Disc $I $pn 0.75
    $q90 = Q-Disc $I $pn 0.90
    $v2 = 0.0; $v3 = 0.0
    for ($i = 0; $i -lt $I.Length; $i++) {
        $d = $I[$i] - $mu
        $v2 += $pn[$i] * $d * $d
        $v3 += $pn[$i] * $d * $d * $d
    }
    $v2 = [math]::Max($v2, 0)
    if ($v2 -le 0) {
        $sk = [double]::NaN
    } else {
        $sk = $v3 / [math]::Pow($v2, 1.5)
    }
    $imx = 0; $pm = [double]$pn[0]
    for ($i = 1; $i -lt $pn.Length; $i++) { if ([double]$pn[$i] -gt $pm) { $pm = [double]$pn[$i]; $imx = $i } }
    $s90_50 = $q90 - $q50
    $s75_25 = $q75 - $q25
    $asym = ($q90 - $q50) - ($q50 - $q25)
    return @( $s90_50, $s75_25, $asym, $sk, ($mu - $q50), [double]$I[$imx] )
}

function OLS([object[]]$Xrows, [double[]]$y) {
    $n = $y.Length; $p = $Xrows[0].Length
    $XtX = New-Object "double[,]" $p, $p
    $Xty = New-Object double[] $p
    for ($ii = 0; $ii -lt $n; $ii++) {
        for ($a = 0; $a -lt $p; $a++) {
            $Xty[$a] += $Xrows[$ii][$a] * $y[$ii]
            for ($b = 0; $b -lt $p; $b++) { $XtX[$a,$b] += $Xrows[$ii][$a] * $Xrows[$ii][$b] }
        }
    }
    if ($p -eq 2) {
        $a00 = [double]$XtX.GetValue(0,0); $a01 = [double]$XtX.GetValue(0,1)
        $a10 = [double]$XtX.GetValue(1,0); $a11 = [double]$XtX.GetValue(1,1)
        $det = $a00*$a11 - $a01*$a10
        if ([math]::Abs($det) -lt 1e-18) { return $null }
        $inv = New-Object 'double[,]' 2, 2
        $inv[0,0] = $a11 / $det; $inv[0,1] = -$a01 / $det
        $inv[1,0] = -$a10 / $det; $inv[1,1] = $a00 / $det
        $beta = New-Object double[] 2
        $beta[0] = $inv[0,0]*$Xty[0]+$inv[0,1]*$Xty[1]
        $beta[1] = $inv[1,0]*$Xty[0]+$inv[1,1]*$Xty[1]
        return @{ beta = $beta; inv = $inv; p = 2 }
    }
    $a=$XtX.GetValue(0,0); $b=$XtX.GetValue(0,1); $c=$XtX.GetValue(0,2)
    $d=$XtX.GetValue(1,0); $e=$XtX.GetValue(1,1); $f=$XtX.GetValue(1,2)
    $g=$XtX.GetValue(2,0); $h=$XtX.GetValue(2,1); $i=$XtX.GetValue(2,2)
    $det3 = $a*($e*$i-$f*$h) - $b*($d*$i-$f*$g) + $c*($d*$h-$e*$g)
    if ([math]::Abs($det3) -lt 1e-20) { return $null }
    $inv3 = New-Object 'double[,]' 3, 3
    $inv3[0,0]=($e*$i-$f*$h)/$det3; $inv3[0,1]=($c*$h-$b*$i)/$det3; $inv3[0,2]=($b*$f-$c*$e)/$det3
    $inv3[1,0]=($f*$g-$d*$i)/$det3; $inv3[1,1]=($a*$i-$c*$g)/$det3; $inv3[1,2]=($c*$d-$a*$f)/$det3
    $inv3[2,0]=($d*$h-$e*$g)/$det3; $inv3[2,1]=($b*$g-$a*$h)/$det3; $inv3[2,2]=($a*$e-$b*$d)/$det3
    $beta = New-Object double[] 3
    for ($r = 0; $r -lt 3; $r++) {
        $s = 0.0; for ($c = 0; $c -lt 3; $c++) { $s += [double]$inv3[$r,$c] * [double]$Xty[$c] }; $beta[$r] = $s
    }
    return @{ beta = $beta; inv = $inv3; p = 3 }
}

function Hii($xi, $sol) {
    if ($sol.p -eq 2) {
        $inv = $sol.inv
        return $xi[0]*($inv[0,0]*$xi[0]+$inv[0,1]*$xi[1]) + $xi[1]*($inv[1,0]*$xi[0]+$inv[1,1]*$xi[1])
    }
    $inv = $sol.inv; $t = 0.0
    for ($r = 0; $r -lt 3; $r++) {
        $s = 0.0; for ($c = 0; $c -lt 3; $c++) { $s += [double]$inv.GetValue($r,$c) * $xi[$c] }; $t += $xi[$r] * $s
    }
    return $t
}

function Loocv($Xrows, $y, $sol) {
    $n = $y.Length; $beta = $sol.beta; $p = $sol.p
    $se = 0.0
    for ($ii = 0; $ii -lt $n; $ii++) {
        $yh = 0.0; for ($j = 0; $j -lt $p; $j++) { $yh += $Xrows[$ii][$j] * $beta[$j] }
        $e = $y[$ii] - $yh
        $h = [math]::Min(0.9999999999, (Hii $Xrows[$ii] $sol))
        $loo = $e / (1.0 - $h)
        $se += $loo * $loo
    }
    return [math]::Sqrt($se / $n)
}

function Corr-P([double[]]$a, [double[]]$b) {
    $n = $a.Length; $ma = ($a | Measure-Object -Average).Average; $mb = ($b | Measure-Object -Average).Average
    $sab = 0.0; $saa = 0.0; $sbb = 0.0
    for ($i = 0; $i -lt $n; $i++) { $da = $a[$i]-$ma; $db = $b[$i]-$mb; $sab += $da*$db; $saa += $da*$da; $sbb += $db*$db }
    if ($saa -le 0 -or $sbb -le 0) { return [double]::NaN }
    return $sab / [math]::Sqrt($saa * $sbb)
}

function Rank([double[]]$x) {
    $n = $x.Length
    $idx = 0..($n-1) | Sort-Object { $x[$_] }
    $r = New-Object double[] $n
    for ($k = 0; $k -lt $n; $k++) { $r[$idx[$k]] = $k + 1 }
    return $r
}

function Corr-S([double[]]$a, [double[]]$b) { Corr-P (Rank $a) (Rank $b) }

# Load PT matrix
$ptCsv = Import-Csv $ptMatrixPath
$vn = $ptCsv[0].PSObject.Properties.Name
$ptCols = $vn | Where-Object { $_ -ne 'T_K' }
$Igrid = foreach ($c in $ptCols) {
    if ($c -match '^Ith_(.+)_mA$') {
        $raw = $Matches[1] -replace '_', '.'
        [double]::Parse($raw, $cult)
    }
}
$ord = 0..($Igrid.Length-1) | Sort-Object { $Igrid[$_] }
$Iarr = $ord | ForEach-Object { [double]$Igrid[$_] }
$ptByT = @{}
foreach ($row in $ptCsv) {
    $tk = [double]::Parse($row.T_K, $cult)
    $pr = foreach ($ix in $ord) {
        $nm = $ptCols[$ix]
        $v = $row.$nm
        if ($null -eq $v -or $v -eq '') { [double]::NaN } else { [double]::Parse($v, $cult) }
    }
    $ptByT[$tk] = @($pr)
}

$stdMap = @{}
Import-Csv $ptSummaryPath | ForEach-Object {
    $tk = [double]::Parse($_.T_K, $cult)
    if ($_.std_threshold_mA -and $_.std_threshold_mA -ne '') { $stdMap[$tk] = [double]::Parse($_.std_threshold_mA, $cult) }
}

# Per-T feature rows
$alphaCsv = Import-Csv $alphaPath
$N = $alphaCsv.Count
$feat = New-Object 'object[]' $N
for ($ri = 0; $ri -lt $N; $ri++) {
    $ar = $alphaCsv[$ri]
    $TK = [double]::Parse($ar.T_K, $cult)
    $s90 = [double]::NaN; $s75 = [double]::NaN; $asym = [double]::NaN; $sk = [double]::NaN; $mm = [double]::NaN; $ipk = [double]::NaN
    if ($ptByT.ContainsKey($TK)) {
        $pr = [double[]]($ptByT[$TK])
        $bad = $false; foreach ($v in $pr) { if ($v -ne $v) { $bad = $true } }
        if (-not $bad) {
            $sum = 0.0; foreach ($v in $pr) { $sum += $v }
            if ($sum -gt 0) {
                $o = @(Get-PTObs ([double[]]$Iarr) $pr)
                if ($o.Count -ge 6) {
                    $s90 = [double]$o[0]; $s75 = [double]$o[1]; $asym = [double]$o[2]; $sk = [double]$o[3]; $mm = [double]$o[4]; $ipk = [double]$o[5]
                }
            }
        }
    }
    $stdpt = if ($stdMap.ContainsKey($TK)) { $stdMap[$TK] } else { [double]::NaN }
    $feat[$ri] = [pscustomobject]@{
        T_K = $TK
        alpha = [double]::Parse($ar.alpha, $cult)
        spread90_50 = $s90; spread75_25 = $s75; asymmetry = $asym
        skew_pt_weighted = $sk; mean_minus_median_pt = $mm
        I_peak_mA = [double]::Parse($ar.I_peak_mA, $cult)
        width_mA = [double]::Parse($ar.width_mA, $cult)
        S_peak = [double]::Parse($ar.S_peak, $cult)
        I_peak_PT_mA = $ipk; std_threshold_mA_PT = $stdpt
    }
}

function Fit-Name($name, $ix, [scriptblock]$getX) {
    if ($null -eq $ix -or $ix.Count -lt 4) { return $null }
    $y = New-Object double[] $ix.Count
    $c = 0
    foreach ($ii in $ix) { $y[$c++] = $feat[$ii].alpha }
    [object[]]$Xrows = foreach ($ii in $ix) { , (& $getX $feat[$ii]) }
    $sol = OLS $Xrows $y
    if ($null -eq $sol) { return $null }
    $yh = 0..($ix.Length-1) | ForEach-Object {
        $r = $Xrows[$_]; $s = 0.0; for ($j = 0; $j -lt $r.Length; $j++) { $s += $r[$j] * $sol.beta[$j] }; $s
    }
    $loocv = Loocv $Xrows $y $sol
    $pear = Corr-P ($y -as [double[]]) ($yh -as [double[]])
    $spear = Corr-S ($y -as [double[]]) ($yh -as [double[]])
    $hmax = 0.0; for ($ii = 0; $ii -lt $ix.Length; $ii++) { $hmax = [math]::Max($hmax, (Hii $Xrows[$ii] $sol)) }
    $errs224 = @()
    foreach ($tHold in 22, 24) {
        $at = -1
        for ($k = 0; $k -lt $ix.Length; $k++) { if ([math]::Abs($feat[$ix[$k]].T_K - $tHold) -lt 0.51) { $at = $k; break } }
        if ($at -lt 0) { continue }
        $tr = @($ix | Where-Object { $_ -ne $ix[$at] })
        if ($tr.Count -lt ($Xrows[0].Length + 1)) { continue }
        $y2 = [double[]]($tr | ForEach-Object { $feat[$_].alpha })
        [object[]]$X2 = foreach ($ii in $tr) { , (& $getX $feat[$ii]) }
        $s2 = OLS $X2 $y2
        if ($null -eq $s2) { continue }
        $xi = $Xrows[$at]
        $yhat = 0.0; for ($j = 0; $j -lt $xi.Length; $j++) { $yhat += $xi[$j] * $s2.beta[$j] }
        $errs224 += , ($feat[$ix[$at]].alpha - $yhat)
    }
    $rm224 = if ($errs224.Count -gt 0) { [math]::Sqrt((($errs224 | ForEach-Object { $_ * $_ } | Measure-Object -Average).Average)) } else { [double]::NaN }
    [pscustomobject]@{ name = $name; idx = $ix; Xrows = $Xrows; y = $y; sol = $sol; yhat = $yh
        loocv = $loocv; pearson = $pear; spearman = $spear; maxlev = $hmax; rm224 = $rm224; getX = $getX }
}

function Pick-Idx([scriptblock]$pred) {
    $ix = @()
    for ($i = 0; $i -lt $N; $i++) { if (& $pred $feat[$i]) { $ix += $i } }
    return $ix
}

$ix1 = Pick-Idx { param($r) -not [double]::IsNaN($r.spread90_50) }
$ix2 = Pick-Idx { param($r) -not [double]::IsNaN($r.asymmetry) }
$ix3 = Pick-Idx { param($r) -not [double]::IsNaN($r.I_peak_mA) }
$ix4 = Pick-Idx { param($r) -not [double]::IsNaN($r.spread90_50) -and -not [double]::IsNaN($r.asymmetry) }
$ix5 = Pick-Idx { param($r) -not [double]::IsNaN($r.I_peak_mA) -and -not [double]::IsNaN($r.width_mA) }
$ix6 = Pick-Idx { param($r) -not [double]::IsNaN($r.skew_pt_weighted) -and -not [double]::IsNaN($r.width_mA) }

$models = @(
    (Fit-Name 'alpha ~ spread90_50' $ix1 { param($r) @(1.0, $r.spread90_50) })
    (Fit-Name 'alpha ~ asymmetry' $ix2 { param($r) @(1.0, $r.asymmetry) })
    (Fit-Name 'alpha ~ I_peak_mA' $ix3 { param($r) @(1.0, $r.I_peak_mA) })
    (Fit-Name 'alpha ~ spread90_50 + asymmetry' $ix4 { param($r) @(1.0, $r.spread90_50, $r.asymmetry) })
    (Fit-Name 'alpha ~ I_peak_mA + width_mA' $ix5 { param($r) @(1.0, $r.I_peak_mA, $r.width_mA) })
    (Fit-Name 'alpha ~ skew_pt_weighted + width_mA' $ix6 { param($r) @(1.0, $r.skew_pt_weighted, $r.width_mA) })
) | Where-Object { $_ -ne $null }

$best = $models | Sort-Object loocv | Select-Object -First 1
$betaB = $best.sol.beta
$getXB = $best.getX

# yhat on all rows
$yhatAll = New-Object double[] $N
for ($i = 0; $i -lt $N; $i++) {
    $xi = & $getXB $feat[$i]
    if ($xi -eq $null -or $xi.Length -ne $betaB.Length) { $yhatAll[$i] = [double]::NaN; continue }
    $bad = $false; foreach ($c in $xi) { if ($c -ne $c) { $bad = $true } }
    if ($bad) { $yhatAll[$i] = [double]::NaN; continue }
    $yh = 0.0; for ($j = 0; $j -lt $xi.Length; $j++) { $yh += $xi[$j] * $betaB[$j] }
    $yhatAll[$i] = $yh
}

# CSV
$hdr = 'T_K,alpha,spread90_50,spread75_25,asymmetry,skew_pt_weighted,mean_minus_median_pt,I_peak_mA,width_mA,S_peak,I_peak_PT_mA,std_threshold_mA_PT,alpha_hat_best,residual_best'
$lines = @($hdr)
for ($i = 0; $i -lt $N; $i++) {
    $r = $feat[$i]
    $F = { param([double]$v) if ([double]::IsNaN($v)) { 'NaN' } else { $v.ToString('G17', $cult) } }
    $yh = $yhatAll[$i]
    $res = if ([double]::IsNaN($yh)) { '' } else { ($r.alpha - $yh).ToString('G17', $cult) }
    $yhS = if ([double]::IsNaN($yh)) { '' } else { $yh.ToString('G17', $cult) }
    $lines += "$([double]$r.T_K),$(&$F $r.alpha),$(&$F $r.spread90_50),$(&$F $r.spread75_25),$(&$F $r.asymmetry),$(&$F $r.skew_pt_weighted),$(&$F $r.mean_minus_median_pt),$(&$F $r.I_peak_mA),$(&$F $r.width_mA),$(&$F $r.S_peak),$(&$F $r.I_peak_PT_mA),$(&$F $r.std_threshold_mA_PT),$yhS,$res"
}
$lines | Set-Content -Path $outCsv -Encoding utf8

# std(alpha) on PT-valid rows
$ixP = Pick-Idx { param($r) -not [double]::IsNaN($r.spread90_50) }
$alP = $ixP | ForEach-Object { $feat[$_].alpha }
$mA = ($alP | Measure-Object -Average).Average
$sig = [math]::Sqrt((($alP | ForEach-Object { ($_ - $mA) * ($_ - $mA) } | Measure-Object -Average).Average))

function Flag-Pred($r, $rm, $sg) {
    if ([double]::IsNaN($r) -or [double]::IsNaN($rm) -or [double]::IsNaN($sg) -or $sg -lt 1e-12) { return 'NO' }
    $ar = [math]::Abs($r)
    if ($ar -ge 0.72 -and $rm -le 0.55 * $sg) { return 'YES' }
    if ($ar -ge 0.45 -or $rm -le 0.75 * $sg) { return 'PARTIAL' }
    return 'NO'
}
$fl = Flag-Pred $best.pearson $best.loocv $sig
$geo = if ($best.name -match 'spread|asymmetry|skew') { 'YES' } else { 'NO' }
$minf = if ($best.idx.Length -ge 5 -and [math]::Abs($best.pearson) -ge 0.5) { 'YES' } else { 'NO' }

$tK = $best.idx | ForEach-Object { $feat[$_].T_K }
$yB = $best.idx | ForEach-Object { $feat[$_].alpha }
$yhB = $best.yhat
$monoTa = Corr-S ($tK -as [double[]]) ($yB -as [double[]])
$monoTh = Corr-S ($tK -as [double[]]) ($yhB -as [double[]])

$u_sp = Corr-P ([double[]]($ix1 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix1 | ForEach-Object { $feat[$_].spread90_50 }))
$u_as = Corr-P ([double[]]($ix2 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix2 | ForEach-Object { $feat[$_].asymmetry }))
$u_ip = Corr-P ([double[]]($ix3 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix3 | ForEach-Object { $feat[$_].I_peak_mA }))
$s_sp = Corr-S ([double[]]($ix1 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix1 | ForEach-Object { $feat[$_].spread90_50 }))
$s_as = Corr-S ([double[]]($ix2 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix2 | ForEach-Object { $feat[$_].asymmetry }))
$s_ip = Corr-S ([double[]]($ix3 | ForEach-Object { $feat[$_].alpha })) ([double[]]($ix3 | ForEach-Object { $feat[$_].I_peak_mA }))

$form = switch -Regex ($best.name) {
    '^alpha ~ spread90_50$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * spread90_50"; break }
    '^alpha ~ asymmetry$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * asymmetry"; break }
    '^alpha ~ I_peak_mA$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * I_peak_mA"; break }
    '^alpha ~ spread90_50 \+ asymmetry$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * spread90_50 + $($best.sol.beta[2].ToString('G9')) * asymmetry"; break }
    '^alpha ~ I_peak_mA \+ width_mA$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * I_peak_mA + $($best.sol.beta[2].ToString('G9')) * width_mA"; break }
    '^alpha ~ skew_pt_weighted \+ width_mA$' { "alpha = $($best.sol.beta[0].ToString('G9')) + $($best.sol.beta[1].ToString('G9')) * skew_pt_weighted + $($best.sol.beta[2].ToString('G9')) * width_mA"; break }
    default { 'alpha = X*beta' }
}

$rep = @"
# Alpha from PT geometry (Agent 20B)

**Goal:** low-dimensional mapping ``alpha(T) = f(PT geometry observables)`` with ``alpha = kappa2/kappa1`` (Agent 19F).

- **alpha table:** ``tables/alpha_structure.csv``
- **PT_matrix.csv:** ``results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_matrix.csv``
- **PT_summary.csv:** ``results/switching/runs/run_2026_03_25_013356_pt_robust_canonical/tables/PT_summary.csv``

## Feature definitions (per T)

- **spread90_50**, **spread75_25**, **asymmetry**, **skew_pt_weighted**, **mean_minus_median_pt**, **I_peak_PT_mA**: from normalized PMF rows of ``PT_matrix`` (discrete CDF quantiles; skew = ``v3 / v2^(3/2)`` on the PMF). **skew_pt_weighted** may be ``NaN`` when the discrete variance ``v2`` is numerically zero in this pipeline (then the ``alpha ~ skew_pt_weighted + width_mA`` fit is omitted from the table).
- **I_peak_mA**, **width_mA**, **S_peak**: switching observables from ``alpha_structure.csv`` (Agent 19F pipeline).
- **std_threshold_mA_PT**: from ``PT_summary.csv``.

## Best model (by LOOCV RMSE)

- **Model:** ``$($best.name)``
- **Explicit formula:** $form
- **LOOCV RMSE:** $($best.loocv.ToString('G9'))
- **In-sample Pearson(alpha, yhat):** $($best.pearson.ToString('G9'))
- **In-sample Spearman(alpha, yhat):** $($best.spearman.ToString('G9'))
- **Spearman(T, alpha):** $($monoTa.ToString('G9')); **Spearman(T, yhat):** $($monoTh.ToString('G9')) (monotonicity vs temperature on the fit mask)
- **22-24 K sensitivity:** hold-one-T-out RMSE on T ``{22, 24}``: **$($best.rm224.ToString('G9'))**
- **std(alpha) on PT-valid rows:** $($sig.ToString('G9')) (scale for LOOCV)

## Correlation strength (alpha vs single predictors, PT-valid rows where defined)

| predictor | Pearson | Spearman |
|---|---:|---:|
| spread90_50 | $($u_sp.ToString('G9')) | $($s_sp.ToString('G9')) |
| asymmetry | $($u_as.ToString('G9')) | $($s_as.ToString('G9')) |
| I_peak_mA (all T with alpha) | $($u_ip.ToString('G9')) | $($s_ip.ToString('G9')) |

## All models

| model | n | LOOCV RMSE | Pearson | Spearman | max leverage |
|---|---:|---:|---:|---:|---:|
"@
$rep += "`n"
foreach ($m in ($models | Sort-Object loocv)) {
    $rep += "| $($m.name) | $($m.idx.Length) | $($m.loocv.ToString('G9')) | $($m.pearson.ToString('G9')) | $($m.spearman.ToString('G9')) | $($m.maxlev.ToString('G9')) |`n"
}
$rep += @"

## Regime behavior

- ``PT_matrix`` rows are **missing** at 28-30 K in this canonical export; PT-spread features are **NaN** there (see ``alpha_from_PT.csv``).
- **22-24 K** is the sharp **alpha** step in Agent 19F; hold-out RMSE on ``{22,24}`` tests whether the geometry law extrapolates across that band when each point is predicted from the rest.
- On a **sparse** discrete current grid, **q75-q25** can occasionally go negative from the piecewise-linear inverse-CDF construction; **spread90_50** and **asymmetry** remain the primary shape/tail-side descriptors used in the best model.

## Final flags

- **ALPHA_PREDICTABLE_FROM_PT** = **$fl**
- **ALPHA_GEOMETRY_CONTROLLED** = **$geo**
- **MINIMAL_MODEL_FOUND** = **$minf**

*Generated by ``tools/compute_alpha_from_pt_agent20b.ps1`` (MATLAB twin: ``analysis/run_alpha_from_pt_agent20b.m``).*
"@
$rep | Set-Content -Path $outRep -Encoding utf8
Write-Host "Wrote $outCsv"
Write-Host "Wrote $outRep"
Write-Host "Best: $($best.name) LOOCV=$($best.loocv.ToString('G9'))"
