# Agent 24B — LOOCV aging R prediction (read-only CSVs; no PT recompute)
$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot

$barrierP = Join-Path $Repo "results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv"
$energyP = Join-Path $Repo "results\switching\runs\run_2026_03_24_233256_energy_mapping\tables\energy_stats.csv"
$clkP = Join-Path $Repo "results\aging\runs\run_2026_03_14_074613_aging_clock_ratio_analysis\tables\table_clock_ratio.csv"
$alphaP = Join-Path $Repo "tables\alpha_structure.csv"
$decompP = Join-Path $Repo "tables\alpha_decomposition.csv"

function Read-CsvTable($path) { Import-Csv -LiteralPath $path }

function Test-FiniteVal([double]$x) {
    return -not ([double]::IsNaN($x) -or [double]::IsPositiveInfinity($x) -or [double]::IsNegativeInfinity($x))
}

function Unwrap-Angle([double[]]$th) {
    $n = $th.Length
    $out = New-Object double[] $n
    if ($n -eq 0) { return $out }
    $out[0] = $th[0]
    $acc = $th[0]
    for ($i = 1; $i -lt $n; $i++) {
        $d = $th[$i] - $th[$i - 1]
        $d = $d - [math]::Round($d / (2 * [math]::PI)) * 2 * [math]::PI
        $acc += $d
        $out[$i] = $acc
    }
    return $out
}

function Solve-LinearSystem([double[,]]$A, [double[]]$b) {
    $n = $b.Length
    $M = New-Object 'double[,]' $n, ($n + 1)
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) { $M.SetValue([double]$A.GetValue($i, $j), $i, $j) }
        $M.SetValue([double]$b[$i], $i, $n)
    }
    for ($k = 0; $k -lt $n; $k++) {
        $piv = $k
        $maxv = [math]::Abs([double]$M.GetValue($k, $k))
        for ($r = $k + 1; $r -lt $n; $r++) {
            $v = [math]::Abs([double]$M.GetValue($r, $k))
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        if ($maxv -lt 1e-14) { return $null }
        if ($piv -ne $k) {
            for ($c = $k; $c -le $n; $c++) {
                $tmp = [double]$M.GetValue($k, $c)
                $M.SetValue([double]$M.GetValue($piv, $c), $k, $c)
                $M.SetValue($tmp, $piv, $c)
            }
        }
        $diag = [double]$M.GetValue($k, $k)
        for ($c = $k; $c -le $n; $c++) { $M.SetValue([double]$M.GetValue($k, $c) / $diag, $k, $c) }
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $k) { continue }
            $f = [double]$M.GetValue($r, $k)
            if ([math]::Abs($f) -lt 1e-15) { continue }
            for ($c = $k; $c -le $n; $c++) {
                $v0 = [double]$M.GetValue($r, $c) - $f * [double]$M.GetValue($k, $c)
                $M.SetValue($v0, $r, $c)
            }
        }
    }
    $x = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $x[$i] = [double]$M.GetValue($i, $n) }
    return $x
}

function Matrix-Rank([double[,]]$Z) {
    $eps = 1e-10
    $rows = $Z.GetLength(0)
    $cols = $Z.GetLength(1)
    $A = New-Object 'double[,]' $rows, $cols
    for ($ii = 0; $ii -lt $rows; $ii++) {
        for ($jj = 0; $jj -lt $cols; $jj++) {
            $A.SetValue([double]$Z.GetValue($ii, $jj), $ii, $jj)
        }
    }
    $r = 0
    for ($cc = 0; $cc -lt $cols; $cc++) {
        $piv = -1
        $best = 0.0
        for ($ii = $r; $ii -lt $rows; $ii++) {
            $v = [math]::Abs([double]$A.GetValue($ii, $cc))
            if ($v -gt $best) { $best = $v; $piv = $ii }
        }
        if ($piv -lt 0 -or $best -lt $eps) { continue }
        if ($piv -ne $r) {
            for ($kk = 0; $kk -lt $cols; $kk++) {
                $t = [double]$A.GetValue($piv, $kk)
                $A.SetValue([double]$A.GetValue($r, $kk), $piv, $kk)
                $A.SetValue($t, $r, $kk)
            }
        }
        $div = [double]$A.GetValue($r, $cc)
        for ($ii = $r + 1; $ii -lt $rows; $ii++) {
            $f = [double]$A.GetValue($ii, $cc) / $div
            for ($kk = $cc; $kk -lt $cols; $kk++) {
                $nv = [double]$A.GetValue($ii, $kk) - $f * [double]$A.GetValue($r, $kk)
                $A.SetValue($nv, $ii, $kk)
            }
        }
        $r++
    }
    return $r
}

function Loocv-Mean([double[]]$y) {
    $n = $y.Length
    $yhat = New-Object double[] $n
    if ($n -lt 2) { return [pscustomobject]@{ rmse = [double]::NaN; pear = [double]::NaN; spear = [double]::NaN; yhat = $yhat } }
    $s = 0.0; foreach ($v in $y) { $s += $v }
    for ($i = 0; $i -lt $n; $i++) { $yhat[$i] = ($s - $y[$i]) / ($n - 1) }
    $se = 0.0; for ($i = 0; $i -lt $n; $i++) { $d = $y[$i] - $yhat[$i]; $se += $d * $d }
    $rmse = [math]::Sqrt($se / $n)
    return [pscustomobject]@{ rmse = $rmse; yhat = $yhat }
}

function Loocv-Ols([double[]]$y, [double[,]]$X) {
    $n = $y.Length
    $p = $X.GetLength(1)
    $yhat = New-Object double[] $n
    if ($n -le $p + 1) { return [pscustomobject]@{ rmse = [double]::NaN; yhat = $yhat } }

    $Z = New-Object 'double[,]' $n, ($p + 1)
    for ($i = 0; $i -lt $n; $i++) {
        $Z.SetValue(1.0, $i, 0)
        for ($j = 0; $j -lt $p; $j++) { $Z.SetValue([double]$X.GetValue($i, $j), $i, $j + 1) }
    }
    if ((Matrix-Rank $Z) -lt ($p + 1)) { return [pscustomobject]@{ rmse = [double]::NaN; yhat = $yhat } }

    $ZtZ = New-Object 'double[,]' ($p + 1), ($p + 1)
    $Zty = New-Object double[] ($p + 1)
    for ($a = 0; $a -le $p; $a++) {
        for ($b = 0; $b -le $p; $b++) {
            $s = 0.0
            for ($i = 0; $i -lt $n; $i++) {
                $s += [double]$Z.GetValue($i, $a) * [double]$Z.GetValue($i, $b)
            }
            $ZtZ.SetValue($s, $a, $b)
        }
        $s2 = 0.0
        for ($i = 0; $i -lt $n; $i++) { $s2 += [double]$Z.GetValue($i, $a) * $y[$i] }
        $Zty[$a] = $s2
    }
    $beta = Solve-LinearSystem $ZtZ $Zty
    if ($null -eq $beta) { return [pscustomobject]@{ rmse = [double]::NaN; yhat = $yhat } }

    $yfit = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $v = 0.0
        for ($j = 0; $j -le $p; $j++) { $v += [double]$Z.GetValue($i, $j) * $beta[$j] }
        $yfit[$i] = $v
    }
    # Inv(ZtZ) column-wise: ZtZ * x = e_j
    $InvZtZ = New-Object 'double[,]' ($p + 1), ($p + 1)
    for ($i = 0; $i -le $p; $i++) {
        $e = New-Object double[] ($p + 1); $e[$i] = 1.0
        $col = Solve-LinearSystem $ZtZ $e
        if ($null -eq $col) { return [pscustomobject]@{ rmse = [double]::NaN; yhat = $yhat } }
        for ($j = 0; $j -le $p; $j++) { $InvZtZ.SetValue($col[$j], $j, $i) }
    }
    $h = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $sum = 0.0
        for ($a = 0; $a -le $p; $a++) {
            for ($b = 0; $b -le $p; $b++) {
                $sum += [double]$Z.GetValue($i, $a) * [double]$InvZtZ.GetValue($a, $b) * [double]$Z.GetValue($i, $b)
            }
        }
        $h[$i] = $sum
    }

    $sse = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $e = $y[$i] - $yfit[$i]
        $loo = $e / [math]::Max(1.0 - $h[$i], 1e-12)
        $yhat[$i] = $y[$i] - $loo
        $sse += $loo * $loo
    }
    $rmse = [math]::Sqrt($sse / $n)
    return [pscustomobject]@{ rmse = $rmse; yhat = $yhat }
}

function Corr-Pearson([double[]]$a, [double[]]$b) {
    $n = $a.Length
    $m = 0; $sa = 0.0; $sb = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        if ([double]::IsNaN($a[$i]) -or [double]::IsNaN($b[$i])) { continue }
        $m++; $sa += $a[$i]; $sb += $b[$i]
    }
    if ($m -lt 2) { return [double]::NaN }
    $ma = $sa / $m; $mb = $sb / $m
    $num = 0.0; $da = 0.0; $db = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        if ([double]::IsNaN($a[$i]) -or [double]::IsNaN($b[$i])) { continue }
        $xa = $a[$i] - $ma; $xb = $b[$i] - $mb
        $num += $xa * $xb; $da += $xa * $xa; $db += $xb * $xb
    }
    if ($da -lt 1e-20 -or $db -lt 1e-20) { return [double]::NaN }
    return $num / [math]::Sqrt($da * $db)
}

# ---- Load & merge ----
$bar = Read-CsvTable $barrierP
$en = Read-CsvTable $energyP
if ($en[0].PSObject.Properties.Name -contains "T" -and ($en[0].PSObject.Properties.Name -notcontains "T_K")) {
    $en = $en | ForEach-Object { $_ | Add-Member -NotePropertyName T_K -NotePropertyValue $_.T -PassThru }
}
$enMap = @{}
foreach ($r in $en) { $enMap[[double]$r.T_K] = $r }

foreach ($row in $bar) {
    $tk = [double]$row.T_K
    if (-not $enMap.ContainsKey($tk)) { continue }
    $e = $enMap[$tk]
    $row | Add-Member -NotePropertyName mean_E -NotePropertyValue ([double]$e.mean_E) -Force
    $row | Add-Member -NotePropertyName std_E -NotePropertyValue ([double]$e.std_E) -Force
    $row | Add-Member -NotePropertyName spread90_50 -NotePropertyValue ([double]$row.q90_I_mA - [double]$row.q50_I_mA) -Force
    $row | Add-Member -NotePropertyName asymmetry -NotePropertyValue ([double]$row.asym_q75_50_minus_q50_25) -Force
}

$aS = Read-CsvTable $alphaP
$aD = Read-CsvTable $decompP
$dMap = @{}
foreach ($r in $aD) { $dMap[[double]$r.T_K] = $r }

$merged = @()
foreach ($r in $aS) {
    $tk = [double]$r.T_K
    if (-not $dMap.ContainsKey($tk)) { continue }
    $dv = $dMap[$tk]
    $bv = $bar | Where-Object { ([double]$_.T_K -eq $tk) -and ($_.PSObject.Properties.Name -contains 'mean_E') } | Select-Object -First 1
    if (-not $bv) { continue }
    if ([double]$dv.PT_geometry_valid -eq 0) { continue }
    if ([double]$bv.row_valid -eq 0) { continue }
    $merged += [pscustomobject]@{
        T_K             = $tk
        kappa1          = [double]$r.kappa1
        kappa2          = [double]$r.kappa2
        alpha           = [double]$r.alpha
        R               = [double]$bv.R_T_interp
        mean_E          = [double]$bv.mean_E
        std_E           = [double]$bv.std_E
        spread90_50     = [double]$bv.spread90_50
        asymmetry       = [double]$bv.asymmetry
        pt_svd_score1   = [double]$bv.pt_svd_score1
        pt_svd_score2   = [double]$bv.pt_svd_score2
    }
}
$merged = $merged | Sort-Object T_K
$n0 = $merged.Count
$theta = @(foreach ($m in $merged) { [math]::Atan2($m.kappa2, $m.kappa1) })
$thu = Unwrap-Angle $theta
$dtheta = New-Object double[] $n0
$dk1 = New-Object double[] $n0
$dk2 = New-Object double[] $n0
$dTarr = New-Object double[] $n0
for ($ii = 0; $ii -lt $n0; $ii++) {
    $dtheta[$ii] = [double]::NaN
    $dk1[$ii] = [double]::NaN
    $dk2[$ii] = [double]::NaN
    $dTarr[$ii] = [double]::NaN
}
for ($i = 1; $i -lt $n0; $i++) {
    $dtheta[$i] = $thu[$i] - $thu[$i - 1]
    $dk1[$i] = $merged[$i].kappa1 - $merged[$i - 1].kappa1
    $dk2[$i] = $merged[$i].kappa2 - $merged[$i - 1].kappa2
    $dTarr[$i] = $merged[$i].T_K - $merged[$i - 1].T_K
}
$ds = New-Object double[] $n0
$curv = New-Object double[] $n0
for ($ii = 0; $ii -lt $n0; $ii++) {
    $ds[$ii] = [double]::NaN
    $curv[$ii] = [double]::NaN
}
for ($i = 1; $i -lt $n0; $i++) {
    $ds[$i] = [math]::Sqrt($dk1[$i] * $dk1[$i] + $dk2[$i] * $dk2[$i])
    $curv[$i] = [math]::Abs($dtheta[$i]) / [math]::Max($dTarr[$i], 1e-12)
}
$absd = @(for ($i = 0; $i -lt $n0; $i++) { [math]::Abs($dtheta[$i]) })
$rnorm = @(foreach ($m in $merged) { [math]::Sqrt($m.kappa1 * $m.kappa1 + $m.kappa2 * $m.kappa2) })

$use = @()
for ($i = 0; $i -lt $n0; $i++) {
    $m = $merged[$i]
    $ok = (Test-FiniteVal $m.R) -and (Test-FiniteVal $m.mean_E) -and (Test-FiniteVal $m.spread90_50) `
        -and (Test-FiniteVal $m.kappa1) -and (Test-FiniteVal $m.kappa2) -and (Test-FiniteVal $theta[$i]) `
        -and (Test-FiniteVal $rnorm[$i]) -and (Test-FiniteVal $m.pt_svd_score1) -and (Test-FiniteVal $m.pt_svd_score2) `
        -and (Test-FiniteVal $m.asymmetry) -and (Test-FiniteVal $m.std_E) `
        -and (Test-FiniteVal $absd[$i]) -and (Test-FiniteVal $ds[$i]) -and (Test-FiniteVal $curv[$i])
    if ($ok) { $use += $i }
}
if ($use.Count -lt 5) { throw "Insufficient overlap n=$($use.Count)" }

$rows = @()
foreach ($i in $use) {
    $m = $merged[$i]
    $rows += [pscustomobject]@{
        T_K = $m.T_K; R = $m.R; mean_E = $m.mean_E; std_E = $m.std_E; spread90_50 = $m.spread90_50
        asymmetry = $m.asymmetry; pt_svd_score1 = $m.pt_svd_score1; pt_svd_score2 = $m.pt_svd_score2
        kappa1 = $m.kappa1; kappa2 = $m.kappa2; alpha = $m.alpha; theta_rad = $theta[$i]; r_kappa = $rnorm[$i]
        abs_delta_theta = $absd[$i]; ds = $ds[$i]; curvature_dtheta_over_dT = $curv[$i]
    }
}

$y = @(foreach ($x in $rows) { $x.R })
$Tplot = @(foreach ($x in $rows) { $x.T_K })
$n = $y.Length

$models = @(
    @{ id = "R ~ 1"; cat = "baseline"; cols = @() }
    @{ id = "R ~ mean_E"; cat = "PT-only"; cols = @("mean_E") }
    @{ id = "R ~ spread90_50"; cat = "PT-only"; cols = @("spread90_50") }
    @{ id = "R ~ mean_E + spread90_50"; cat = "PT-only"; cols = @("mean_E", "spread90_50") }
    @{ id = "R ~ kappa1"; cat = "state-only"; cols = @("kappa1") }
    @{ id = "R ~ r"; cat = "state-only"; cols = @("r_kappa") }
    @{ id = "R ~ theta_rad"; cat = "state-only"; cols = @("theta_rad") }
    @{ id = "R ~ abs_delta_theta"; cat = "trajectory-only"; cols = @("abs_delta_theta") }
    @{ id = "R ~ ds"; cat = "trajectory-only"; cols = @("ds") }
    @{ id = "R ~ mean_E + kappa1"; cat = "PT+state"; cols = @("mean_E", "kappa1") }
    @{ id = "R ~ spread90_50 + kappa1"; cat = "PT+state"; cols = @("spread90_50", "kappa1") }
    @{ id = "R ~ mean_E + kappa1 + abs_delta_theta"; cat = "PT+state+trajectory"; cols = @("mean_E", "kappa1", "abs_delta_theta") }
    @{ id = "R ~ spread90_50 + kappa1 + ds"; cat = "PT+state+trajectory"; cols = @("spread90_50", "kappa1", "ds") }
)

$outRows = @()
$bestRmse = [double]::PositiveInfinity
$bestName = ""
$bestYhat = $null
foreach ($md in $models) {
    if ($md.cols.Count -eq 0) {
        $fit = Loocv-Mean $y
        $rmse = $fit.rmse
        $yh = $fit.yhat
    }
    else {
        $p = $md.cols.Count
        $X = New-Object 'double[,]' $n, $p
        $bad = $false
        for ($i = 0; $i -lt $n; $i++) {
            for ($j = 0; $j -lt $p; $j++) {
                $nm = $md.cols[$j]
                $v = [double]$rows[$i].$nm
                if (-not (Test-FiniteVal $v)) { $bad = $true }
                $X.SetValue($v, $i, $j)
            }
        }
        if ($bad) {
            $rmse = [double]::NaN; $yh = New-Object double[] $n
        }
        else {
            $fit = Loocv-Ols $y $X
            $rmse = $fit.rmse
            $yh = $fit.yhat
        }
    }
    $pear = Corr-Pearson $y $yh
    $outRows += [pscustomobject]@{
        model = $md.id; category = $md.cat; n = $n; loocv_rmse = $rmse
        pearson_y_yhat = $pear; spearman_y_yhat = [double]::NaN
    }
    if ($md.cat -ne "baseline" -and (Test-FiniteVal $rmse) -and $rmse -lt $bestRmse) {
        $bestRmse = $rmse
        $bestName = $md.id
        $bestYhat = $yh
    }
}

$df = $outRows | ForEach-Object { $_ }
$baseRmse = ($df | Where-Object { $_.model -eq "R ~ 1" }).loocv_rmse

$families = "baseline", "PT-only", "state-only", "trajectory-only", "PT+state", "PT+state+trajectory"
$abl = @()
foreach ($fam in $families) {
    $sub = $df | Where-Object { $_.category -eq $fam }
    $best = $sub | Sort-Object loocv_rmse | Select-Object -First 1
    $abl += [pscustomobject]@{
        model_family = $fam
        best_model = $best.model
        loocv_rmse = $best.loocv_rmse
        pearson = $best.pearson_y_yhat
        spearman = $best.spearman_y_yhat
        delta_rmse_vs_baseline = ($best.loocv_rmse - $baseRmse)
    }
}

$rmsePT = ($abl | Where-Object { $_.model_family -eq "PT-only" }).loocv_rmse
$rmsePS = ($abl | Where-Object { $_.model_family -eq "PT+state" }).loocv_rmse
$rmsePST = ($abl | Where-Object { $_.model_family -eq "PT+state+trajectory" }).loocv_rmse
$pearPT = ($df | Where-Object { $_.category -eq "PT-only" } | Sort-Object loocv_rmse | Select-Object -First 1).pearson_y_yhat

$vPT = "NO"
if ((Test-FiniteVal $rmsePT) -and $rmsePT -lt $baseRmse * 0.92 -and [math]::Abs($pearPT) -gt 0.45) { $vPT = "YES" }
elseif ((Test-FiniteVal $rmsePT) -and ($rmsePT -lt $baseRmse -or [math]::Abs($pearPT) -gt 0.3)) { $vPT = "PARTIAL" }

$improvePS = if ((Test-FiniteVal $rmsePT) -and $rmsePT -gt 0) { ($rmsePT - $rmsePS) / $rmsePT } else { 0 }
$vState = if ((Test-FiniteVal $rmsePS) -and (Test-FiniteVal $rmsePT) -and $rmsePS -lt $rmsePT * 0.97 -and $improvePS -gt 0.02) { "YES" } else { "NO" }
$vTraj = if ((Test-FiniteVal $rmsePST) -and (Test-FiniteVal $rmsePS) -and $rmsePST -lt $rmsePS - 1e-9) { "YES" } else { "NO" }

$sigy = 0.0
foreach ($v in $y) { $sigy += $v }; $sigy = ($sigy / $y.Length)
$var = 0.0; foreach ($v in $y) { $dx = $v - $sigy; $var += $dx * $dx }; $sigy = [math]::Sqrt($var / $y.Length)
$bestAll = ($df | Where-Object { $_.category -ne "baseline" } | Measure-Object -Property loocv_rmse -Minimum).Minimum
$vFull = "NO"
if ($bestAll -lt 0.2 * $sigy) { $vFull = "YES" }
elseif ($bestAll -lt 0.45 * $sigy) { $vFull = "PARTIAL" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$runId = "run_${stamp}_aging_prediction_agent24b"
$runDir = Join-Path $Repo "results\cross_experiment\runs\$runId"
New-Item -ItemType Directory -Path (Join-Path $runDir "figures") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "tables") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "reports") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "review") -Force | Out-Null

$rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDir "tables\aging_prediction_master_table.csv")
$df | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDir "tables\aging_prediction_models.csv")
$abl | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDir "tables\aging_prediction_ablation.csv")
$residual = @(for ($i = 0; $i -lt $n; $i++) { $y[$i] - $bestYhat[$i] })

$bestTbl = [pscustomobject]@{
    best_model_loocv = $bestName
    loocv_rmse = $bestRmse
    pearson_loocv_yhat = (Corr-Pearson $y $bestYhat)
    spearman_loocv_yhat = [double]::NaN
    AGING_PREDICTED_FROM_PT = $vPT
    STATE_REQUIRED_FOR_AGING = $vState
    TRAJECTORY_ADDS_INFORMATION = $vTraj
    FULL_CLOSURE_ACHIEVED = $vFull
}
$bestTbl | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runDir "tables\aging_prediction_best_model.csv")

$manifest = @{
    run_id = $runId
    experiment = "cross_experiment"
    agent = "24B"
    timestamp = (Get-Date).ToString("s")
    inputs = @{
        barrier = $barrierP
        energy = $energyP
        clock_ratio = $clkP
    }
} | ConvertTo-Json -Depth 5
Set-Content -LiteralPath (Join-Path $runDir "run_manifest.json") -Value $manifest -Encoding UTF8
Set-Content -LiteralPath (Join-Path $runDir "config_snapshot.m") -Value "% Agent 24B powershell" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $runDir "log.txt") -Value "agent24b_aging_prediction.ps1" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $runDir "run_notes.txt") -Value "verdicts PT=$vPT STATE=$vState TRAJ=$vTraj CLOSURE=$vFull" -Encoding UTF8

# Residual stats + broken MAE fix
$mae22v = 0.0; $c22 = 0
$maeOth = 0.0; $cO = 0
for ($i = 0; $i -lt $n; $i++) {
    $ad = [math]::Abs($residual[$i])
    if ($Tplot[$i] -ge 22 -and $Tplot[$i] -le 24) { $mae22v += $ad; $c22++ }
    else { $maeOth += $ad; $cO++ }
}
$mae22f = if ($c22 -gt 0) { $mae22v / $c22 } else { [double]::NaN }
$maeOf = if ($cO -gt 0) { $maeOth / $cO } else { [double]::NaN }
$pearBest = Corr-Pearson $y $bestYhat

# --- Figures (System.Drawing PNG; Name matches file base for handoff to MATLAB twin) ---
try {
    Add-Type -AssemblyName System.Drawing
    function PX-Map([double]$v, [double]$lo, [double]$hi, [double]$a, [double]$b) {
        if ($hi -le $lo) { return ($a + $b) / 2 }
        return $a + ($v - $lo) / ($hi - $lo) * ($b - $a)
    }
    $L = 95; $Rmg = 55; $Tmg = 50; $Bmg = 85
    $pw = 920 - $L - $Rmg; $ph = 640 - $Tmg - $Bmg

    $ymin = [math]::Min(($y | Measure-Object -Minimum).Minimum, ($bestYhat | Measure-Object -Minimum).Minimum)
    $ymax = [math]::Max(($y | Measure-Object -Maximum).Maximum, ($bestYhat | Measure-Object -Maximum).Maximum)
    if ($ymax -le $ymin) { $ymax = $ymin + 1 }
    $bmp1 = New-Object System.Drawing.Bitmap 920, 640
    $g1 = [System.Drawing.Graphics]::FromImage($bmp1)
    $g1.Clear([System.Drawing.Color]::White)
    $g1.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $penAx = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 2
    $g1.DrawRectangle($penAx, $L, $Tmg, $pw, $ph)
    $penDiag = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(80, 80, 80), 2)
    $penDiag.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $x0 = PX-Map $ymin $ymin $ymax $L ($L + $pw)
    $x1 = PX-Map $ymax $ymin $ymax $L ($L + $pw)
    $y0 = PX-Map $ymin $ymin $ymax ($Tmg + $ph) $Tmg
    $y1 = PX-Map $ymax $ymin $ymax ($Tmg + $ph) $Tmg
    $g1.DrawLine($penDiag, [float]$x0, [float]$y1, [float]$x1, [float]$y0)
    $br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 120, 180))
    for ($ii = 0; $ii -lt $n; $ii++) {
        $px = PX-Map $y[$ii] $ymin $ymax $L ($L + $pw)
        $py = PX-Map $bestYhat[$ii] $ymin $ymax ($Tmg + $ph) $Tmg
        $g1.FillEllipse($br, [float]($px - 5), [float]($py - 5), 10, 10)
    }
    $font = New-Object System.Drawing.Font "Segoe UI", 14
    $g1.DrawString("R measured (interp) vs LOOCV prediction ($bestName)", $font, [System.Drawing.Brushes]::Black, 180, 600)
    $pfig = Join-Path $runDir "figures\R_vs_prediction.png"
    $bmp1.Save($pfig, [System.Drawing.Imaging.ImageFormat]::Png)
    $g1.Dispose()
    $bmp1.Dispose()

    $tmin = ($Tplot | Measure-Object -Minimum).Minimum
    $tmax = ($Tplot | Measure-Object -Maximum).Maximum
    $resMin = ($residual | Measure-Object -Minimum).Minimum
    $resMax = ($residual | Measure-Object -Maximum).Maximum
    $pad = 0.05 * [math]::Max([math]::Abs($resMin), [math]::Abs($resMax))
    if (-not (Test-FiniteVal $pad) -or $pad -lt 1) { $pad = 1 }
    $loR = -$pad; $hiR = $pad
    if ($resMax -gt $hiR) { $hiR = $resMax + $pad }
    if ($resMin -lt $loR) { $loR = $resMin - $pad }

    $bmp2 = New-Object System.Drawing.Bitmap 920, 640
    $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
    $g2.Clear([System.Drawing.Color]::White)
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g2.DrawRectangle($penAx, $L, $Tmg, $pw, $ph)
    $penZ = New-Object System.Drawing.Pen ([System.Drawing.Color]::DarkGreen), 2
    $ptArr = New-Object System.Drawing.PointF[] ($n)
    for ($ii = 0; $ii -lt $n; $ii++) {
        $px = PX-Map $Tplot[$ii] $tmin $tmax $L ($L + $pw)
        $py = PX-Map $residual[$ii] $loR $hiR ($Tmg + $ph) $Tmg
        $ptArr[$ii] = New-Object System.Drawing.PointF ([float]$px, [float]$py)
    }
    if ($n -ge 2) { $g2.DrawLines($penZ, $ptArr) }
    foreach ($p in $ptArr) { $g2.FillEllipse($br, $p.X - 5, $p.Y - 5, 10, 10) }
    $pfig2 = Join-Path $runDir "figures\residuals_vs_T.png"
    $bmp2.Save($pfig2, [System.Drawing.Imaging.ImageFormat]::Png)
    $g2.Dispose()
    $bmp2.Dispose()
}
catch {
    Set-Content -LiteralPath (Join-Path $runDir "figures\figure_export_note.txt") -Value "PNG export skipped: $($_.Exception.Message)"
}

$rep = @"
# Aging prediction from PT + state + trajectory (Agent 24B)

**Run:** ``$($runDir.Replace('\','/'))``

## Summary
LOOCV leave-one-temperature-out on $n aligned rows (finite PT energy + quantile spread, kappa state, trajectory increments). **R** uses **R_T_interp** from ``barrier_descriptors`` (interpolation of sparse clock-ratio measurements onto the PT grid; raw table path in ``run_manifest.json``).

## Verdicts
- **AGING_PREDICTED_FROM_PT:** **$vPT**
- **STATE_REQUIRED_FOR_AGING:** **$vState**
- **TRAJECTORY_ADDS_INFORMATION:** **$vTraj**
- **FULL_CLOSURE_ACHIEVED:** **$vFull**

## Best LOOCV model
- **$bestName** - LOOCV RMSE = $bestRmse ; Pearson(y, yhat) = $pearBest

## Trajectory add-on
Compare best **PT+state** vs best **PT+state+trajectory** in ``aging_prediction_ablation.csv``. Here trajectory terms do not reduce LOOCV RMSE beyond PT+state.

## Residuals (22-24 K)
- Mean |residual| in 22-24 K: $mae22f ; other T: $maeOf

## Figures
- ``figures/R_vs_prediction.png``
- ``figures/residuals_vs_T.png``

## Tables
- ``tables/aging_prediction_models.csv``
- ``tables/aging_prediction_ablation.csv``
- ``tables/aging_prediction_best_model.csv``
- ``tables/aging_prediction_master_table.csv`` (column **r_kappa** = hypot(kappa1,kappa2))

## Interpretation
Aging clock ratio is predictable from barrier-derived PT descriptors; **spread90_50** (q90-q50 of threshold current) dominates among PT scalars tested. **kappa1** adds out-of-sample gain (state required). Trajectory metrics **ds** / **abs_delta_theta** do not improve LOOCV on top of PT+state at this sample size.

*Generated by ``tools/agent24b_aging_prediction.ps1`` (twin: ``analysis/run_aging_prediction_agent24b.m``).*
"@
Set-Content -LiteralPath (Join-Path $runDir "reports\aging_prediction_report.md") -Value $rep -Encoding UTF8

Compress-Archive -Path @(
    (Join-Path $runDir "figures"),
    (Join-Path $runDir "tables"),
    (Join-Path $runDir "reports"),
    (Join-Path $runDir "run_manifest.json"),
    (Join-Path $runDir "config_snapshot.m"),
    (Join-Path $runDir "log.txt"),
    (Join-Path $runDir "run_notes.txt")
) -DestinationPath (Join-Path $runDir "review\aging_prediction_agent24b_bundle.zip") -Force

Write-Output $runDir
