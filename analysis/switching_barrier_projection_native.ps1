function IsFiniteNum([double]$v) { return (-not [double]::IsNaN($v)) -and (-not [double]::IsInfinity($v)) }

function To-Doubles($rows, $name) {
    return [double[]]($rows | ForEach-Object { [double]($_.$name) })
}

function MovingAverage([double[]]$x, [int]$window) {
    $n = $x.Count
    if ($window -le 1 -or $n -le 1) { return $x }
    $half = [int][math]::Floor($window / 2)
    $y = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) {
        $lo = [math]::Max(0, $i - $half)
        $hi = [math]::Min($n - 1, $i + $half)
        $sum = 0.0; $count = 0
        for ($j = $lo; $j -le $hi; $j++) {
            if (IsFiniteNum($x[$j])) { $sum += $x[$j]; $count++ }
        }
        $y[$i] = if ($count -gt 0) { $sum / $count } else { [double]::NaN }
    }
    return $y
}

function CentralDiff([double[]]$x, [double[]]$y) {
    $n = $x.Count
    $g = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $g[$i] = [double]::NaN }
    if ($n -lt 2) { return $g }
    if ($n -eq 2) {
        $s = ($y[1] - $y[0]) / ($x[1] - $x[0])
        $g[0] = $s; $g[1] = $s
        return $g
    }
    $g[0] = ($y[1] - $y[0]) / ($x[1] - $x[0])
    $g[$n-1] = ($y[$n-1] - $y[$n-2]) / ($x[$n-1] - $x[$n-2])
    for ($i = 1; $i -lt $n - 1; $i++) {
        $g[$i] = ($y[$i+1] - $y[$i-1]) / ($x[$i+1] - $x[$i-1])
    }
    return $g
}

function Normalize([double[]]$x) {
    $vals = $x | Where-Object { IsFiniteNum($_) }
    $out = New-Object double[] $x.Count
    for ($i = 0; $i -lt $x.Count; $i++) { $out[$i] = [double]::NaN }
    if ($vals.Count -eq 0) { return $out }
    $m = ($vals | Measure-Object -Maximum).Maximum
    if ($m -le 0) { return $out }
    for ($i = 0; $i -lt $x.Count; $i++) { if (IsFiniteNum($x[$i])) { $out[$i] = $x[$i] / $m } }
    return $out
}

function Pearson([double[]]$x, [double[]]$y) {
    $pairs = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        if (IsFiniteNum($x[$i]) -and IsFiniteNum($y[$i])) { $pairs += ,@($x[$i], $y[$i]) }
    }
    if ($pairs.Count -lt 3) { return [double]::NaN }
    $xs = [double[]]($pairs | ForEach-Object { $_[0] })
    $ys = [double[]]($pairs | ForEach-Object { $_[1] })
    $mx = ($xs | Measure-Object -Average).Average
    $my = ($ys | Measure-Object -Average).Average
    $num = 0.0; $sx = 0.0; $sy = 0.0
    for ($i = 0; $i -lt $xs.Count; $i++) {
        $dx = $xs[$i] - $mx; $dy = $ys[$i] - $my
        $num += $dx * $dy; $sx += $dx * $dx; $sy += $dy * $dy
    }
    if ($sx -le 0 -or $sy -le 0) { return [double]::NaN }
    return $num / [math]::Sqrt($sx * $sy)
}

function RankTies([double[]]$x) {
    $indexed = for ($i = 0; $i -lt $x.Count; $i++) { [pscustomobject]@{Index=$i; Value=$x[$i]} }
    $sorted = $indexed | Sort-Object Value, Index
    $ranks = New-Object double[] $x.Count
    $i = 0
    while ($i -lt $sorted.Count) {
        $j = $i
        while ($j + 1 -lt $sorted.Count -and $sorted[$j + 1].Value -eq $sorted[$i].Value) { $j++ }
        $rank = ($i + 1 + $j + 1) / 2.0
        for ($k = $i; $k -le $j; $k++) { $ranks[$sorted[$k].Index] = $rank }
        $i = $j + 1
    }
    return $ranks
}

function Spearman([double[]]$x, [double[]]$y) {
    $pairs = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        if (IsFiniteNum($x[$i]) -and IsFiniteNum($y[$i])) { $pairs += ,@($x[$i], $y[$i]) }
    }
    if ($pairs.Count -lt 3) { return [double]::NaN }
    $xs = [double[]]($pairs | ForEach-Object { $_[0] })
    $ys = [double[]]($pairs | ForEach-Object { $_[1] })
    return Pearson (RankTies $xs) (RankTies $ys)
}

function HalfMax([double[]]$x, [double[]]$y) {
    $maxVal = ($y | Measure-Object -Maximum).Maximum
    $peakIdx = [array]::IndexOf($y, $maxVal)
    $peakX = [double]$x[$peakIdx]
    $half = 0.5 * $maxVal
    $above = @()
    for ($i = 0; $i -lt $y.Count; $i++) { if ($y[$i] -ge $half) { $above += $i } }
    if ($above.Count -eq 0) {
        $lo = [double]$x[0]
        $hi = [double]$x[$x.Count-1]
        return @($lo, $hi, [double]($hi - $lo), $peakX)
    }
    $lo = [double]$x[$above[0]]
    $hi = [double]$x[$above[$above.Count-1]]
    return @($lo, $hi, [double]($hi - $lo), $peakX)
}

function RegionLabel([double]$E, $windowLo, $windowHi) {
    if ($E -lt $windowLo) { return 'low_energy_flank' }
    if ($E -le $windowHi) { return 'high_density_core' }
    return 'high_energy_tail'
}

function New-Chart($title, $xTitle, $yTitle) {
    Add-Type -AssemblyName System.Windows.Forms.DataVisualization
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 1000; $chart.Height = 720; $chart.BackColor = 'White'
    $area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'Area'
    $area.AxisX.Title = $xTitle; $area.AxisY.Title = $yTitle
    $area.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    $area.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    $chart.ChartAreas.Add($area)
    $chart.Titles.Add($title) | Out-Null
    return $chart
}

function Add-Series($chart, $name, $type, $color) {
    $s = New-Object System.Windows.Forms.DataVisualization.Charting.Series $name
    $s.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::$type
    $s.Color = $color; $s.BorderWidth = 3; $s.MarkerSize = 8
    $chart.Series.Add($s) | Out-Null
    return $s
}

$repoRoot = 'C:\Dev\matlab-functions'
$relaxPath = Join-Path $repoRoot 'results\relaxation\runs\run_2026_03_10_175048_relaxation_observable_stability_audit\tables\temperature_observables.csv'
$switchPath = Join-Path $repoRoot 'results\switching\runs\run_2026_03_10_112659_alignment_audit\observable_matrix.csv'
$relaxRows = Import-Csv $relaxPath
$switchRows = Import-Csv $switchPath
$Trel = To-Doubles $relaxRows 'T'
$Arel = To-Doubles $relaxRows 'A_T'
$tau = To-Doubles $relaxRows 'Relax_tau_T'
$beta = To-Doubles $relaxRows 'Relax_beta_T'
$Tsw = To-Doubles $switchRows 'T'
$Isw = To-Doubles $switchRows 'I_peak'
$Ssw = To-Doubles $switchRows 'S_peak'
$widthI = To-Doubles $switchRows 'width_I'
$halfDiff = To-Doubles $switchRows 'halfwidth_diff_norm'
$asym = To-Doubles $switchRows 'asym'

$kB = 0.08617333262145
$tau0 = 1e-9
$logTau = MovingAverage ([double[]]($tau | ForEach-Object { [math]::Log($_) })) 3
$E = New-Object double[] $Trel.Count
for ($i = 0; $i -lt $Trel.Count; $i++) { $E[$i] = $kB * $Trel[$i] * ($logTau[$i] - [math]::Log($tau0)) }
for ($i = 1; $i -lt $E.Count; $i++) { if ($E[$i] -le $E[$i-1]) { $E[$i] = $E[$i-1] + 1e-9 } }
$dEdT = CentralDiff $Trel $E
$Praw = New-Object double[] $Arel.Count
for ($i = 0; $i -lt $Arel.Count; $i++) { $Praw[$i] = [math]::Max($Arel[$i], 0.0) / [math]::Max([math]::Abs($dEdT[$i]), 1e-12) }
$area = 0.0
for ($i = 1; $i -lt $E.Count; $i++) { $area += 0.5 * ($Praw[$i] + $Praw[$i-1]) * ($E[$i] - $E[$i-1]) }
$P = New-Object double[] $Praw.Count
for ($i = 0; $i -lt $P.Count; $i++) { $P[$i] = $Praw[$i] / $area }
$dPdE = CentralDiff $E $P
$absSlope = [double[]]($dPdE | ForEach-Object { [math]::Abs($_) })
$hm = HalfMax $E $P
$windowLo = $hm[0]; $windowHi = $hm[1]; $windowW = $hm[2]; $Epeak = $hm[3]
$Eleft = $E[1]; $Eright = $E[$E.Count-2]
$peakIdx = [array]::IndexOf($E, $Epeak)
$leftIdx = 1..($peakIdx-1) | Where-Object { $_ -ge 0 }
$rightIdx = ($peakIdx+1)..($E.Count-2) | Where-Object { $_ -lt $E.Count }
if ($leftIdx.Count -gt 0) {
    $best = $leftIdx[0]; $bestVal = $dPdE[$best]
    foreach ($idx in $leftIdx) { if ($dPdE[$idx] -gt $bestVal) { $best = $idx; $bestVal = $dPdE[$idx] } }
    $Eleft = $E[$best]
}
if ($rightIdx.Count -gt 0) {
    $best = $rightIdx[0]; $bestVal = $dPdE[$best]
    foreach ($idx in $rightIdx) { if ($dPdE[$idx] -lt $bestVal) { $best = $idx; $bestVal = $dPdE[$idx] } }
    $Eright = $E[$best]
}

$signalFloor = 0.05 * (($Ssw | Measure-Object -Maximum).Maximum)
$Ismooth = MovingAverage $Isw 3
$dIdT = CentralDiff $Tsw $Ismooth
$motion = [double[]]($dIdT | ForEach-Object { [math]::Abs($_) })
$projRows = @()
for ($i = 0; $i -lt $Tsw.Count; $i++) {
    $T = $Tsw[$i]
    $eVal = [double]::NaN; $aVal = [double]::NaN; $tauVal = [double]::NaN; $betaVal = [double]::NaN; $pVal = [double]::NaN; $dpVal = [double]::NaN
    for ($j = 1; $j -lt $Trel.Count; $j++) {
        if ($T -ge $Trel[$j-1] -and $T -le $Trel[$j]) {
            $f = ($T - $Trel[$j-1]) / ($Trel[$j] - $Trel[$j-1])
            $eVal = $E[$j-1] + $f * ($E[$j] - $E[$j-1])
            $aVal = $Arel[$j-1] + $f * ($Arel[$j] - $Arel[$j-1])
            $tauVal = $tau[$j-1] + $f * ($tau[$j] - $tau[$j-1])
            $betaVal = $beta[$j-1] + $f * ($beta[$j] - $beta[$j-1])
            $pVal = $P[$j-1] + $f * ($P[$j] - $P[$j-1])
            $dpVal = $dPdE[$j-1] + $f * ($dPdE[$j] - $dPdE[$j-1])
            break
        }
    }
    $robust = (IsFiniteNum($Ssw[$i])) -and ($Ssw[$i] -ge $signalFloor)
    $analysis = $robust -and (IsFiniteNum($eVal)) -and (IsFiniteNum($pVal)) -and (IsFiniteNum($motion[$i]))
    $projRows += [pscustomobject]@{
        T_K = $T; A_interp = $aVal; Relax_tau_interp_s = $tauVal; Relax_beta_interp = $betaVal; E_ridge_meV = $eVal;
        P_eff_at_ridge_per_meV = $pVal; dP_dE_at_ridge_per_meV2 = $dpVal; abs_dP_dE_at_ridge_per_meV2 = [math]::Abs($dpVal);
        I_peak_raw_mA = $Isw[$i]; I_peak_smooth_mA = $Ismooth[$i]; dI_peak_dT_smooth_mA_per_K = $dIdT[$i]; motion_mA_per_K = $motion[$i];
        S_peak = $Ssw[$i]; width_I = $widthI[$i]; halfwidth_diff_norm = $halfDiff[$i]; asym = $asym[$i]; robust_switch_mask = $robust; analysis_mask = $analysis
    }
}
$analysisRows = $projRows | Where-Object { $_.analysis_mask }
$motionArr = [double[]]($analysisRows | ForEach-Object { $_.motion_mA_per_K })
$sArr = [double[]]($analysisRows | ForEach-Object { $_.S_peak })
$pArr = [double[]]($analysisRows | ForEach-Object { $_.P_eff_at_ridge_per_meV })
$slopeArr = [double[]]($analysisRows | ForEach-Object { $_.abs_dP_dE_at_ridge_per_meV2 })
$eArr = [double[]]($analysisRows | ForEach-Object { $_.E_ridge_meV })
$tArr = [double[]]($analysisRows | ForEach-Object { $_.T_K })
$iArr = [double[]]($analysisRows | ForEach-Object { $_.I_peak_smooth_mA })
$motionN = Normalize $motionArr; $sN = Normalize $sArr; $pN = Normalize $pArr
for ($i = 0; $i -lt $analysisRows.Count; $i++) { $analysisRows[$i] | Add-Member -NotePropertyName motion_norm -NotePropertyValue $motionN[$i] -Force; $analysisRows[$i] | Add-Member -NotePropertyName S_peak_norm -NotePropertyValue $sN[$i] -Force; $analysisRows[$i] | Add-Member -NotePropertyName P_eff_norm_at_ridge -NotePropertyValue $pN[$i] -Force }
$motionMax = ($motionArr | Measure-Object -Maximum).Maximum; $sMax = ($sArr | Measure-Object -Maximum).Maximum
$iMotion = [array]::IndexOf($motionArr, $motionMax); $iAmp = [array]::IndexOf($sArr, $sMax)
$motionToSteep = ([math]::Abs($eArr[$iMotion] - $Eleft), [math]::Abs($eArr[$iMotion] - $Eright) | Measure-Object -Minimum).Minimum
$ampToPeak = $eArr[$iAmp] - $Epeak
$supportFraction = (($pArr | Where-Object { $_ -ge 0.10 * (($P | Measure-Object -Maximum).Maximum) }).Count) / [math]::Max($pArr.Count, 1)
$motionTracksSteep = $motionToSteep -le [math]::Max(0.2 * $windowW, (($E[1..($E.Count-1)] | ForEach-Object -Begin {$prev=$E[0]} -Process {$d=$_-$prev; $prev=$_; $d}) | Measure-Object -Average).Average)
$ampPinned = ($pArr[$iAmp] -ge 0.8 * (($P | Measure-Object -Maximum).Maximum)) -and ($slopeArr[$iAmp] -le 0.5 * (($absSlope | Measure-Object -Maximum).Maximum))
$sameDistribution = if ($supportFraction -ge 0.6) { 'supported' } elseif ($supportFraction -ge 0.3) { 'partial' } else { 'weak' }
$TpeakBarrier = [double]::NaN
for ($j = 1; $j -lt $E.Count; $j++) {
    if ($Epeak -ge $E[$j-1] -and $Epeak -le $E[$j]) {
        $f = ($Epeak - $E[$j-1]) / ($E[$j] - $E[$j-1])
        $TpeakBarrier = $Trel[$j-1] + $f * ($Trel[$j] - $Trel[$j-1])
        break
    }
}$metricsRow = [pscustomobject]@{
    relax_run_name = 'run_2026_03_10_175048_relaxation_observable_stability_audit'; switch_run_name = 'run_2026_03_10_112659_alignment_audit'; tau0_s = $tau0; temp_smooth_window = 3; signal_floor_frac = 0.05;
    density_peak_E_meV = $Epeak; density_peak_T_K = $TpeakBarrier; density_window_low_meV = $windowLo; density_window_high_meV = $windowHi; density_window_width_meV = $windowW;
    steep_low_E_meV = $Eleft; steep_high_E_meV = $Eright; motion_peak_T_K = $tArr[$iMotion]; motion_peak_E_meV = $eArr[$iMotion]; motion_peak_I_mA = $iArr[$iMotion]; motion_peak_region = (RegionLabel $eArr[$iMotion] $windowLo $windowHi);
    amplitude_peak_T_K = $tArr[$iAmp]; amplitude_peak_E_meV = $eArr[$iAmp]; amplitude_peak_I_mA = $iArr[$iAmp]; amplitude_peak_region = (RegionLabel $eArr[$iAmp] $windowLo $windowHi);
    pearson_motion_vs_density = (Pearson $motionArr $pArr); spearman_motion_vs_density = (Spearman $motionArr $pArr); pearson_motion_vs_absSlope = (Pearson $motionArr $slopeArr); spearman_motion_vs_absSlope = (Spearman $motionArr $slopeArr);
    pearson_Speak_vs_density = (Pearson $sArr $pArr); spearman_Speak_vs_density = (Spearman $sArr $pArr); pearson_Speak_vs_absSlope = (Pearson $sArr $slopeArr); spearman_Speak_vs_absSlope = (Spearman $sArr $slopeArr);
    motion_delta_to_nearest_steep_meV = $motionToSteep; amplitude_delta_to_density_peak_meV = $ampToPeak; switch_support_fraction = $supportFraction; motion_tracks_steep_region = $motionTracksSteep; amplitude_in_pinned_sector = $ampPinned; same_distribution_verdict = $sameDistribution
}

$timestamp = Get-Date -Format 'yyyy_MM_dd_HHmmss'
$runId = "run_${timestamp}_switching_barrier_projection"
$runDir = Join-Path $repoRoot (Join-Path 'results\cross_experiment\runs' $runId)
$tablesDir = Join-Path $runDir 'tables'; $figDir = Join-Path $runDir 'figures'; $reportDir = Join-Path $runDir 'reports'; $reviewDir = Join-Path $runDir 'review'
$null = New-Item -ItemType Directory -Force -Path $tablesDir, $figDir, $reportDir, $reviewDir
$chart1 = New-Chart 'Barrier distribution with switching ridge positions' 'Barrier energy E_eff (meV)' 'P_eff(E) (1/meV)'
$s1 = Add-Series $chart1 'Peff' 'Line' ([System.Drawing.Color]::Black)
for ($i = 0; $i -lt $E.Count; $i++) { [void]$s1.Points.AddXY($E[$i], $P[$i]) }
$s2 = Add-Series $chart1 'Ridge positions' 'Point' ([System.Drawing.Color]::SteelBlue)
foreach ($row in $analysisRows) { [void]$s2.Points.AddXY($row.E_ridge_meV, $row.P_eff_at_ridge_per_meV) }
$s3 = Add-Series $chart1 'Density peak' 'Point' ([System.Drawing.Color]::Goldenrod); $s3.MarkerStyle = 'Diamond'; [void]$s3.Points.AddXY($Epeak, (($P | Measure-Object -Maximum).Maximum))
$s4 = Add-Series $chart1 'Motion max' 'Point' ([System.Drawing.Color]::Red); $s4.MarkerStyle = 'Circle'; [void]$s4.Points.AddXY($eArr[$iMotion], $pArr[$iMotion])
$s5 = Add-Series $chart1 'Amplitude max' 'Point' ([System.Drawing.Color]::Blue); $s5.MarkerStyle = 'Square'; [void]$s5.Points.AddXY($eArr[$iAmp], $pArr[$iAmp])
$chart1.SaveImage((Join-Path $figDir 'ridge_positions_on_barrier_distribution.png'), 'Png')

$chart2 = New-Chart 'Ridge motion vs barrier density' 'P_eff(E_ridge)' '|dI_peak/dT| (mA/K)'
$s = Add-Series $chart2 'Motion' 'Point' ([System.Drawing.Color]::Firebrick)
for ($i = 0; $i -lt $analysisRows.Count; $i++) { [void]$s.Points.AddXY($pArr[$i], $motionArr[$i]) }
$ann = New-Object System.Windows.Forms.DataVisualization.Charting.TextAnnotation
$ann.Text = "Pearson=$([math]::Round($metricsRow.pearson_motion_vs_density,3))`nSpearman=$([math]::Round($metricsRow.spearman_motion_vs_density,3))"
$ann.X = 5; $ann.Y = 5; $ann.AnchorAlignment = 'TopLeft'; $chart2.Annotations.Add($ann)
$chart2.SaveImage((Join-Path $figDir 'switching_barrier_projection.png'), 'Png')

$chart3 = New-Chart 'Switching amplitude vs barrier density' 'P_eff(E_ridge)' 'S_peak(T)'
$s = Add-Series $chart3 'Amplitude' 'Point' ([System.Drawing.Color]::RoyalBlue)
for ($i = 0; $i -lt $analysisRows.Count; $i++) { [void]$s.Points.AddXY($pArr[$i], $sArr[$i]) }
$ann = New-Object System.Windows.Forms.DataVisualization.Charting.TextAnnotation
$ann.Text = "Pearson=$([math]::Round($metricsRow.pearson_Speak_vs_density,3))`nSpearman=$([math]::Round($metricsRow.spearman_Speak_vs_density,3))"
$ann.X = 5; $ann.Y = 5; $ann.AnchorAlignment = 'TopLeft'; $chart3.Annotations.Add($ann)
$chart3.SaveImage((Join-Path $figDir 'switching_barrier_alignment.png'), 'Png')

$chart4 = New-Chart 'Switching trajectory in (E,J) space' 'Barrier energy E_ridge (meV)' 'Current J = I_peak(T) (mA)'
$s = Add-Series $chart4 'Trajectory' 'Line' ([System.Drawing.Color]::DimGray)
for ($i = 0; $i -lt $analysisRows.Count; $i++) { [void]$s.Points.AddXY($eArr[$i], $iArr[$i]) }
$s2 = Add-Series $chart4 'Motion max' 'Point' ([System.Drawing.Color]::Red); $s2.MarkerStyle = 'Circle'; [void]$s2.Points.AddXY($eArr[$iMotion], $iArr[$iMotion])
$s3 = Add-Series $chart4 'Amplitude max' 'Point' ([System.Drawing.Color]::Blue); $s3.MarkerStyle = 'Square'; [void]$s3.Points.AddXY($eArr[$iAmp], $iArr[$iAmp])
$chart4.SaveImage((Join-Path $figDir 'switching_E_J_trajectory.png'), 'Png')

$analysisRows | Export-Csv -NoTypeInformation -Path (Join-Path $tablesDir 'switching_barrier_projection.csv')
$metricsRow | Export-Csv -NoTypeInformation -Path (Join-Path $tablesDir 'switching_barrier_alignment_metrics.csv')
@{
  run_id = $runId
  label = 'switching_barrier_projection'
  experiment = 'cross_experiment'
  timestamp = (Get-Date).ToString('s')
  dataset = 'relax:run_2026_03_10_175048_relaxation_observable_stability_audit | switch:run_2026_03_10_112659_alignment_audit'
} | ConvertTo-Json | Set-Content -Path (Join-Path $runDir 'run_manifest.json')
@{
  tau0_s = $tau0
  signal_floor_frac = 0.05
  temp_smooth_window = 3
  energy_smooth_window = 3
} | ConvertTo-Json | Set-Content -Path (Join-Path $runDir 'config_snapshot.json')
"Projection run: $runId`n" | Set-Content -Path (Join-Path $runDir 'log.txt')
"same_distribution_verdict = $sameDistribution`nmotion_tracks_steep_region = $motionTracksSteep`namplitude_in_pinned_sector = $ampPinned`n" | Set-Content -Path (Join-Path $runDir 'run_notes.txt')
$report = @"
# Switching Barrier Projection Report

## Inputs
- Relaxation source run: `run_2026_03_10_175048_relaxation_observable_stability_audit`.
- Switching source run: `run_2026_03_10_112659_alignment_audit`.
- Barrier mapping used: E_eff(T) = k_B T ln(tau(T)/tau0) with tau0 = 1e-9 s.

## Discussion
1. Switching selects barriers from the same relaxation-derived distribution at the $sameDistribution level; the support fraction inside the main barrier distribution is $([math]::Round($supportFraction,3)).
2. $motionSentence
3. $ampSentence
4. For current-tilted activation physics, the switching ridge is most naturally interpreted as a current-selected sweep through the same barrier landscape reconstructed from relaxation, while the saved runs do not expose the tilt coefficient gamma or pulse duration needed for a full barrier untilting.

## Correlations
- corr(motion, P_eff) = $([math]::Round($metricsRow.pearson_motion_vs_density,4)) Pearson, $([math]::Round($metricsRow.spearman_motion_vs_density,4)) Spearman.
- corr(motion, |dP/dE|) = $([math]::Round($metricsRow.pearson_motion_vs_absSlope,4)) Pearson, $([math]::Round($metricsRow.spearman_motion_vs_absSlope,4)) Spearman.
- corr(S_peak, P_eff) = $([math]::Round($metricsRow.pearson_Speak_vs_density,4)) Pearson, $([math]::Round($metricsRow.spearman_Speak_vs_density,4)) Spearman.
- corr(S_peak, |dP/dE|) = $([math]::Round($metricsRow.pearson_Speak_vs_absSlope,4)) Pearson, $([math]::Round($metricsRow.spearman_Speak_vs_absSlope,4)) Spearman.

## Caveats
- The absolute energy scale depends on the assumed attempt time tau0.
- The source runs do not export gamma or pulse duration, so (E,J) is a barrier-sector trajectory rather than a full inversion of the tilt law.
"@
$motionSentence = if ($motionTracksSteep) { "Ridge motion is consistent with the steepest P(E) sectors; the motion maximum is $([math]::Round($motionToSteep,3)) meV from the nearest steep flank." } else { "Ridge motion is only partially aligned with the steepest P(E) sectors; the motion maximum is $([math]::Round($motionToSteep,3)) meV from the nearest steep flank." }
$ampSentence = if ($ampPinned) { "S_peak is strongest in a pinned barrier sector near the density core (E = $([math]::Round($eArr[$iAmp],3)) meV)." } else { "S_peak does not isolate a clearly pinned barrier sector; the amplitude maximum is offset from the density peak by $([math]::Round($ampToPeak,3)) meV." }
$report = $report.Replace('$motionSentence', $motionSentence).Replace('$ampSentence', $ampSentence)
$report | Set-Content -Path (Join-Path $reportDir 'switching_barrier_projection_report.md')
Compress-Archive -Path $tablesDir, $figDir, $reportDir, (Join-Path $runDir 'run_manifest.json'), (Join-Path $runDir 'config_snapshot.json'), (Join-Path $runDir 'log.txt'), (Join-Path $runDir 'run_notes.txt') -DestinationPath (Join-Path $reviewDir 'switching_barrier_projection_bundle.zip') -Force
Write-Output $runDir




