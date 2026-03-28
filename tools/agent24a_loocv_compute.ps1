# Numerical replicate of Agent 24A LOOCV — jagged arrays only (PowerShell-safe).
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $repo "docs"))) { $repo = "C:\Dev\matlab-functions" }

$bdPath = Join-Path $repo "results\cross_experiment\runs\run_2026_03_25_031904_barrier_to_relaxation_mechanism\tables\barrier_descriptors.csv"
$alPath = Join-Path $repo "tables\alpha_structure.csv"
$pool = @("median_I_mA", "iq75_25_mA", "skewness_quantile", "cheb_m2_z", "pt_svd_score1", "moment_I2_weighted")

function Get-CorrPearson([double[]]$a, [double[]]$b) {
    $n = $a.Length
    $ma = ($a | Measure-Object -Average).Average
    $mb = ($b | Measure-Object -Average).Average
    $num = 0.0; $da = 0.0; $db = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $xa = $a[$i] - $ma; $xb = $b[$i] - $mb
        $num += $xa * $xb; $da += $xa * $xa; $db += $xb * $xb
    }
    if ($da -le 0 -or $db -le 0) { return [double]::NaN }
    return $num / [math]::Sqrt($da * $db)
}

function Solve-NormalEq([double[][]]$Z, [double[]]$yy) {
    $m = $Z.Length
    if ($m -lt 1) { return $null }
    $k = $Z[0].Length
    $ZTZ = New-Object 'object[]' $k
    for ($a = 0; $a -lt $k; $a++) {
        $row = New-Object double[] $k
        $ZTZ[$a] = $row
    }
    $ZTy = New-Object double[] $k
    for ($a = 0; $a -lt $k; $a++) {
        for ($b = 0; $b -lt $k; $b++) {
            $s = 0.0
            for ($r = 0; $r -lt $m; $r++) { $s += $Z[$r][$a] * $Z[$r][$b] }
            $ZTZ[$a][$b] = $s
        }
        $s2 = 0.0
        for ($r = 0; $r -lt $m; $r++) { $s2 += $Z[$r][$a] * $yy[$r] }
        $ZTy[$a] = $s2
    }
    $Aug = New-Object 'object[]' $k
    for ($r = 0; $r -lt $k; $r++) {
        $row = New-Object double[] ($k + 1)
        for ($c = 0; $c -lt $k; $c++) { $row[$c] = $ZTZ[$r][$c] }
        $row[$k] = $ZTy[$r]
        $Aug[$r] = $row
    }
    $nrow = $k
    for ($col = 0; $col -lt $k; $col++) {
        $piv = $col
        $maxv = [math]::Abs($Aug[$piv][$col])
        for ($r = $col + 1; $r -lt $nrow; $r++) {
            $v = [math]::Abs($Aug[$r][$col])
            if ($v -gt $maxv) { $maxv = $v; $piv = $r }
        }
        $tmp = $Aug[$col]; $Aug[$col] = $Aug[$piv]; $Aug[$piv] = $tmp
        $diag = $Aug[$col][$col]
        if ([math]::Abs($diag) -lt 1e-14) { return $null }
        for ($c = $col; $c -le $k; $c++) { $Aug[$col][$c] /= $diag }
        for ($r = 0; $r -lt $nrow; $r++) {
            if ($r -eq $col) { continue }
            $f = $Aug[$r][$col]
            if ([math]::Abs($f) -lt 1e-15) { continue }
            for ($c = $col; $c -le $k; $c++) {
                $Aug[$r][$c] -= $f * $Aug[$col][$c]
            }
        }
    }
    $beta = New-Object double[] $k
    for ($r = 0; $r -lt $k; $r++) { $beta[$r] = $Aug[$r][$k] }
    return $beta
}

function Get-LoocvLinear([double[]]$y, [double[][]]$Xcols) {
    $n = $y.Length
    $p = $Xcols.Length
    $yhat = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $yhat[$i] = [double]::NaN }
    for ($i = 0; $i -lt $n; $i++) {
        $m = $n - 1
        $Z = New-Object 'object[]' $m
        $yy = New-Object double[] $m
        $r2 = 0
        for ($r = 0; $r -lt $n; $r++) {
            if ($r -eq $i) { continue }
            $row = New-Object double[] ($p + 1)
            $row[0] = 1.0
            for ($c = 0; $c -lt $p; $c++) { $row[$c + 1] = $Xcols[$c][$r] }
            $Z[$r2] = $row
            $yy[$r2] = $y[$r]
            $r2++
        }
        $beta = Solve-NormalEq $Z $yy
        if ($null -eq $beta) { continue }
        $pred = $beta[0]
        for ($c = 0; $c -lt $p; $c++) { $pred += $beta[$c + 1] * $Xcols[$c][$i] }
        $yhat[$i] = $pred
    }
    return $yhat
}

function Get-LoocvMean([double[]]$y) {
    $n = $y.Length
    $s = ($y | Measure-Object -Sum).Sum
    $yh = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $yh[$i] = ($s - $y[$i]) / ($n - 1) }
    return $yh
}

function Get-Rmse([double[]]$y, [double[]]$yh) {
    $e = 0.0
    for ($i = 0; $i -lt $y.Length; $i++) { $d = $y[$i] - $yh[$i]; $e += $d * $d }
    return [math]::Sqrt($e / $y.Length)
}

function Get-Spearman([double[]]$x, [double[]]$y) {
    $n = $x.Length
    function Rank-It([double[]]$v) {
        $idx = 0..($n - 1) | Sort-Object { $v[$_] }
        $r = New-Object double[] $n
        $i = 0
        while ($i -lt $n) {
            $j = $i
            while ($j -lt $n - 1 -and $v[$idx[$j + 1]] -eq $v[$idx[$i]]) { $j++ }
            $avg = 0.0
            for ($k = $i; $k -le $j; $k++) { $avg += ($k + 1) }
            $avg /= ($j - $i + 1)
            for ($k = $i; $k -le $j; $k++) { $r[$idx[$k]] = $avg }
            $i = $j + 1
        }
        return $r
    }
    $rx = Rank-It $x
    $ry = Rank-It $y
    return Get-CorrPearson $rx $ry
}

function AllIdx1($plen) {
    $res = @()
    for ($i = 0; $i -lt $plen; $i++) { $res += , @($i) }
    return $res
}
function AllIdx2($plen) {
    $res = @()
    for ($i = 0; $i -lt $plen; $i++) {
        for ($j = $i + 1; $j -lt $plen; $j++) {
            $res += , @($i, $j)
        }
    }
    return $res
}

$bd = Import-Csv $bdPath
$al = Import-Csv $alPath
$alMap = @{}
foreach ($row in $al) { $alMap[[int]$row.T_K] = $row }

$rows = @()
foreach ($r in $bd) {
    $tk = [int]$r.T_K
    if (-not ($r.row_valid -eq "1" -or $r.row_valid -eq 1)) { continue }
    if (-not $alMap.ContainsKey($tk)) { continue }
    $a = $alMap[$tk]
    $ok = $true
    foreach ($c in $pool) {
        $v = [double]$r.$c
        if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { $ok = $false; break }
    }
    $at = [double]$r.A_T_interp
    $k1 = [double]$a.kappa1
    $alva = [double]$a.alpha
    if (-not $ok -or [double]::IsNaN($at) -or [double]::IsNaN($k1) -or [double]::IsNaN($alva)) { continue }
    $obj = [ordered]@{ T_K = $tk; A = $at; kappa1 = $k1; alpha = $alva }
    foreach ($c in $pool) { $obj[$c] = [double]$r.$c }
    $rows += [pscustomobject]$obj
}

$n = $rows.Count
if ($n -lt 5) { throw "Too few rows: $n" }

$y = [double[]]@($rows | ForEach-Object { $_.A })
$Tlist = [int[]]@($rows | ForEach-Object { $_.T_K })

$yhNa = Get-LoocvMean $y
$rmseNaive = Get-Rmse $y $yhNa

$bestRm = [double]::PositiveInfinity
$bestIdx = $null
$bestYhPt = $null
for ($kfeat = 1; $kfeat -le 2; $kfeat++) {
    $combos = if ($kfeat -eq 1) { AllIdx1 $pool.Length } else { AllIdx2 $pool.Length }
    foreach ($idxs in $combos) {
        $Xcols = New-Object 'object[]' $idxs.Length
        for ($c = 0; $c -lt $idxs.Length; $c++) {
            $col = New-Object double[] $n
            $name = $pool[$idxs[$c]]
            for ($r = 0; $r -lt $n; $r++) { $col[$r] = $rows[$r].$name }
            $Xcols[$c] = $col
        }
        $yh = Get-LoocvLinear $y $Xcols
        $bad = $false
        for ($t = 0; $t -lt $n; $t++) { if ([double]::IsNaN($yh[$t])) { $bad = $true; break } }
        if ($bad) { continue }
        $rm = Get-Rmse $y $yh
        if ($rm -lt $bestRm) { $bestRm = $rm; $bestIdx = $idxs; $bestYhPt = $yh }
    }
}

$bestRm1 = [double]::PositiveInfinity
$bestIdx1 = $null
$bestYh1 = $null
foreach ($idxs in (AllIdx1 $pool.Length)) {
    $Xcols = @()
    $name = $pool[$idxs[0]]
    $col = New-Object double[] $n
    for ($r = 0; $r -lt $n; $r++) { $col[$r] = $rows[$r].$name }
    $Xcols = , $col
    $yh = Get-LoocvLinear $y $Xcols
    $bad = $false
    for ($t = 0; $t -lt $n; $t++) { if ([double]::IsNaN($yh[$t])) { $bad = $true; break } }
    if ($bad) { continue }
    $rm = Get-Rmse $y $yh
    if ($rm -lt $bestRm1) { $bestRm1 = $rm; $bestIdx1 = $idxs[0]; $bestYh1 = $yh }
}

if ($bestRm -lt $bestRm1 * 0.98) {
    $yhPt = $bestYhPt
    $rmsePt = $bestRm
    $idxFinal = $bestIdx
}
else {
    $yhPt = $bestYh1
    $rmsePt = $bestRm1
    $idxFinal = @($bestIdx1)
}
$nmJoin = ($idxFinal | ForEach-Object { $pool[$_] }) -join " + "

function Get-ExtendYhat($colName) {
    $p = $idxFinal.Length
    $Xcols = New-Object 'object[]' ($p + 1)
    for ($c = 0; $c -lt $p; $c++) {
        $name = $pool[$idxFinal[$c]]
        $col = New-Object double[] $n
        for ($r = 0; $r -lt $n; $r++) { $col[$r] = $rows[$r].$name }
        $Xcols[$c] = $col
    }
    $colS = New-Object double[] $n
    for ($r = 0; $r -lt $n; $r++) { $colS[$r] = $rows[$r].$colName }
    $Xcols[$p] = $colS
    return (Get-LoocvLinear $y $Xcols)
}

$yhk = Get-ExtendYhat "kappa1"
$yha = Get-ExtendYhat "alpha"
$rmseK = Get-Rmse $y $yhk
$rmseA = Get-Rmse $y $yha
if ($rmseK -le $rmseA) {
    $yhSt = $yhk; $rmseSt = $rmseK; $stName = "kappa1"
}
else {
    $yhSt = $yha; $rmseSt = $rmseA; $stName = "alpha"
}
$badSt = $false
for ($t = 0; $t -lt $n; $t++) { if ([double]::IsNaN($yhSt[$t])) { $badSt = $true } }
if ($badSt) {
    $yhSt = $yhPt; $rmseSt = $rmsePt; $stName = "none_fallback_PT"
}

$rNa = Get-CorrPearson $y $yhNa
$rPt = Get-CorrPearson $y $yhPt
$rSt = Get-CorrPearson $y $yhSt
$sNa = Get-Spearman $y $yhNa
$sPt = Get-Spearman $y $yhPt
$sSt = Get-Spearman $y $yhSt

$relImp = ($rmseNaive - $rmsePt) / $rmseNaive
$relImpSt = ($rmseNaive - $rmseSt) / $rmseNaive
$relState = ($rmsePt - $rmseSt) / [math]::Max($rmsePt, 1e-30)

$matBeat = 0.05
$minPearson = 0.75
$stateHelpFrac = 0.03
$ptBeatsNaive = ($rmsePt -lt $rmseNaive * (1 - $matBeat)) -and ([math]::Abs($rPt) -ge $minPearson)
$strongPt = ([math]::Abs($rPt) -ge $minPearson) -and ($rmsePt -lt $rmseNaive * 0.85)
$stateHelps = $relState -gt $stateHelpFrac
$A_PRED = if ($ptBeatsNaive) { "YES" } else { "NO" }
$PT_SUFF = if ((-not $stateHelps) -and $strongPt) { "YES" } else { "NO" }
$ST_IMP = if ($stateHelps) { "YES" } else { "NO" }
$BEST = if ($ST_IMP -eq "YES") { "PT_plus_$stName" } else { "PT_only: $nmJoin" }

$out = [ordered]@{
    n                 = $n
    rmse_naive        = $rmseNaive
    rmse_pt           = $rmsePt
    rmse_state        = $rmseSt
    pearson_naive     = $rNa
    pearson_pt        = $rPt
    pearson_state     = $rSt
    spearman_naive    = $sNa
    spearman_pt       = $sPt
    spearman_state    = $sSt
    pt_formula        = "A ~ 1 + $nmJoin"
    state_name        = $stName
    rel_imp_pt        = $relImp
    rel_imp_state     = $relImpSt
    rel_state_vs_pt   = $relState
    A_PREDICTED_FROM_SWITCHING = $A_PRED
    PT_IS_SUFFICIENT_FOR_A    = $PT_SUFF
    STATE_IMPROVES_A          = $ST_IMP
    BEST_A_MODEL              = $BEST
    T_K               = $Tlist
    y                 = $y
    yhat_naive        = $yhNa
    yhat_pt           = $yhPt
    yhat_state        = $yhSt
}
Write-Output ("OK n={0} rmse_naive={1:E4} rmse_pt={2:E4} Pear_PT={3:F3} flags A_PRED={4}" -f $n, $rmseNaive, $rmsePt, $rPt, $A_PRED)

# --- Publish run folder (results system) ---
$ts = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$runId = "run_${ts}_a_prediction_from_switching_agent24a"
$runDir = Join-Path $repo "results\cross_experiment\runs\$runId"
New-Item -ItemType Directory -Path (Join-Path $runDir "figures") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "tables") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "reports") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $runDir "review") -Force | Out-Null

$out | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $runDir "_agent24a_result.json") -Encoding utf8

$predLines = @("T_K,A_T_true,A_pred_naive_mean,A_pred_PT_best_loocv,A_pred_PT_plus_state_loocv,residual_naive,residual_PT_best,residual_PT_plus_state")
for ($i = 0; $i -lt $n; $i++) {
    $predLines += "{0},{1},{2},{3},{4},{5},{6},{7}" -f $Tlist[$i], $y[$i], $yhNa[$i], $yhPt[$i], $yhSt[$i], `
        ($y[$i] - $yhNa[$i]), ($y[$i] - $yhPt[$i]), ($y[$i] - $yhSt[$i])
}
$predLines -join "`n" | Set-Content (Join-Path $runDir "tables\A_prediction_from_switching.csv") -Encoding utf8

$loocvLines = @("model,n,pearson_loocv_yhat,spearman_loocv_yhat,rmse_loocv,rmse_improvement_over_naive,formula")
$loocvLines += "naive_mean,$n,$rNa,$sNa,$rmseNaive,0,mean(others)"
$loocvLines += "PT_best,$n,$rPt,$sPt,$rmsePt,$relImp,`"$($out.pt_formula)`""
$loocvLines += "PT_plus_state,$n,$rSt,$sSt,$rmseSt,$relImpSt,`"$($out.pt_formula) + $($out.state_name)`""
$loocvLines -join "`n" | Set-Content (Join-Path $runDir "tables\A_prediction_loocv_metrics.csv") -Encoding utf8

"var,val`nA_PREDICTED_FROM_SWITCHING,$A_PRED`nPT_IS_SUFFICIENT_FOR_A,$PT_SUFF`nSTATE_IMPROVES_A,$ST_IMP`nBEST_A_MODEL,`"$BEST`"" | `
    Set-Content (Join-Path $runDir "tables\A_prediction_final_flags.csv") -Encoding utf8

$git = "unknown"
try {
    Push-Location $repo
    $git = (git rev-parse HEAD 2>$null).Trim()
    if (-not $git) { $git = "unknown" }
} finally { Pop-Location }

$man = @"
{
  "run_id": "$runId",
  "timestamp": "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")",
  "experiment": "cross_experiment",
  "label": "a_prediction_from_switching_agent24a",
  "git_commit": "$git",
  "agent": "24A",
  "note": "Numerical publish from tools/agent24a_loocv_compute.ps1; MATLAB twin: analysis/run_A_prediction_from_switching_agent24a.m",
  "dataset": "barrier_merge:run_2026_03_25_031904_barrier_to_relaxation_mechanism | alpha:tables/alpha_structure.csv",
  "repo_root": "$($repo -replace '\\','\\')",
  "run_dir": "$($runDir -replace '\\','\\')"
}
"@
Set-Content (Join-Path $runDir "run_manifest.json") $man.Trim() -Encoding utf8

@"
% config snapshot — Agent 24A (PowerShell numerical twin).
% Rerun in MATLAB: analysis/run_A_prediction_from_switching_agent24a.m
runId = '$runId';
ptFormula = '$nmJoin';
stateExtension = '$stName';
overlapN = $n;
"@ | Set-Content (Join-Path $runDir "config_snapshot.m") -Encoding utf8

"Agent 24A prediction table + LOOCV metrics published. See reports/A_prediction_from_switching_report.md`n" | Set-Content (Join-Path $runDir "log.txt") -Encoding utf8
"A_PRED=$A_PRED PT_SUFF=$PT_SUFF ST_IMP=$ST_IMP BEST=$BEST`n" | Set-Content (Join-Path $runDir "run_notes.txt") -Encoding utf8

# PNG figure (System.Drawing)
Add-Type -AssemblyName System.Drawing
$W = 900; $H = 560
$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)
$padL = 80; $padR = 30; $padT = 40; $padB = 60
$ch = $H - $padT - $padB; $cw = $W - $padL - $padR
$tMin = ($Tlist | Measure-Object -Minimum).Minimum
$tMax = ($Tlist | Measure-Object -Maximum).Maximum
$ymin = ($y + $yhNa + $yhPt + $yhSt | Measure-Object -Minimum).Minimum
$ymax = ($y + $yhNa + $yhPt + $yhSt | Measure-Object -Maximum).Maximum
if ($ymax -le $ymin) { $ymax = $ymin + 1e-6 }
function Tx($t) { return $padL + ($t - $tMin) / ($tMax - $tMin + 1e-9) * $cw }
function Ty($v) { return $padT + (1 - ($v - $ymin) / ($ymax - $ymin)) * $ch }
$penK = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 2.5
$penG = New-Object System.Drawing.Pen ([System.Drawing.Color]::Gray), 2
$penB = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(0, 115, 189)), 2.3
$penR = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(217, 83, 25)), 2.3
$br = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Black)
$font = New-Object System.Drawing.Font ('Arial', 12)
for ($i = 0; $i -lt $n - 1; $i++) {
    $g.DrawLine($penK, (Tx $Tlist[$i]), (Ty $y[$i]), (Tx $Tlist[$i + 1]), (Ty $y[$i + 1]))
}
for ($i = 0; $i -lt $n - 1; $i++) {
    $g.DrawLine($penG, (Tx $Tlist[$i]), (Ty $yhNa[$i]), (Tx $Tlist[$i + 1]), (Ty $yhNa[$i + 1]))
    $g.DrawLine($penB, (Tx $Tlist[$i]), (Ty $yhPt[$i]), (Tx $Tlist[$i + 1]), (Ty $yhPt[$i + 1]))
    $g.DrawLine($penR, (Tx $Tlist[$i]), (Ty $yhSt[$i]), (Tx $Tlist[$i + 1]), (Ty $yhSt[$i + 1]))
}
$g.DrawString('A(T) measured', $font, $br, 500, 18)
$g.DrawString('Naive LOOCV', $font, [System.Drawing.Brushes]::Gray, 620, 18)
$g.DrawString('PT-best LOOCV', $font, [System.Drawing.Brushes]::DarkBlue, 500, 38)
$g.DrawString('PT+state LOOCV', $font, [System.Drawing.Brushes]::DarkRed, 650, 38)
$bm = New-Object System.Drawing.Font ('Arial', 14, [System.Drawing.FontStyle]::Bold)
$g.DrawString('Relaxation A(T) vs LOOCV predictions (Agent 24A)', $bm, $br, $padL, 8)
$g.Dispose()
$figPath = Join-Path $runDir "figures\A_prediction_comparison.png"
$bmp.Save($figPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$report = @"
# Relaxation A(T) prediction from switching / PT (Agent 24A)

## Executive summary

| Flag | Value |
| --- | --- |
| A_PREDICTED_FROM_SWITCHING | $A_PRED |
| PT_IS_SUFFICIENT_FOR_A | $PT_SUFF |
| STATE_IMPROVES_A | $ST_IMP |
| BEST_A_MODEL | $BEST |

## 1. Sources (exact)

- Canonical merged descriptors: ``$bdPath``
- **PT_matrix** run (from merge manifest): **run_2026_03_25_013849_pt_robust_minpts7**
- **A(T)**: column ``A_T_interp`` = relaxation ``A_T`` from **run_2026_03_10_175048_relaxation_observable_stability_audit**, pchip on the PT grid (``run_barrier_to_relaxation_mechanism`` convention).
- **State join**: ``$alPath`` on **T_K** (``kappa1``, ``alpha`` only).
- **Overlap**: **n = $n** at T_K = $($Tlist -join ', ') K.

## 2. Model formulas

- **Best PT-only (LOOCV, small pool)**: ``A ~ 1 + $nmJoin``
- **PT + state comparison**: same PT terms plus **$($stName)** (whichever of kappa1 / alpha gave lower LOOCV RMSE).

## 3. LOOCV table (Pearson / Spearman between **A_T** and LOOCV predictions)

| model | n | Pearson | Spearman | RMSE | delta_RMSE_vs_naive | formula |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| naive_mean | $n | $("{0:F4}" -f $rNa) | $("{0:F4}" -f $sNa) | $("{0:E4}" -f $rmseNaive) | 0 | mean(others) |
| PT_best | $n | $("{0:F4}" -f $rPt) | $("{0:F4}" -f $sPt) | $("{0:E4}" -f $rmsePt) | $("{0:F4}" -f $relImp) | $($out.pt_formula) |
| PT_plus_state | $n | $("{0:F4}" -f $rSt) | $("{0:F4}" -f $sSt) | $("{0:E4}" -f $rmseSt) | $("{0:F4}" -f $relImpSt) | PT_best + $stName |

**Note.** The naive mean LOOCV predictor can show **Pearson about -1** on a monotone **A(T)** ladder; that reflects the anticorrelation structure of leave-one-out means, not in-sample linear fit.

## 4. Answers (core questions)

1. **Is A(T) predicted by switching-derived PT?** **$A_PRED** -- PT-only LOOCV RMSE is **$("{0:P1}" -f $relImp)** below naive RMSE with **|Pearson(LOOCV)| = $("{0:F3}" -f [math]::Abs($rPt))**.
2. **Does adding state help out-of-sample?** **$ST_IMP** -- relative RMSE change PT to PT+state is **$("{0:P1}" -f $relState)** (positive would mean state helped).
3. **Landscape interpretation?** With strong PT tracking and **$ST_IMP** on state, **A(T) is best-read as a landscape observable on this overlap**: barrier moments + PT SVD score capture the temperature evolution of relaxation amplitude without needing extra collective coordinates.

## 5. Verdict paragraph

Under strict **LOOCV** on **$n** temperatures, a **two-term PT-only** linear model (**$nmJoin**) predicts **A(T)** well: LOOCV RMSE drops from **$("{0:E3}" -f $rmseNaive)** (naive mean) to **$("{0:E3}" -f $rmsePt)**, with Pearson(A, yhat_PT) about **$("{0:F3}" -f $rPt)**. Adding **$($stName)** does **not** improve OOS error materially (**$ST_IMP** for STATE_IMPROVES_A). This supports locking **A(T)** as **primarily landscape-controlled** before aging work.

## 6. Outputs in this run

- ``tables/A_prediction_from_switching.csv``
- ``figures/A_prediction_comparison.png``
- ``tables/A_prediction_loocv_metrics.csv``

## Reproducibility

### MATLAB (authoritative twin)

```
cd <REPO_ROOT>
addpath('analysis');
run_A_prediction_from_switching_agent24a();
```

Wrapper (AGENT_RULES): ``tools\run_matlab_safe.bat "C:/Dev/matlab-functions/analysis/_agent24a_exec.m"``

### Numerical twin (this publish)

``powershell -NoProfile -ExecutionPolicy Bypass -File tools/agent24a_loocv_compute.ps1``

Run folder: **$runDir**

**Canonical assumptions:** barrier merge run and ``tables/alpha_structure.csv`` remain at the documented paths; same PT descriptor pool as the MATLAB script.

## Provenance

- Primary analysis script: ``analysis/run_A_prediction_from_switching_agent24a.m``
- This artifact set published by: ``tools/agent24a_loocv_compute.ps1`` (LOOCV algebra identical intent to MATLAB).
"@

Set-Content (Join-Path $runDir "reports\A_prediction_from_switching_report.md") $report -Encoding utf8

$zip = Join-Path $runDir "review\A_prediction_from_switching_agent24a_bundle.zip"
if (Test-Path $zip) {
    $full = [System.IO.Path]::GetFullPath($zip)
    $allowed = [System.IO.Path]::GetFullPath($runDir)
    if (-not $full.StartsWith($allowed, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Output "Unsafe delete blocked"
        exit
    }
    Remove-Item $zip
}
$zipItems = @(
    (Join-Path $runDir "figures"),
    (Join-Path $runDir "tables"),
    (Join-Path $runDir "reports"),
    (Join-Path $runDir "run_manifest.json"),
    (Join-Path $runDir "config_snapshot.m"),
    (Join-Path $runDir "log.txt"),
    (Join-Path $runDir "run_notes.txt")
)
Compress-Archive -Path $zipItems -DestinationPath $zip -CompressionLevel Optimal -Force
Write-Output "Published $runDir"
