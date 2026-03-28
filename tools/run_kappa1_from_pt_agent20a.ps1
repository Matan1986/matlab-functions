# Agent 20A: kappa1 ~ PT tail observables (read-only). Writes repo-root tables + reports.
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot

$ptDefaultPath = Join-Path $Repo "results/switching/runs/run_2026_03_25_013849_pt_robust_minpts7/tables/PT_matrix.csv"
$ptPath = if ($env:PT_MATRIX_OVERRIDE) { $env:PT_MATRIX_OVERRIDE } else { $ptDefaultPath }
$kappaPath = Join-Path $Repo "results/switching/runs/_extract_run_2026_03_24_220314_residual_decomposition/run_2026_03_24_220314_residual_decomposition/tables/kappa_vs_T.csv"
$scalingPath = Join-Path $Repo "results/switching/runs/run_2026_03_12_234016_switching_full_scaling_collapse/tables/switching_full_scaling_parameters.csv"
$outCsv = if ($env:OUT_CSV_OVERRIDE) { $env:OUT_CSV_OVERRIDE } else { (Join-Path $Repo "tables/kappa1_from_PT.csv") }
$outMd = if ($env:OUT_MD_OVERRIDE) { $env:OUT_MD_OVERRIDE } else { (Join-Path $Repo "reports/kappa1_from_PT_report.md") }

$ptRunId = ""
$m = [regex]::Match($ptPath, "run_\d{4}_\d{2}_\d{2}_\d{6}_[^\\/]+")
if ($m.Success) { $ptRunId = $m.Value }

# PowerShell parses $M[$i,$j] incorrectly in some builds — use .GetValue
function MG([double[,]]$A, [int]$r, [int]$c) { return [double]$A.GetValue($r, $c) }
function MS([double[,]]$A, [int]$r, [int]$c, [double]$v) { [void]$A.SetValue($v, $r, $c) }
function KeyT([double]$t) { return [string]([math]::Round($t, 6)) }

function Test-FiniteD([double]$x) {
    return ($x -eq $x) -and ($x -ne [double]::PositiveInfinity) -and ($x -ne [double]::NegativeInfinity)
}

function Get-CumTrapz([double[]]$x, [double[]]$y) {
    $c = New-Object 'double[]' $x.Length
    for ($i = 1; $i -lt $x.Length; $i++) {
        $c[$i] = $c[$i - 1] + 0.5 * ($y[$i] + $y[$i - 1]) * ($x[$i] - $x[$i - 1])
    }
    return ,$c
}

function Get-QuantileFromCdf([double[]]$I, [double[]]$cdf, [double]$qt) {
    $pairs = @()
    for ($k = 0; $k -lt $I.Length; $k++) {
        if ((Test-FiniteD $I[$k]) -and (Test-FiniteD $cdf[$k])) { $pairs += ,@($cdf[$k], $I[$k]) }
    }
    if ($pairs.Count -lt 2) { return [double]::NaN }
    $ucu = @(); $agg = @{}; $cnt = @{}
    foreach ($p in $pairs) {
        $u = $p[0]; $ix = $p[1]
        if (-not $agg.ContainsKey([string]$u)) { $agg[[string]$u] = 0.0; $cnt[[string]$u] = 0 }
        $agg[[string]$u] += $ix; $cnt[[string]$u]++
    }
    $keys = $agg.Keys | ForEach-Object { [double]$_ } | Sort-Object
    $uxu = @()
    foreach ($u in $keys) { $s = [string]$u; $uxu += $agg[$s] / [math]::Max(1, $cnt[$s]) }
    $qt = [math]::Max(0.0, [math]::Min(1.0, $qt))
    if ($keys.Count -lt 2) { return [double]::NaN }
    return [double](Get-LinearInterp $qt $keys $uxu)
}

function Get-LinearInterp([double]$q, [double[]]$xu, [double[]]$yu) {
    if ($q -le $xu[0]) { return $yu[0] }
    if ($q -ge $xu[-1]) { return $yu[-1] }
    for ($i = 0; $i -lt $xu.Length - 1; $i++) {
        if ($q -ge $xu[$i] -and $q -le $xu[$i + 1]) {
            $t = ($q - $xu[$i]) / ($xu[$i + 1] - $xu[$i])
            return $yu[$i] + $t * ($yu[$i + 1] - $yu[$i])
        }
    }
    return [double]::NaN
}

function Get-Trapz([double[]]$x, [double[]]$y) {
    $s = 0.0
    for ($i = 1; $i -lt $x.Length; $i++) {
        $s += 0.5 * ($y[$i] + $y[$i - 1]) * ($x[$i] - $x[$i - 1])
    }
    return $s
}

function Test-RowValid([double[]]$prow, [double[]]$Iref) {
    foreach ($v in $prow) { if (-not (Test-FiniteD $v)) { return $false } }
    $allNonPos = $true
    foreach ($v in $prow) { if ($v -gt 0) { $allNonPos = $false } }
    if ($allNonPos) { return $false }
    $p = $prow | ForEach-Object { [math]::Max($_, 0.0) }
    $area = Get-Trapz $Iref $p
    return ((Test-FiniteD $area) -and $area -gt 0)
}

function Get-TailFeatures([double[]]$Iraw, [double[]]$pRaw) {
    $Ix = @(); $px = @()
    for ($k = 0; $k -lt $Iraw.Length; $k++) {
        if ((Test-FiniteD $Iraw[$k]) -and (Test-FiniteD $pRaw[$k])) {
            $Ix += $Iraw[$k]; $px += [math]::Max(0.0, $pRaw[$k])
        }
    }
    $I = [double[]]$Ix; $p = [double[]]$px
    if ($I.Length -lt 2) { return $null }
    $area = Get-Trapz $I $p
    if (-not (Test-FiniteD $area) -or $area -le 0) { return $null }
    $pn = $p | ForEach-Object { $_ / $area }
    $cdf = Get-CumTrapz $I $pn
    if ($cdf[-1] -le 0) { return $null }
    $cf = $cdf | ForEach-Object { $_ / $cdf[-1] }
    $q50 = Get-QuantileFromCdf $I $cf 0.50
    $q75 = Get-QuantileFromCdf $I $cf 0.75
    $q90 = Get-QuantileFromCdf $I $cf 0.90
    $q95 = Get-QuantileFromCdf $I $cf 0.95
    $q875 = Get-QuantileFromCdf $I $cf 0.875
    $span = $I[-1] - $I[0]
    $iCut = $I[0] + 0.875 * $span
    $geom = [double]::NaN
    $idx = @()
    for ($k = 0; $k -lt $I.Length; $k++) { if ($I[$k] -ge $iCut) { $idx += $k } }
    if ($idx.Count -ge 2) {
        $It = [double[]]@($idx | ForEach-Object { $I[$_] })
        $pt = [double[]]@($idx | ForEach-Object { $pn[$_] })
        $geom = Get-Trapz $It $pt
    }
    $tmq = [double]::NaN
    $idx2 = @()
    for ($k = 0; $k -lt $I.Length; $k++) { if ($I[$k] -ge $q875) { $idx2 += $k } }
    if ($idx2.Count -ge 2) {
        $It2 = [double[]]@($idx2 | ForEach-Object { $I[$_] })
        $pt2 = [double[]]@($idx2 | ForEach-Object { $pn[$_] })
        $tmq = Get-Trapz $It2 $pt2
    }
    $pdfq90 = Get-LinearInterp $q90 $I $pn
    return [pscustomobject]@{
        q50_I = $q50; q75_I = $q75; q90_I = $q90; q95_I = $q95
        tail_width_q90_q50 = ($q90 - $q50); extreme_tail_q95_q75 = ($q95 - $q75)
        tail_mass_geom_top12p5_axis = $geom; tail_mass_quantile_top12p5 = $tmq; pdf_at_q90 = $pdfq90
    }
}

function Get-Pearson([double[]]$a, [double[]]$b) {
    $n = $a.Length
    $ax = @(); $bx = @()
    for ($i = 0; $i -lt $n; $i++) {
        if ((Test-FiniteD $a[$i]) -and (Test-FiniteD $b[$i])) { $ax += $a[$i]; $bx += $b[$i] }
    }
    if ($ax.Length -lt 2) { return [double]::NaN }
    $mx = ($ax | Measure-Object -Average).Average
    $my = ($bx | Measure-Object -Average).Average
    $num = 0.0; $dx = 0.0; $dy = 0.0
    for ($i = 0; $i -lt $ax.Length; $i++) {
        $num += ($ax[$i] - $mx) * ($bx[$i] - $my)
        $dx += [math]::Pow($ax[$i] - $mx, 2)
        $dy += [math]::Pow($bx[$i] - $my, 2)
    }
    $den = [math]::Sqrt($dx * $dy)
    if ($den -eq 0) { return [double]::NaN }
    return $num / $den
}

function Get-Spearman([double[]]$a, [double[]]$b) {
    $ax = @(); $bx = @()
    for ($i = 0; $i -lt $a.Length; $i++) {
        if ((Test-FiniteD $a[$i]) -and (Test-FiniteD $b[$i])) { $ax += $a[$i]; $bx += $b[$i] }
    }
    if ($ax.Length -lt 2) { return [double]::NaN }
    $ra = Get-Ranks $ax; $rb = Get-Ranks $bx
    return Get-Pearson $ra $rb
}

function Get-Ranks([double[]]$v) {
    $idx = 0..($v.Length - 1) | Sort-Object { $v[$_] }
    $r = New-Object 'double[]' $v.Length
    $i = 0
    while ($i -lt $idx.Length) {
        $j = $i
        while ($j -lt $idx.Length -and ($v[$idx[$j]] -eq $v[$idx[$i]])) { $j++ }
        $avg = ($i + 1 + $j) / 2.0
        for ($k = $i; $k -lt $j; $k++) { $r[$idx[$k]] = $avg }
        $i = $j
    }
    return ,$r
}

function Solve-Ols([double[,]]$Z, [double[]]$y) {
    # normal equations Z'*Z beta = Z'*y
    $n = $Z.GetLength(0)
    $p = $Z.GetLength(1)
    $ZtZ = New-Object 'double[,]' $p, $p
    $Zty = New-Object 'double[]' $p
    for ($i = 0; $i -lt $p; $i++) {
        $s = 0.0
        for ($k = 0; $k -lt $n; $k++) { $s += (MG $Z $k $i) * $y[$k] }
        $Zty[$i] = $s
        for ($j = 0; $j -lt $p; $j++) {
            $s2 = 0.0
            for ($k = 0; $k -lt $n; $k++) { $s2 += (MG $Z $k $i) * (MG $Z $k $j) }
            MS $ZtZ $i $j $s2
        }
    }
    return Solve-LinearSystem $ZtZ $Zty
}

function Solve-LinearSystem([double[,]]$A, [double[]]$b) {
    $n = $b.Length
    $M = New-Object 'double[,]' $n, ($n + 1)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { MS $M $i $j (MG $A $i $j) }
        MS $M $i $n $b[$i]
    }
    # Gaussian elimination ($col is reserved in PowerShell — use $cix)
    for ($cix = 0; $cix -lt $n; $cix++) {
        $piv = $cix
        for ($rr = $cix + 1; $rr -lt $n; $rr++) {
            if ([math]::Abs((MG $M $rr $cix)) -gt [math]::Abs((MG $M $piv $cix))) { $piv = $rr }
        }
        for ($c = 0; $c -le $n; $c++) {
            $t = MG $M $cix $c
            MS $M $cix $c (MG $M $piv $c)
            MS $M $piv $c $t
        }
        $div = MG $M $cix $cix
        if ([math]::Abs($div) -lt 1e-15) { throw "Singular matrix" }
        for ($c = 0; $c -le $n; $c++) { MS $M $cix $c ((MG $M $cix $c) / $div) }
        for ($rr = 0; $rr -lt $n; $rr++) {
            if ($rr -ne $cix) {
                $f = MG $M $rr $cix
                for ($c = 0; $c -le $n; $c++) { MS $M $rr $c ((MG $M $rr $c) - $f * (MG $M $cix $c)) }
            }
        }
    }
    $x = New-Object 'double[]' $n
    for ($i = 0; $i -lt $n; $i++) { $x[$i] = MG $M $i $n }
    return ,$x
}

function Get-OlsFit([double[,]]$X, [double[]]$y) {
    $n = $X.GetLength(0)
    $p = $X.GetLength(1)
    $Z = New-Object 'double[,]' $n, ($p + 1)
    for ($k = 0; $k -lt $n; $k++) {
        MS $Z $k 0 1.0
        for ($j = 0; $j -lt $p; $j++) { MS $Z $k ($j + 1) (MG $X $k $j) }
    }
    $beta = Solve-Ols $Z $y
    $yhat = New-Object 'double[]' $n
    for ($k = 0; $k -lt $n; $k++) {
        $s = $beta[0]
        for ($j = 0; $j -lt $p; $j++) { $s += $beta[$j + 1] * (MG $X $k $j) }
        $yhat[$k] = $s
    }
    return @{ Beta = $beta; Yhat = $yhat }
}

function Get-LoocvRmse([double[,]]$X, [double[]]$y) {
    $n = $X.GetLength(0)
    if ($n -lt 3) { return [double]::NaN }
    $se = 0.0
    for ($ii = 0; $ii -lt $n; $ii++) {
        $n1 = $n - 1
        $p = $X.GetLength(1)
        $X1 = New-Object 'double[,]' $n1, $p
        $y1 = New-Object 'double[]' $n1
        $r = 0
        for ($k = 0; $k -lt $n; $k++) {
            if ($k -eq $ii) { continue }
            for ($j = 0; $j -lt $p; $j++) { MS $X1 $r $j (MG $X $k $j) }
            $y1[$r] = $y[$k]
            $r++
        }
        $fit = Get-OlsFit $X1 $y1
        $pred = $fit.Beta[0]
        for ($j = 0; $j -lt $p; $j++) { $pred += $fit.Beta[$j + 1] * (MG $X $ii $j) }
        $se += [math]::Pow($y[$ii] - $pred, 2)
    }
    return [math]::Sqrt($se / $n)
}

# --- Load PT matrix
$pt = Import-Csv $ptPath
$hdr = $pt[0].PSObject.Properties.Name
$tCol = if ($hdr -contains 'T_K') { 'T_K' } else { $hdr[0] }
$ithCols = $hdr | Where-Object { $_ -ne $tCol -and $_ -like 'Ith_*' }
function Parse-IthCol([string]$name) {
    $s = $name -replace '^Ith_', '' -replace '_mA$', ''
    $s = $s -replace '_', '.'
    return [double]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)
}
$currents = @()
foreach ($c in $ithCols) { $currents += (Parse-IthCol $c) }
$order = 0..($currents.Length - 1) | Sort-Object { $currents[$_] }
$currents = [double[]]($order | ForEach-Object { $currents[$_] })
$colOrder = $order | ForEach-Object { $ithCols[$_] }

$rowsOut = @()
foreach ($row in $pt) {
    $t = [double]::Parse([string]$row.$tCol, [System.Globalization.CultureInfo]::InvariantCulture)
    $prow = @()
    foreach ($cn in $colOrder) {
        $cell = [string]$row.$cn
        if ($cell -eq '' -or $cell -eq 'NaN') { $prow += [double]::NaN }
        else { $prow += [double]::Parse($cell, [System.Globalization.CultureInfo]::InvariantCulture) }
    }
    $rowsOut += ,@($t, $prow)
}

# Kappa + scaling lookup
$kappaRows = Import-Csv $kappaPath
$kapMap = @{}
foreach ($r in $kappaRows) { $kapMap[(KeyT ([double]$r.T))] = [double]$r.kappa }
$scaleRows = Import-Csv $scalingPath
$spMap = @{}
foreach ($r in $scaleRows) { $spMap[(KeyT ([double]$r.T_K))] = [double]$r.S_peak }

$data = @()
foreach ($item in $rowsOut) {
    $t = $item[0]; $prow = [double[]]$item[1]
    $tk = KeyT $t
    if (-not $kapMap.ContainsKey($tk)) { continue }
    if (-not $spMap.ContainsKey($tk)) { continue }
    if (-not (Test-RowValid $prow $currents)) { continue }
    $fe = Get-TailFeatures $currents $prow
    if ($null -eq $fe) { continue }
    $sp = $spMap[$tk]
    $fe | Add-Member -NotePropertyName T_K -NotePropertyValue $t -Force
    $fe | Add-Member -NotePropertyName kappa1 -NotePropertyValue $kapMap[$tk] -Force
    $fe | Add-Member -NotePropertyName S_peak -NotePropertyValue $sp -Force
    $fe | Add-Member -NotePropertyName tail_width_over_Speak -NotePropertyValue ($fe.tail_width_q90_q50 / $sp) -Force
    $fe | Add-Member -NotePropertyName extreme_over_Speak -NotePropertyValue ($fe.extreme_tail_q95_q75 / $sp) -Force
    $data += $fe
}

if ($data.Count -lt 5) { throw "Too few aligned rows" }

New-Item -ItemType Directory -Force -Path (Split-Path $outCsv) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $outMd) | Out-Null
$data | Export-Csv -NoTypeInformation -Path $outCsv

function To-Matrix1([double[]]$v) {
    $n = $v.Length
    $M = New-Object 'double[,]' $n, 1
    for ($i = 0; $i -lt $n; $i++) { MS $M $i 0 $v[$i] }
    return ,$M
}
function To-Matrix2([double[]]$a, [double[]]$b) {
    $n = $a.Length
    $M = New-Object 'double[,]' $n, 2
    for ($i = 0; $i -lt $n; $i++) { MS $M $i 0 $a[$i]; MS $M $i 1 $b[$i] }
    return ,$M
}

$T = [double[]]($data | ForEach-Object { $_.T_K })
$kap = [double[]]($data | ForEach-Object { $_.kappa1 })
$spv = [double[]]($data | ForEach-Object { $_.S_peak })
$q50v = [double[]]($data | ForEach-Object { $_.q50_I })
$q90v = [double[]]($data | ForEach-Object { $_.q90_I })
$tw = [double[]]($data | ForEach-Object { $_.tail_width_q90_q50 })
$tm = [double[]]($data | ForEach-Object { $_.tail_mass_quantile_top12p5 })

$yv = $kap
$models = @(
    [pscustomobject]@{ Name = "linear: kappa1 ~ q90"; Formula = "kappa1 ~ q90"; X = (To-Matrix1 $q90v); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ tail_width"; Formula = "kappa1 ~ (q90-q50)"; X = (To-Matrix1 $tw); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ tail_mass_q"; Formula = "kappa1 ~ tail_mass_top12.5"; X = (To-Matrix1 $tm); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ q90 + width"; Formula = "kappa1 ~ q90 + tail_width"; X = (To-Matrix2 $q90v $tw); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ width + S_peak"; Formula = "kappa1 ~ tail_width + S_peak"; X = (To-Matrix2 $tw $spv); Y = $yv }
)

$logKap = [double[]]($kap | ForEach-Object { [math]::Log($_) })
$models += @(
    [pscustomobject]@{ Name = "log_kappa: log(kappa1) ~ q90"; Formula = "log(kappa1) ~ q90"; X = (To-Matrix1 $q90v); Y = $logKap },
    [pscustomobject]@{ Name = "log_kappa: log(kappa1) ~ tail_width"; Formula = "log(kappa1) ~ (q90-q50)"; X = (To-Matrix1 $tw); Y = $logKap },
    [pscustomobject]@{ Name = "log_kappa: log(kappa1) ~ tail_mass_q"; Formula = "log(kappa1) ~ tail_mass_top12.5"; X = (To-Matrix1 $tm); Y = $logKap },
    [pscustomobject]@{ Name = "log_kappa: log(kappa1) ~ q90 + width"; Formula = "log(kappa1) ~ q90 + tail_width"; X = (To-Matrix2 $q90v $tw); Y = $logKap },
    [pscustomobject]@{ Name = "log_kappa: log(kappa1) ~ width + S_peak"; Formula = "log(kappa1) ~ tail_width + S_peak"; X = (To-Matrix2 $tw $spv); Y = $logKap }
)

$lq90 = [double[]]($q90v | ForEach-Object { [math]::Log($_) })
$ltw = [double[]]($tw | ForEach-Object { [math]::Log($_) })
$models += @(
    [pscustomobject]@{ Name = "linear: kappa1 ~ log(q90)"; Formula = "kappa1 ~ log(q90)"; X = (To-Matrix1 $lq90); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ log(tail_width)"; Formula = "kappa1 ~ log(tail_width)"; X = (To-Matrix1 $ltw); Y = $yv },
    [pscustomobject]@{ Name = "linear: kappa1 ~ log(q90)+log(width)"; Formula = "kappa1 ~ log(q90)+log(tail_width)"; X = (To-Matrix2 $lq90 $ltw); Y = $yv }
)

$maskExcl = 0..($T.Length - 1) | Where-Object { ($T[$_] -lt 22) -or ($T[$_] -gt 24) }
$nEx = $maskExcl.Count

$lines = @()
foreach ($m in $models) {
    $fit = Get-OlsFit $m.X $m.Y
    $loocv = Get-LoocvRmse $m.X $m.Y
    $rmse = [math]::Sqrt((0..($m.Y.Length - 1) | ForEach-Object { [math]::Pow($m.Y[$_] - $fit.Yhat[$_], 2) } | Measure-Object -Average).Average)
    $py = Get-Pearson $fit.Yhat $m.Y
    $sy = Get-Spearman $fit.Yhat $m.Y
    $loocvEx = [double]::NaN
    if ($nEx -ge 4) {
        $n = $m.X.GetLength(0); $p = $m.X.GetLength(1)
        $X2 = New-Object 'double[,]' $nEx, $p
        $y2 = New-Object 'double[]' $nEx
        $r = 0
        foreach ($ix in $maskExcl) {
            for ($j = 0; $j -lt $p; $j++) { MS $X2 $r $j (MG $m.X $ix $j) }
            $y2[$r] = $m.Y[$ix]; $r++
        }
        $loocvEx = Get-LoocvRmse $X2 $y2
    }
    $lines += [pscustomobject]@{
        Name = $m.Name; Loocv = $loocv; Rmse = $rmse; Py = $py; Sy = $sy; LoocvEx = $loocvEx
        Formula = ($m.Formula + " | beta=[" + ([string]::Join(' ', $fit.Beta)) + "]")
    }
}

$best = $lines | Where-Object { $_.Name -like 'linear: kappa1*' } | Sort-Object Loocv | Select-Object -First 1
$meanKap = ($kap | Measure-Object -Average).Average
$stdKap = [math]::Sqrt((($kap | ForEach-Object { ($_ - $meanKap) * ($_ - $meanKap) } | Measure-Object -Average).Average))
$relLoocv = $best.Loocv / [math]::Max($stdKap, 1e-12)
$goodLoocv = $relLoocv -lt 0.45
$goodR = [math]::Abs($best.Py) -gt 0.72
if ($goodLoocv -and $goodR) { $predFlag = 'YES' }
elseif ($goodR -or $relLoocv -lt 0.65) { $predFlag = 'PARTIAL' }
else { $predFlag = 'NO' }

$cTail = [math]::Abs((Get-Pearson $kap $q90v))
$cMed = [math]::Abs((Get-Pearson $kap $q50v))
if ($cTail -gt $cMed + 0.1 -and $cTail -gt 0.35) { $tailDom = 'YES' } else { $tailDom = 'NO' }
$minimal = if ($predFlag -eq 'NO') { 'NO' } else { 'YES' }
$stable = (Test-FiniteD $best.LoocvEx) -and ($best.LoocvEx -lt 1.5 * $best.Loocv)

$md = @()
$md += "# Kappa1 from PT tail law (Agent 20A)"
$md += ""
$md += "## Data sources"
$md += "- **PT_matrix (tail features)**: ``$($ptPath.Replace($Repo + '\', '').Replace('\','/'))``"
$md += "- **kappa1 (kappaAll)**: ``$($kappaPath.Replace($Repo + '\', '').Replace('\','/'))``"
$md += "- **S_peak**: ``$($scalingPath.Replace($Repo + '\', '').Replace('\','/'))``"
$md += ""
$md += "*Note: Canonical decomposition used PT from ``run_2026_03_24_212033_switching_barrier_distribution_from_map``; this report uses PT row shapes (``$ptRunId``) for tail metrics.*"
$md += ""
$md += "## Correlations (kappa1 vs tail features)"
$md += "| Feature | Pearson | Spearman |"
$md += "| --- | --- | --- |"
$md += ("| q90_I | {0:F4} | {1:F4} |" -f (Get-Pearson $kap $q90v), (Get-Spearman $kap $q90v))
$md += ("| tail width (q90-q50) | {0:F4} | {1:F4} |" -f (Get-Pearson $kap $tw), (Get-Spearman $kap $tw))
$md += ("| tail_mass_quantile_top12p5 | {0:F4} | {1:F4} |" -f (Get-Pearson $kap $tm), (Get-Spearman $kap $tm))
$md += ("| S_peak | {0:F4} | {1:F4} |" -f (Get-Pearson $kap $spv), (Get-Spearman $kap $spv))
$md += ""
$md += "## Models"
$md += "| Model | LOOCV RMSE | in-sample RMSE | Pearson(y,yhat) | Spearman(y,yhat) | LOOCV excl 22-24 K |"
$md += "| --- | --- | --- | --- | --- | --- |"
foreach ($ln in $lines) {
    $md += "| $($ln.Name) | $($ln.Loocv) | $($ln.Rmse) | $([string]::Format('{0:F4}', $ln.Py)) | $([string]::Format('{0:F4}', $ln.Sy)) | $($ln.LoocvEx) |"
}
$md += ""
$md += "## Best model (linear ``kappa1`` predictors, min LOOCV)"
$md += "- **Name**: ``$($best.Name)``"
$md += "- **Formula / coefficients**: $($best.Formula)"
if ($best.Name -eq 'linear: kappa1 ~ width + S_peak') {
    $b = ($best.Formula -split 'beta=\[')[1] -replace '\].*','' -split '\s+' | Where-Object { $_ -ne '' }
    if ($b.Count -ge 3) {
        $md += ("- **Explicit (tail width ``W`` = q90-q50, mA; ``S`` = S_peak)**:" +
            " ``kappa1 = {0} + {1}*W + {2}*S``" -f [double]$b[0], [double]$b[1], [double]$b[2])
    }
}
$md += "- **q95_I**: finite for all aligned temperatures in this run (tail upper bound stable on the PT grid)."
$md += "- **Geom. tail mass (top 12.5% of I axis)**: often NaN on coarse grids; **tail_mass_quantile_top12p5** (mass above q87.5) is used as the tail-mass regressor."
$md += "- **LOOCV RMSE**: $($best.Loocv) (relative to std(kappa1): $([string]::Format('{0:F3}', $relLoocv)))"
$md += "- **LOOCV excluding T in [22,24] K** (n=$nEx): $($best.LoocvEx)"
$md += "- **Pearson / Spearman (y vs yhat)**: $([string]::Format('{0:F4}', $best.Py)), $([string]::Format('{0:F4}', $best.Sy))"
$md += "- **Stability (22-24 K exclusion)**: $(if ($stable) { 'PASS' } else { 'FAIL' })"
$doAligned = ($env:ALIGNED_RUN -eq '1')
if ($doAligned) {
    $prevTablePath = if ($env:COMPARE_PREV_TABLE_PATH) { $env:COMPARE_PREV_TABLE_PATH } else { (Join-Path $Repo "tables/kappa1_from_PT.csv") }
    $prevLoocv = [double]::NaN
    $prevPear = [double]::NaN
    $prevSpea = [double]::NaN
    if (Test-Path $prevTablePath) {
        $prevRows = Import-Csv $prevTablePath
        $prevW = @(); $prevS = @(); $prevY = @()
        foreach ($r in $prevRows) {
            $w = [double]$r.tail_width_q90_q50
            $s = [double]$r.S_peak
            $yv = [double]$r.kappa1
            if (Test-FiniteD $w -and Test-FiniteD $s -and Test-FiniteD $yv) {
                $prevW += ,$w
                $prevS += ,$s
                $prevY += ,$yv
            }
        }
        if ($prevW.Count -ge 4) {
            $prevX = To-Matrix2 ([double[]]$prevW) ([double[]]$prevS)
            $fitPrev = Get-OlsFit $prevX ([double[]]$prevY)
            $prevLoocv = Get-LoocvRmse $prevX ([double[]]$prevY)
            $prevPear = Get-Pearson $fitPrev.Yhat ([double[]]$prevY)
            $prevSpea = Get-Spearman $fitPrev.Yhat ([double[]]$prevY)
        }
    }

    $dLo = $best.Loocv - $prevLoocv
    $dPr = $best.Py - $prevPear
    $dSp = $best.Sy - $prevSpea

    $stableAfter = $false
    if (Test-FiniteD $prevLoocv) {
        $rmseThresh = 0.25 * $prevLoocv
        $pearThresh = 0.03
        if (([math]::Abs($dLo) -le $rmseThresh) -and ([math]::Abs($dPr) -le $pearThresh)) { $stableAfter = $true }
    }

    $md += ""
    $md += "## PT alignment change (vs previous unaligned model)"
    $md += "- PT artifact in this aligned run: $ptRunId"
    $md += "- Previous LOOCV RMSE: $prevLoocv"
    $md += "- Aligned LOOCV RMSE: $($best.Loocv)"
    $md += "- Delta LOOCV RMSE (aligned - previous): $dLo"
    $md += "- Previous Pearson/Spearman: $prevPear / $prevSpea"
    $md += "- Aligned Pearson/Spearman: $($best.Py) / $($best.Sy)"
    $md += "- Delta Pearson/Spearman: $dPr / $dSp"
    $md += "- MODEL_STABLE_AFTER_ALIGNMENT: $(if ($stableAfter) { 'YES' } else { 'NO' })"
} 
$md += ""
$md += "## Final flags"
$md += "- ``KAPPA1_PREDICTABLE_FROM_PT`` = **$predFlag**"
$md += "- ``KAPPA1_TAIL_DOMINATED`` = **$tailDom** (|corr(kappa,q90)|=$([string]::Format('{0:F3}', $cTail)) vs |corr(kappa,q50)|=$([string]::Format('{0:F3}', $cMed)))"
$md += "- ``MINIMAL_MODEL_FOUND`` = **$minimal**"
if ($doAligned) {
    $md += "- PT_ALIGNMENT_FIXED = **YES**"
    $md += "- MODEL_STABLE_AFTER_ALIGNMENT = **$(if ($stableAfter) { 'YES' } else { 'NO' })**"
}
$md | Set-Content -Path $outMd -Encoding utf8

Write-Host "Wrote $outCsv"
Write-Host "Wrote $outMd"
Write-Host "Best:" $best.Name "LOOCV" $best.Loocv
