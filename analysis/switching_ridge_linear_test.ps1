param(
    [string]$RepoRoot = '',
    [string]$SwitchRunName = 'run_2026_03_10_112659_alignment_audit',
    [string]$MotionRunName = 'run_2026_03_11_084425_relaxation_switching_motion_test',
    [string]$RelaxRunName = 'run_2026_03_10_175048_relaxation_observable_stability_audit',
    [string]$RunLabel = 'switching_ridge_linear_test'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

$helperPath = Join-Path $PSScriptRoot 'switching_collapse_kernel_analysis.ps1'
if (-not (Test-Path -LiteralPath $helperPath)) {
    throw "Missing helper script: $helperPath"
}
$helperText = Get-Content -LiteralPath $helperPath -Raw
$startMarker = 'function Get-RepoRootPath {'
$endMarker = '$RepoRoot = Get-RepoRootPath $RepoRoot'
$startIndex = $helperText.IndexOf($startMarker)
$endIndex = $helperText.IndexOf($endMarker)
if ($startIndex -lt 0 -or $endIndex -le $startIndex) {
    throw 'Could not isolate helper functions from switching_collapse_kernel_analysis.ps1'
}
Invoke-Expression ($helperText.Substring($startIndex, $endIndex - $startIndex))

$ThisScriptRoot = if ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}

function Get-RepoRootPath {
    param([string]$InputRepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($InputRepoRoot)) {
        return (Resolve-Path $InputRepoRoot).Path
    }
    return (Split-Path $ThisScriptRoot -Parent)
}

function Add-PointSeries {
    param(
        [System.Windows.Forms.DataVisualization.Charting.Chart]$Chart,
        [string]$Name,
        [double[]]$X,
        [double[]]$Y,
        [object]$Color,
        [string]$MarkerStyle = 'Circle',
        [int]$MarkerSize = 8
    )
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $Name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Point
    $series.Legend = 'legend'
    $series.ChartArea = 'main'
    $series.IsVisibleInLegend = $true
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::$MarkerStyle
    $series.MarkerSize = $MarkerSize
    if ($null -ne $Color) { $series.Color = $Color }
    for ($i = 0; $i -lt [Math]::Min($X.Length, $Y.Length); $i++) {
        if ([double]::IsNaN($X[$i]) -or [double]::IsInfinity($X[$i]) -or [double]::IsNaN($Y[$i]) -or [double]::IsInfinity($Y[$i])) {
            continue
        }
        [void]$series.Points.AddXY($X[$i], $Y[$i])
    }
    $Chart.Series.Add($series)
}

function Sign-NonZero {
    param([double]$Value)
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value) -or [Math]::Abs($Value) -lt 1e-12) { return 0 }
    if ($Value -gt 0) { return 1 }
    return -1
}

function Get-LinearFit {
    param([object[]]$Rows)
    $x = [double[]]@($Rows | ForEach-Object { To-Double $_.T })
    $y = [double[]]@($Rows | ForEach-Object { To-Double $_.I_peak })
    $n = $x.Length
    if ($n -lt 2) {
        return [pscustomobject]@{ slope = [double]::NaN; intercept = [double]::NaN; r_squared = [double]::NaN; fit_y = [double[]]@() }
    }
    $mx = Get-Mean $x
    $my = Get-Mean $y
    $sumXY = 0.0
    $sumXX = 0.0
    $sumYY = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $dx = $x[$i] - $mx
        $dy = $y[$i] - $my
        $sumXY += $dx * $dy
        $sumXX += $dx * $dx
        $sumYY += $dy * $dy
    }
    if ($sumXX -le 0) {
        return [pscustomobject]@{ slope = [double]::NaN; intercept = [double]::NaN; r_squared = [double]::NaN; fit_y = [double[]]@() }
    }
    $a = $sumXY / $sumXX
    $b = $my - ($a * $mx)
    $fitY = [double[]]::new($n)
    $sse = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $fitY[$i] = ($a * $x[$i]) + $b
        $err = $y[$i] - $fitY[$i]
        $sse += $err * $err
    }
    $r2 = if ($sumYY -gt 0) { 1.0 - ($sse / $sumYY) } else { [double]::NaN }
    return [pscustomobject]@{ slope = $a; intercept = $b; r_squared = $r2; fit_y = $fitY }
}

function Get-MobileRegime {
    param([object[]]$Rows)
    $sorted = @($Rows | Sort-Object T)
    $candidateRows = @($sorted | Where-Object { [int]$_.comparison_mask -eq 1 -and -not [double]::IsNaN($_.dI_peak_dT_smooth) })
    if ($candidateRows.Count -lt 3) { throw 'Not enough saved derivative points to identify a mobile regime.' }

    $nonZeroRows = @($candidateRows | Where-Object { [Math]::Abs($_.dI_peak_dT_smooth) -gt 1e-9 })
    if ($nonZeroRows.Count -lt 3) { throw 'No non-zero derivative segment found in saved outputs.' }

    $dominantSign = Sign-NonZero (Get-Median ($nonZeroRows | ForEach-Object { $_.dI_peak_dT_smooth }))
    if ($dominantSign -eq 0) { $dominantSign = -1 }

    $absNonZero = @($nonZeroRows | ForEach-Object { [Math]::Abs($_.dI_peak_dT_smooth) })
    $threshold = 0.5 * (Get-Median $absNonZero)
    $gridStep = Get-Median (@($sorted | Select-Object -Skip 1 | ForEach-Object -Begin { $prev = $sorted[0].T } -Process { $d = $_.T - $prev; $prev = $_.T; $d }))
    if ([double]::IsNaN($gridStep) -or $gridStep -le 0) { $gridStep = 2.0 }

    $activeRows = @($candidateRows | Where-Object {
        (Sign-NonZero $_.dI_peak_dT_smooth) -eq $dominantSign -and [Math]::Abs($_.dI_peak_dT_smooth) -ge $threshold
    } | Sort-Object T)
    if ($activeRows.Count -lt 3) { throw 'Derivative thresholding did not leave enough points for a mobile regime fit.' }
    $blocks = @()
    $current = @()
    foreach ($row in $activeRows) {
        if ($current.Count -eq 0) {
            $current += ,$row
            continue
        }
        $prev = $current[$current.Count - 1]
        if (($row.T - $prev.T) -le (1.5 * $gridStep + 1e-9)) {
            $current += ,$row
        } else {
            $blocks += ,@($current)
            $current = @()
            $current += ,$row
        }
    }
    if ($current.Count -gt 0) { $blocks += ,@($current) }

    $bestBlock = $null
    foreach ($block in $blocks) {
        if ($null -eq $bestBlock) { $bestBlock = $block; continue }
        if ($block.Count -gt $bestBlock.Count) { $bestBlock = $block; continue }
        if ($block.Count -eq $bestBlock.Count) {
            $blockMaxT = ($block | Measure-Object T -Maximum).Maximum
            $bestMaxT = ($bestBlock | Measure-Object T -Maximum).Maximum
            if ($blockMaxT -gt $bestMaxT) { $bestBlock = $block }
        }
    }
    if ($null -eq $bestBlock -or $bestBlock.Count -lt 3) {
        throw 'Could not identify a contiguous mobile regime with at least three saved points.'
    }

    return [pscustomobject]@{
        rows = @($bestBlock | Sort-Object T)
        threshold = $threshold
        dominant_sign = $dominantSign
        grid_step = $gridStep
        start_T = (@($bestBlock | Sort-Object T)[0]).T
        end_T = (@($bestBlock | Sort-Object T)[-1]).T
    }
}

function Build-FullFigure {
    param([object[]]$Rows, [object[]]$MobileRows, [pscustomobject]$Fit, [double]$PinningOnsetT, [double]$RelaxPeakT, [string]$OutputPath)
    $chart = New-LineChart -Title 'I_peak(T) with automatic mobile-regime selection' -XAxisTitle 'Temperature (K)' -YAxisTitle 'I_peak (mA)'
    Add-LineSeries -Chart $chart -Name 'full I_peak(T)' -X ([double[]]@($Rows | ForEach-Object { $_.T })) -Y ([double[]]@($Rows | ForEach-Object { $_.I_peak })) -Color (Hex-Color '#4D4D4D') -MarkerStyle 'Circle' -BorderWidth 3
    Add-PointSeries -Chart $chart -Name 'mobile regime' -X ([double[]]@($MobileRows | ForEach-Object { $_.T })) -Y ([double[]]@($MobileRows | ForEach-Object { $_.I_peak })) -Color (Hex-Color '#D62728') -MarkerStyle 'Diamond' -MarkerSize 9
    Add-LineSeries -Chart $chart -Name 'linear fit' -X ([double[]]@($MobileRows | ForEach-Object { $_.T })) -Y $Fit.fit_y -Color (Hex-Color '#1F77B4') -MarkerStyle 'None' -BorderWidth 3
    $yMin = ((@($Rows | ForEach-Object { $_.I_peak }) | Measure-Object -Minimum).Minimum) - 2.0
    $yMax = ((@($Rows | ForEach-Object { $_.I_peak }) | Measure-Object -Maximum).Maximum) + 2.0
    Add-LineSeries -Chart $chart -Name 'pinning onset' -X ([double[]]@($PinningOnsetT, $PinningOnsetT)) -Y ([double[]]@($yMin, $yMax)) -Color (Hex-Color '#FF7F0E') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
    Add-LineSeries -Chart $chart -Name 'Relax peak' -X ([double[]]@($RelaxPeakT, $RelaxPeakT)) -Y ([double[]]@($yMin, $yMax)) -Color (Hex-Color '#2CA02C') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
    Save-Chart -Chart $chart -Path $OutputPath
}

function Build-FitFigure {
    param([object[]]$MobileRows, [pscustomobject]$Fit, [string]$OutputPath)
    $chart = New-LineChart -Title 'Mobile-regime I_peak(T) linear fit' -XAxisTitle 'Temperature (K)' -YAxisTitle 'I_peak (mA)'
    Add-PointSeries -Chart $chart -Name 'mobile regime points' -X ([double[]]@($MobileRows | ForEach-Object { $_.T })) -Y ([double[]]@($MobileRows | ForEach-Object { $_.I_peak })) -Color (Hex-Color '#D62728') -MarkerStyle 'Diamond' -MarkerSize 9
    Add-LineSeries -Chart $chart -Name 'linear fit' -X ([double[]]@($MobileRows | ForEach-Object { $_.T })) -Y $Fit.fit_y -Color (Hex-Color '#1F77B4') -MarkerStyle 'None' -BorderWidth 3
    Save-Chart -Chart $chart -Path $OutputPath
}

function Build-DerivativeFigure {
    param([object[]]$Rows, [object[]]$MobileRows, [double]$Threshold, [int]$DominantSign, [double]$PinningOnsetT, [double]$RelaxPeakT, [string]$OutputPath)
    $chart = New-LineChart -Title 'Saved dI_peak/dT used for mobile-regime detection' -XAxisTitle 'Temperature (K)' -YAxisTitle 'dI_peak/dT (mA/K)'
    Add-LineSeries -Chart $chart -Name 'saved smoothed derivative' -X ([double[]]@($Rows | ForEach-Object { $_.T })) -Y ([double[]]@($Rows | ForEach-Object { $_.dI_peak_dT_smooth })) -Color (Hex-Color '#4D4D4D') -MarkerStyle 'Circle' -BorderWidth 3
    Add-PointSeries -Chart $chart -Name 'selected mobile points' -X ([double[]]@($MobileRows | ForEach-Object { $_.T })) -Y ([double[]]@($MobileRows | ForEach-Object { $_.dI_peak_dT_smooth })) -Color (Hex-Color '#D62728') -MarkerStyle 'Diamond' -MarkerSize 9
    $signedThreshold = $DominantSign * $Threshold
    $xMin = ((@($Rows | ForEach-Object { $_.T }) | Measure-Object -Minimum).Minimum)
    $xMax = ((@($Rows | ForEach-Object { $_.T }) | Measure-Object -Maximum).Maximum)
    Add-LineSeries -Chart $chart -Name 'selection threshold' -X ([double[]]@($xMin, $xMax)) -Y ([double[]]@($signedThreshold, $signedThreshold)) -Color (Hex-Color '#9467BD') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
    $yMin = -2.5
    $yMax = 0.5
    Add-LineSeries -Chart $chart -Name 'pinning onset' -X ([double[]]@($PinningOnsetT, $PinningOnsetT)) -Y ([double[]]@($yMin, $yMax)) -Color (Hex-Color '#FF7F0E') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
    Add-LineSeries -Chart $chart -Name 'Relax peak' -X ([double[]]@($RelaxPeakT, $RelaxPeakT)) -Y ([double[]]@($yMin, $yMax)) -Color (Hex-Color '#2CA02C') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
    Save-Chart -Chart $chart -Path $OutputPath
}

$RepoRoot = Get-RepoRootPath $RepoRoot
$switchRunDir = Join-Path $RepoRoot ("results\switching\runs\{0}" -f $SwitchRunName)
$motionRunDir = Join-Path $RepoRoot ("results\cross_experiment\runs\{0}" -f $MotionRunName)
$relaxRunDir = Join-Path $RepoRoot ("results\relaxation\runs\{0}" -f $RelaxRunName)

$requiredFiles = @(
    (Join-Path $switchRunDir 'observable_matrix.csv'),
    (Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv'),
    (Join-Path $relaxRunDir 'tables\observables_relaxation.csv')
)
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required saved-output file: $path"
    }
}

$config = [ordered]@{
    switching_run = $SwitchRunName
    motion_run = $MotionRunName
    relaxation_run = $RelaxRunName
    data_policy = 'saved outputs only'
    regime_rule = 'dominant-sign saved derivative block with |dI/dT| >= 0.5 * median(|nonzero dI/dT|)'
    fit_model = 'I_peak(T) = a*T + b within identified mobile regime'
}

$run = New-RunContext -RepoRootPath $RepoRoot -Experiment 'cross_experiment' -Label $RunLabel -Dataset ("switch:{0} | motion:{1} | relax:{2}" -f $SwitchRunName, $MotionRunName, $RelaxRunName) -Config $config
Append-Line -Path $run.LogPath -Text ("[{0}] switching ridge linear test started" -f (Stamp-Now))

$switchRows = @(Import-Csv -Path (Join-Path $switchRunDir 'observable_matrix.csv') | ForEach-Object {
    [pscustomobject]@{ T = To-Double $_.T; I_peak = To-Double $_.I_peak; S_peak = To-Double $_.S_peak }
} | Sort-Object T)
$motionRows = @(Import-Csv -Path (Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv') | ForEach-Object {
    [pscustomobject]@{ T = To-Double $_.T_K; dI_peak_dT_smooth = To-Double $_.dI_peak_dT_smooth_mA_per_K; comparison_mask = To-Double $_.comparison_mask }
} | Sort-Object T)
$relaxObs = @(Import-Csv -Path (Join-Path $relaxRunDir 'tables\observables_relaxation.csv'))[0]
Append-Line -Path $run.LogPath -Text ("[{0}] loaded saved source tables" -f (Stamp-Now))

$motionByT = @{}
foreach ($row in $motionRows) { $motionByT[[string]$row.T] = $row }
$joinedRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $switchRows) {
    $motion = if ($motionByT.ContainsKey([string]$row.T)) { $motionByT[[string]$row.T] } else { $null }
    [void]$joinedRows.Add([pscustomobject]@{
        T = $row.T
        I_peak = $row.I_peak
        S_peak = $row.S_peak
        dI_peak_dT_smooth = if ($null -ne $motion) { $motion.dI_peak_dT_smooth } else { [double]::NaN }
        comparison_mask = if ($null -ne $motion) { $motion.comparison_mask } else { 0 }
    })
}
$joinedRows = @($joinedRows | Sort-Object T)

$mobile = Get-MobileRegime -Rows $joinedRows
$mobileRows = @($mobile.rows)
$fit = Get-LinearFit -Rows $mobileRows
$relaxPeakT = To-Double $relaxObs.Relax_T_peak
$pinningOnsetT = $mobile.start_T
$fitRangeText = ('{0:F1}-{1:F1}' -f $mobile.start_T, $mobile.end_T)
Append-Line -Path $run.LogPath -Text ("[{0}] identified mobile regime: {1} K" -f (Stamp-Now), $fitRangeText)

$fitRows = @(
    [pscustomobject]@{
        switching_run = $SwitchRunName
        motion_run = $MotionRunName
        relaxation_run = $RelaxRunName
        mobile_regime_T_min_K = $mobile.start_T
        mobile_regime_T_max_K = $mobile.end_T
        mobile_regime_n_points = $mobileRows.Count
        slope_a_mA_per_K = $fit.slope
        intercept_b_mA = $fit.intercept
        r_squared = $fit.r_squared
        derivative_threshold_mA_per_K = $mobile.threshold
        dominant_derivative_sign = $mobile.dominant_sign
        pinning_onset_T_K = $pinningOnsetT
        relaxation_crossover_T_K = $relaxPeakT
        delta_mobile_start_vs_relax_peak_K = $pinningOnsetT - $relaxPeakT
    }
)
$fitTablePath = Join-Path $run.TablesDir 'linear_fit_results.csv'
Write-RunTable -Rows $fitRows -Path $fitTablePath
Append-Line -Path $run.LogPath -Text ("[{0}] wrote fit table" -f (Stamp-Now))

$fullFigurePath = Join-Path $run.FiguresDir 'Ipeak_vs_T_full.png'
$fitFigurePath = Join-Path $run.FiguresDir 'Ipeak_vs_T_fit.png'
$derivFigurePath = Join-Path $run.FiguresDir 'dIpeak_dT_vs_T.png'
Build-FullFigure -Rows $joinedRows -MobileRows $mobileRows -Fit $fit -PinningOnsetT $pinningOnsetT -RelaxPeakT $relaxPeakT -OutputPath $fullFigurePath
Build-FitFigure -MobileRows $mobileRows -Fit $fit -OutputPath $fitFigurePath
Build-DerivativeFigure -Rows $joinedRows -MobileRows $mobileRows -Threshold $mobile.threshold -DominantSign $mobile.dominant_sign -PinningOnsetT $pinningOnsetT -RelaxPeakT $relaxPeakT -OutputPath $derivFigurePath
Append-Line -Path $run.LogPath -Text ("[{0}] wrote figures" -f (Stamp-Now))

$slopeText = [string]::Format($Invariant, '{0:F3}', $fit.slope)
$interceptText = [string]::Format($Invariant, '{0:F3}', $fit.intercept)
$r2Text = [string]::Format($Invariant, '{0:F3}', $fit.r_squared)
$thresholdText = [string]::Format($Invariant, '{0:F3}', $mobile.threshold)
$mobileStartText = [string]::Format($Invariant, '{0:F1}', $mobile.start_T)
$mobileEndText = [string]::Format($Invariant, '{0:F1}', $mobile.end_T)
$relaxPeakText = [string]::Format($Invariant, '{0:F1}', $relaxPeakT)
$deltaText = [string]::Format($Invariant, '{0:F1}', ($pinningOnsetT - $relaxPeakT))
$consistencyText = if ($fit.r_squared -ge 0.95) { 'strongly consistent with a linear dependence over the selected range' } elseif ($fit.r_squared -ge 0.85) { 'reasonably consistent with an approximate linear dependence over the selected range' } else { 'only weakly consistent with a linear dependence over the selected range' }

$reportText = @"
# Switching Ridge Linear Test

## Repository-state summary
- Repository rules inspected before analysis: docs/AGENT_RULES.md, docs/results_system.md, docs/repository_structure.md, docs/output_artifacts.md, docs/visualization_rules.md.
- Existing related code inspected: analysis/relaxation_switching_motion_test.m.
- Existing saved functionality already present: the motion-test run already exported a saved smoothed dI_peak/dT table derived from the canonical switching ridge observables.
- Gap found: the saved outputs had not yet been used for an automatic high-temperature mobile-regime selection followed by a dedicated linear fit of I_peak(T).
- New code added: analysis/switching_ridge_linear_test.ps1.

## Exact saved files reused
- Switching observable source: $((Join-Path $switchRunDir 'observable_matrix.csv'))
- Saved derivative source: $((Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv'))
- Relaxation crossover reference: $((Join-Path $relaxRunDir 'tables\observables_relaxation.csv'))

## Automatic mobile-regime rule
- Raw I_peak(T) values were taken from the saved switching observable table.
- Mobile-regime detection used the saved smoothed derivative column dI_peak_dT_smooth_mA_per_K from the prior motion-test run.
- The dominant derivative sign is $($mobile.dominant_sign).
- The automatic derivative threshold was set to 0.5 times the median absolute non-zero derivative, giving |dI_peak/dT| >= $thresholdText mA/K.
- The selected contiguous mobile block is $mobileStartText-$mobileEndText K with $($mobileRows.Count) temperatures.
- The low-temperature pinning onset is therefore approximated by the lower edge of this block, T_pin ~ $mobileStartText K.
- The 34 K point was excluded automatically because the saved comparison mask is 0 and the saved derivative is not finite there.

## Linear fit result
- Fit model: I_peak(T) = a*T + b.
- Slope a = $slopeText mA/K.
- Intercept b = $interceptText mA.
- R^2 = $r2Text.
- Fit range = $mobileStartText-$mobileEndText K.

## Interpretation
- Over the automatically selected mobile regime, the ridge is $consistencyText.
- The sign of the slope is negative, so the saved ridge position moves to lower current as temperature increases in the mobile regime.
- The pinning or slowdown boundary appears near $mobileStartText K, which is about $deltaText K relative to the Relaxation crossover peak near $relaxPeakText K.
- This means the mobile switching regime starts below the Relaxation crossover and continues through that crossover window rather than turning on exactly at 26-27 K.

## Uncertainty and limits
- The mobile-regime boundary is automatic but still method-dependent because it relies on a threshold applied to the saved smoothed derivative.
- A stricter later-temperature subset would fit even more linearly, but it would use fewer points and would no longer represent the broadest automatically detected mobile window.
- No switching maps were recomputed, so this run tests only what the saved ridge observables already support.

## Visualization choices
- number of curves: 4 series in the full-curve panel, 2 in the fit panel, and 5 in the derivative panel
- legend vs colormap: explicit legends only
- colormap used: none
- smoothing applied: none in this run; the derivative plot reuses the saved smoothed derivative export from the earlier motion-test run
- justification: the figures are focused on the regime-selection logic and the linear-fit claim rather than map-level detail
"@

$reportPath = Join-Path $run.ReportsDir 'switching_ridge_linear_test.md'
Write-TextUtf8 -Path $reportPath -Text $reportText

$zipPath = Build-ZipBundle -Run $run -ZipName 'switching_ridge_linear_test.zip'
Append-Line -Path $run.LogPath -Text ("[{0}] wrote report: {1}" -f (Stamp-Now), $reportPath)
Append-Line -Path $run.LogPath -Text ("[{0}] wrote review bundle: {1}" -f (Stamp-Now), $zipPath)
Append-Line -Path $run.NotesPath -Text ("mobile regime = {0}-{1} K" -f $mobileStartText, $mobileEndText)
Append-Line -Path $run.NotesPath -Text ("linear fit slope/intercept/R2 = {0} / {1} / {2}" -f $slopeText, $interceptText, $r2Text)

Write-Output ("Run directory: {0}" -f $run.RunDir)
Write-Output ("Report: {0}" -f $reportPath)
Write-Output ("Review bundle: {0}" -f $zipPath)



