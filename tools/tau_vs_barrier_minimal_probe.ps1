$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\Dev\matlab-functions'

$agingCsv = Join-Path $repoRoot 'results\aging\runs\run_2026_03_12_223709_aging_timescale_extraction\tables\tau_vs_Tp.csv'
$ptCsv = Join-Path $repoRoot 'results\switching\runs\run_2026_03_25_013356_pt_robust_canonical\tables\PT_summary.csv'

$outCsv = Join-Path $repoRoot 'tables\tau_vs_barrier_test.csv'
$outMd = Join-Path $repoRoot 'reports\tau_vs_barrier_report.md'

function Test-FiniteDouble([double]$x) {
  return -not [double]::IsNaN($x) -and -not [double]::IsInfinity($x)
}

function PearsonR([double[]]$a, [double[]]$b) {
  $n = $a.Length
  $meanA = ($a | Measure-Object -Average).Average
  $meanB = ($b | Measure-Object -Average).Average
  $num = 0.0
  $denA = 0.0
  $denB = 0.0
  for ($i=0; $i -lt $n; $i++) {
    $da = $a[$i] - $meanA
    $db = $b[$i] - $meanB
    $num += $da * $db
    $denA += $da * $da
    $denB += $db * $db
  }
  $den = [Math]::Sqrt($denA * $denB)
  if ($den -eq 0.0) { return [double]::NaN }
  return $num / $den
}

function SpearmanR([double[]]$a, [double[]]$b) {
  function RankData([double[]]$x) {
    $n = $x.Length
    $idx = 0..($n-1)
    $pairs = $idx | ForEach-Object { [pscustomobject]@{ v=$x[$_]; i=$_ } } | Sort-Object v
    $ranks = New-Object 'double[]' $n
    $tol = 1e-12
    $pos = 0
    while ($pos -lt $n) {
      $v0 = [double]$pairs[$pos].v
      $start = $pos
      while ($pos -lt $n -and ([Math]::Abs([double]$pairs[$pos].v - $v0) -le $tol)) {
        $pos++
      }
      $end = $pos - 1
      # Ranks are 1..n; average for ties
      $avgRank = (($start + 1) + ($end + 1)) / 2.0
      for ($k=$start; $k -le $end; $k++) {
        $ranks[[int]$pairs[$k].i] = $avgRank
      }
    }
    return ,$ranks
  }

  $ra = RankData $a
  $rb = RankData $b
  return PearsonR $ra $rb
}

function Solve-3x3([double[,] ]$A, [double[]]$b) {
  # Gaussian elimination on augmented 3x4 using nested arrays for indexing.
  $M = @(
    @($A[0,0], $A[0,1], $A[0,2], $b[0]),
    @($A[1,0], $A[1,1], $A[1,2], $b[1]),
    @($A[2,0], $A[2,1], $A[2,2], $b[2])
  )

  for ($p=0; $p -lt 3; $p++) {
    $pivot = [double]$M[$p][$p]
    if ([Math]::Abs($pivot) -lt 1e-15) {
      for ($r=$p+1; $r -lt 3; $r++) {
        if ([Math]::Abs([double]$M[$r][$p]) -gt 1e-15) {
          $tmp = $M[$p]
          $M[$p] = $M[$r]
          $M[$r] = $tmp
          $pivot = [double]$M[$p][$p]
          break
        }
      }
    }

    if ([Math]::Abs($pivot) -lt 1e-15) {
      return ,@([double]::NaN, [double]::NaN, [double]::NaN)
    }

    # normalize pivot row
    for ($c=$p; $c -lt 4; $c++) {
      $M[$p][$c] = [double]$M[$p][$c] / $pivot
    }

    # eliminate other rows
    for ($r=0; $r -lt 3; $r++) {
      if ($r -eq $p) { continue }
      $factor = [double]$M[$r][$p]
      for ($c=$p; $c -lt 4; $c++) {
        $M[$r][$c] = [double]$M[$r][$c] - $factor * [double]$M[$p][$c]
      }
    }
  }

  return ,@([double]$M[0][3], [double]$M[1][3], [double]$M[2][3])
}

function RMSE([double[]]$a, [double[]]$b) {
  $n = $a.Length
  $s = 0.0
  for ($i=0; $i -lt $n; $i++) {
    $d = $a[$i] - $b[$i]
    $s += $d * $d
  }
  return [Math]::Sqrt($s / $n)
}

# Coerce scalar-like values into a single [double].
# Import-Csv / array handling can occasionally yield 1-element arrays; for regression we need strict scalars.
function ScalarDouble($v) {
  $cur = $v
  $guard = 0
  while ($cur -is [System.Array] -and $guard -lt 20) {
    if ($cur.Length -lt 1) { return [double]::NaN }
    $cur = $cur[0]
    $guard++
  }
  if ($cur -is [System.Array]) { return [double]::NaN }
  return [double]$cur
}

# Load CSVs
$aging = Import-Csv $agingCsv
$pt = Import-Csv $ptCsv

if (-not ($aging[0].PSObject.Properties.Name -contains 'tau_effective_seconds')) {
  throw "Expected column tau_effective_seconds in aging csv."
}
if (-not ($aging[0].PSObject.Properties.Name -contains 'Tp')) {
  throw "Expected column Tp in aging csv."
}

if (-not ($pt[0].PSObject.Properties.Name -contains 'mean_threshold_mA') -or -not ($pt[0].PSObject.Properties.Name -contains 'std_threshold_mA')) {
  throw "Expected mean_threshold_mA/std_threshold_mA in PT_summary csv."
}
if (-not ($pt[0].PSObject.Properties.Name -contains 'T_K')) {
  throw "Expected column T_K in PT_summary csv."
}

# PT lookup by integer temperature
$ptMap = @{}
foreach ($row in $pt) {
  $T = [int][double]$row.T_K
  $meanRaw = $row.mean_threshold_mA
  $stdRaw = $row.std_threshold_mA
  $guard = 0
  while (($meanRaw -is [System.Array]) -and $guard -lt 20) { if ($meanRaw.Length -lt 1) { $meanRaw = [double]::NaN; break }; $meanRaw = $meanRaw[0]; $guard++ }
  $guard = 0
  while (($stdRaw -is [System.Array]) -and $guard -lt 20) { if ($stdRaw.Length -lt 1) { $stdRaw = [double]::NaN; break }; $stdRaw = $stdRaw[0]; $guard++ }
  $mean = [double]$meanRaw
  $std = [double]$stdRaw
  $ptMap[$T.ToString()] = @{ mean=$mean; std=$std }
}

$yList = New-Object 'System.Collections.Generic.List[double]'
$meanEList = New-Object 'System.Collections.Generic.List[double]'
$stdEList = New-Object 'System.Collections.Generic.List[double]'
$TList = New-Object 'System.Collections.Generic.List[double]'

foreach ($row in $aging) {
  $T = [int][double]$row.Tp
  $key = $T.ToString()
  if (-not $ptMap.ContainsKey($key)) { continue }
  $tau = [double]$row.tau_effective_seconds
  if (-not (Test-FiniteDouble $tau)) { continue }
  if ($tau -le 0.0) { continue }
  $logTau = [Math]::Log($tau)
  if (-not (Test-FiniteDouble $logTau)) { continue }
  $meanRaw = $ptMap[$key].mean
  $stdRaw = $ptMap[$key].std
  $guard = 0
  while (($meanRaw -is [System.Array]) -and $guard -lt 20) { if ($meanRaw.Length -lt 1) { $meanRaw = [double]::NaN; break }; $meanRaw = $meanRaw[0]; $guard++ }
  $guard = 0
  while (($stdRaw -is [System.Array]) -and $guard -lt 20) { if ($stdRaw.Length -lt 1) { $stdRaw = [double]::NaN; break }; $stdRaw = $stdRaw[0]; $guard++ }
  $mean = [double]$meanRaw
  $std = [double]$stdRaw
  if (-not (Test-FiniteDouble $mean) -or -not (Test-FiniteDouble $std)) { continue }
  $yList.Add($logTau) | Out-Null
  $meanEList.Add($mean) | Out-Null
  $stdEList.Add($std) | Out-Null
  $TList.Add([double]$T) | Out-Null
}

$n = $yList.Count
if ($n -lt 3) { throw "Not enough joined points after finite filtering: n=$n" }

$y = $yList.ToArray()
$meanE = $meanEList.ToArray()
$stdE = $stdEList.ToArray()

# Baseline LOOCV
$baselinePred = New-Object 'double[]' $n
$sumY = ($y | Measure-Object -Sum).Sum
for ($i=0; $i -lt $n; $i++) {
  $baselinePred[$i] = ($sumY - $y[$i]) / ($n - 1)
}
$baselineRmse = RMSE $y $baselinePred
$baselinePear = PearsonR $y $baselinePred
$baselineSpearman = SpearmanR $y $baselinePred

# LOOCV model helpers
function LOOCV-Linear1([double[]]$x, [double[]]$yArr) {
  $nloc = $yArr.Length
  $pred = New-Object 'double[]' $nloc
  for ($i=0; $i -lt $nloc; $i++) {
    $mx = 0.0; $my = 0.0
    for ($j=0; $j -lt $nloc; $j++) {
      if ($j -eq $i) { continue }
      $mx = [double]($mx + (ScalarDouble $x[$j]))
      $my = [double]($my + (ScalarDouble $yArr[$j]))
    }
    $mx /= ($nloc - 1)
    $my /= ($nloc - 1)
    $num = 0.0; $den = 0.0
    for ($j=0; $j -lt $nloc; $j++) {
      if ($j -eq $i) { continue }
      $dx = (ScalarDouble $x[$j]) - $mx
      $dy = (ScalarDouble $yArr[$j]) - $my
      $num += $dx * $dy
      $den += $dx * $dx
    }
    $b = if ($den -eq 0.0) { 0.0 } else { $num / $den }
    $a = $my - $b * $mx
    $pred[$i] = $a + $b * (ScalarDouble $x[$i])
  }
  return ,$pred
}

function LOOCV-Linear2($x1, $x2, $yArr) {
  $nloc = $yArr.Length
  $pred = New-Object 'double[]' $nloc

  # Flatten to strict 1D doubles once (avoids nested-array coercion surprises inside loops).
  $x1c = New-Object 'double[]' $nloc
  $x2c = New-Object 'double[]' $nloc
  $yc = New-Object 'double[]' $nloc
  for ($k=0; $k -lt $nloc; $k++) {
    $cur = $x1[$k]; $guard = 0
    while (($cur -is [System.Array]) -and $guard -lt 20) { if ($cur.Length -lt 1) { $cur = [double]::NaN; break }; $cur = $cur[0]; $guard++ }
    $x1c[$k] = [double]$cur

    $cur = $x2[$k]; $guard = 0
    while (($cur -is [System.Array]) -and $guard -lt 20) { if ($cur.Length -lt 1) { $cur = [double]::NaN; break }; $cur = $cur[0]; $guard++ }
    $x2c[$k] = [double]$cur

    $cur = $yArr[$k]; $guard = 0
    while (($cur -is [System.Array]) -and $guard -lt 20) { if ($cur.Length -lt 1) { $cur = [double]::NaN; break }; $cur = $cur[0]; $guard++ }
    $yc[$k] = [double]$cur
  }

  for ($i=0; $i -lt $nloc; $i++) {
    $nTrain = $nloc - 1
    $sumY = [double]0.0; $sumX1 = [double]0.0; $sumX2 = [double]0.0
    $sumX1sq = [double]0.0; $sumX2sq = [double]0.0; $sumX1X2 = [double]0.0
    $sumX1Y = [double]0.0; $sumX2Y = [double]0.0

    for ($j=0; $j -lt $nloc; $j++) {
      if ($j -eq $i) { continue }
      $X1 = $x1c[$j]
      $X2 = $x2c[$j]
      $Yv = $yc[$j]
      $sumY += $Yv
      $sumX1 += $X1
      $sumX2 += $X2
      $sumX1sq += $X1*$X1
      $sumX2sq += $X2*$X2
      $sumX1X2 += $X1*$X2
      $sumX1Y += $X1*$Yv
      $sumX2Y += $X2*$Yv
    }

    # Normal equations for beta = [a; b1; b2]
    $A = New-Object 'double[,]' 3,3
    $A[0,0] = [double]$nTrain; $A[0,1] = $sumX1; $A[0,2] = $sumX2
    $A[1,0] = $sumX1;         $A[1,1] = $sumX1sq; $A[1,2] = $sumX1X2
    $A[2,0] = $sumX2;         $A[2,1] = $sumX1X2; $A[2,2] = $sumX2sq
    $bvec = @($sumY, $sumX1Y, $sumX2Y)

    $beta = Solve-3x3 $A $bvec
    $a = [double]$beta[0]; $b1 = [double]$beta[1]; $b2 = [double]$beta[2]
    $pred[$i] = $a + $b1*$x1c[$i] + $b2*$x2c[$i]
  }

  return ,$pred
}

$pred1 = LOOCV-Linear1 $meanE $y
$pred2 = LOOCV-Linear1 $stdE $y
$pred3 = LOOCV-Linear2 $meanE $stdE $y

$models = @(
  [pscustomobject]@{ model='log_tau ~ mean_E'; predictors='mean_E'; n_T=$n; pred=$pred1 },
  [pscustomobject]@{ model='log_tau ~ std_E'; predictors='std_E'; n_T=$n; pred=$pred2 },
  [pscustomobject]@{ model='log_tau ~ mean_E + std_E'; predictors='mean_E,std_E'; n_T=$n; pred=$pred3 }
)

foreach ($m in $models) {
  $m | Add-Member -NotePropertyName LOOCV_RMSE -NotePropertyValue (RMSE $y $m.pred) -Force
  $m | Add-Member -NotePropertyName Pearson_r -NotePropertyValue (PearsonR $y $m.pred) -Force
  $m | Add-Member -NotePropertyName Spearman_r -NotePropertyValue (SpearmanR $y $m.pred) -Force
}

$best = ($models | Sort-Object LOOCV_RMSE | Select-Object -First 1)
$bestAbsPear = [Math]::Abs([double]$best.Pearson_r)
$bestRmse = [double]$best.LOOCV_RMSE
$rmseImproveFrac = if ($baselineRmse -ne 0.0) { ($baselineRmse - $bestRmse)/$baselineRmse } else { 0.0 }

if ($bestAbsPear -ge 0.7 -and $bestRmse -le $baselineRmse * 0.85) {
  $decision = 'YES'
} elseif ($bestAbsPear -ge 0.35 -or $rmseImproveFrac -gt 0.05) {
  $decision = 'PARTIAL'
} else {
  $decision = 'NO'
}

# Write CSV output
$dirTables = Split-Path $outCsv -Parent
if (-not (Test-Path $dirTables)) { New-Item -ItemType Directory -Path $dirTables | Out-Null }

$header = 'model,predictors,n_T,LOOCV_RMSE,Pearson_r,Spearman_r,baseline_LOOCV_RMSE,delta_RMSE_vs_baseline'
$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add($header) | Out-Null

function Round6([double]$x) { return [Math]::Round($x, 6) }

$baselineDelta = 0.0
$lines.Add(("baseline (LOOCV mean of log_tau),{0},{1},{2},{3},{4},{5},{6}" -f '(constant)',$n, (Round6 $baselineRmse), (Round6 $baselinePear), (Round6 $baselineSpearman), (Round6 $baselineRmse), (Round6 $baselineDelta))) | Out-Null

foreach ($m in $models) {
  $delta = [double]$m.LOOCV_RMSE - [double]$baselineRmse
  $lines.Add(("{0},{1},{2},{3},{4},{5},{6},{7}" -f $m.model,$m.predictors,$m.n_T, (Round6 ([double]$m.LOOCV_RMSE)), (Round6 ([double]$m.Pearson_r)), (Round6 ([double]$m.Spearman_r)), (Round6 ([double]$baselineRmse)), (Round6 ([double]$delta)))) | Out-Null
}

Set-Content -Path $outCsv -Value ($lines -join "`n") -Encoding UTF8

# Write markdown report (short interpretation <= 10 lines)
$dirReports = Split-Path $outMd -Parent
if (-not (Test-Path $dirReports)) { New-Item -ItemType Directory -Path $dirReports | Out-Null }

$reportLines = @(
  '# tau vs barrier landscape (minimal probe)',
  '',
  "TAU_LINKED_TO_PT: $decision",
  "Joined n_T=$n finite temperature points.",
  ("Baseline LOOCV RMSE={0}." -f ([Math]::Round($baselineRmse,6))),
  ("Best model={0} with LOOCV RMSE={1}." -f $best.model, ([Math]::Round($bestRmse,6))),
  ("Best Pearson |r|={0} (Spearman r={1})." -f ([Math]::Round($bestAbsPear,6)), ([Math]::Round([double]$best.Spearman_r,6))),
  ("RMSE improvement vs baseline={0}%." -f ([Math]::Round(($rmseImproveFrac*100.0),3)))
)

Set-Content -Path $outMd -Value ($reportLines -join "`n") -Encoding UTF8

Write-Output "DONE. Decision=$decision. Wrote:"
Write-Output $outCsv
Write-Output $outMd

