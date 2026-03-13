param(
    [string]$RepoRoot = '',
    [string]$CollapseRunName = 'run_2026_03_11_224153_switching_collapse_kernel_analysis',
    [string]$SwitchRunName = 'run_2026_03_10_112659_alignment_audit',
    [string]$RunLabel = 'switching_collapse_asymmetry_test'
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
$ThisScriptRoot = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
function Get-RepoRootPath {
    param([string]$InputRepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($InputRepoRoot)) {
        return (Resolve-Path $InputRepoRoot).Path
    }
    return (Split-Path $ThisScriptRoot -Parent)
}


function Get-PairedFiniteSeries {
    param([object[]]$X, [object[]]$Y)
    $xs = New-Object System.Collections.Generic.List[double]
    $ys = New-Object System.Collections.Generic.List[double]
    for ($i = 0; $i -lt [Math]::Min($X.Count, $Y.Count); $i++) {
        $xv = [double]$X[$i]
        $yv = [double]$Y[$i]
        if ([double]::IsNaN($xv) -or [double]::IsInfinity($xv) -or [double]::IsNaN($yv) -or [double]::IsInfinity($yv)) {
            continue
        }
        [void]$xs.Add($xv)
        [void]$ys.Add($yv)
    }
    return [pscustomobject]@{ X = $xs; Y = $ys }
}

function Get-AverageRanks {
    param([System.Collections.Generic.List[double]]$Values)
    $pairs = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $Values.Count; $i++) {
        [void]$pairs.Add([pscustomobject]@{ Index = $i; Value = $Values[$i] })
    }
    $sorted = @($pairs | Sort-Object Value, Index)
    $ranks = [double[]]::new($Values.Count)
    $i = 0
    while ($i -lt $sorted.Count) {
        $j = $i
        while ($j + 1 -lt $sorted.Count -and [Math]::Abs($sorted[$j + 1].Value - $sorted[$i].Value) -lt 1e-12) {
            $j++
        }
        $avgRank = 0.5 * (($i + 1) + ($j + 1))
        for ($k = $i; $k -le $j; $k++) {
            $ranks[$sorted[$k].Index] = $avgRank
        }
        $i = $j + 1
    }
    return $ranks
}

function Get-SpearmanCorrelation {
    param([object[]]$X, [object[]]$Y)
    $paired = Get-PairedFiniteSeries $X $Y
    if ($paired.X.Count -lt 3) { return [double]::NaN }
    $rankX = Get-AverageRanks $paired.X
    $rankY = Get-AverageRanks $paired.Y
    return Get-PearsonCorrelation $rankX $rankY
}

function Add-PointSeries {
    param(
        [System.Windows.Forms.DataVisualization.Charting.Chart]$Chart,
        [string]$Name,
        [double[]]$X,
        [double[]]$Y,
        [object]$Color,
        [string]$MarkerStyle = 'Circle',
        [int]$MarkerSize = 8,
        [bool]$ShowInLegend = $true
    )
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $Name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Point
    $series.IsVisibleInLegend = $ShowInLegend
    $series.Legend = 'legend'
    $series.ChartArea = 'main'
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::$MarkerStyle
    $series.MarkerSize = $MarkerSize
    if ($null -ne $Color) { $series.Color = $Color }
    for ($i = 0; $i -lt [Math]::Min($X.Length, $Y.Length); $i++) {
        if ([double]::IsNaN($X[$i]) -or [double]::IsInfinity($X[$i]) -or [double]::IsNaN($Y[$i]) -or [double]::IsInfinity($Y[$i])) { continue }
        [void]$series.Points.AddXY($X[$i], $Y[$i])
    }
    $Chart.Series.Add($series)
}

function Load-CollapseResidualData {
    param([string]$RunDir)
    $obsPath = Join-Path $RunDir 'tables\collapse_observables.csv'
    $summaryPath = Join-Path $RunDir 'tables\collapse_quality_summary.csv'
    if (-not (Test-Path -LiteralPath $obsPath)) { throw "Missing collapse observables file: $obsPath" }
    if (-not (Test-Path -LiteralPath $summaryPath)) { throw "Missing collapse summary file: $summaryPath" }
    $rows = @(Import-Csv -Path $obsPath | ForEach-Object {
        [pscustomobject]@{
            T = To-Double $_.T
            collapse_residual = To-Double $_.shift_width_amp_residual
            halfwidth_diff_norm = To-Double $_.halfwidth_diff_norm_existing
            abs_halfwidth_diff_norm = [Math]::Abs((To-Double $_.halfwidth_diff_norm_existing))
            width_I = To-Double $_.width_I
            signal_fraction = To-Double $_.signal_fraction
        }
    } | Sort-Object T)
    $summaryRow = Import-Csv -Path $summaryPath | Where-Object { $_.transform -eq 'shift_width_amp' } | Select-Object -First 1
    if ($null -eq $summaryRow) { throw 'Missing shift_width_amp summary row.' }
    return [pscustomobject]@{
        Rows = $rows
        OverallMeanResidual = To-Double $summaryRow.mean_residual
        OverallGlobalResidual = To-Double $summaryRow.global_residual
    }
}

function Load-SvdRows {
    param([string]$RunDir)
    $path = Join-Path $RunDir 'svd_mode_coefficients.csv'
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing SVD coefficients file: $path" }
    return @(Import-Csv -Path $path | ForEach-Object {
        [pscustomobject]@{
            T = [double][Math]::Round((To-Double $_.T))
            mode2_coeff = To-Double $_.mode2_coeff
            mode3_coeff = To-Double $_.mode3_coeff
        }
    } | Sort-Object T)
}

function New-CorrelationRow {
    param([string]$MetricName, [string]$XName, [string]$YName, [object[]]$X, [object[]]$Y, [string]$Interpretation)
    $paired = Get-PairedFiniteSeries $X $Y
    return [pscustomobject]@{
        metric_name = $MetricName
        x_metric = $XName
        y_metric = $YName
        pearson_r = Get-PearsonCorrelation $paired.X $paired.Y
        spearman_rho = Get-SpearmanCorrelation $paired.X $paired.Y
        overlap_count = $paired.X.Count
        interpretation = $Interpretation
    }
}

function Get-LinearFit {
    param([object[]]$X, [object[]]$Y)
    $paired = Get-PairedFiniteSeries $X $Y
    if ($paired.X.Count -lt 2) {
        return [pscustomobject]@{ Valid = $false; X = [double[]]@(); Y = [double[]]@() }
    }
    $mx = Get-Mean $paired.X
    $my = Get-Mean $paired.Y
    $sumXY = 0.0
    $sumXX = 0.0
    for ($i = 0; $i -lt $paired.X.Count; $i++) {
        $dx = $paired.X[$i] - $mx
        $dy = $paired.Y[$i] - $my
        $sumXY += $dx * $dy
        $sumXX += $dx * $dx
    }
    if ($sumXX -le 0) {
        return [pscustomobject]@{ Valid = $false; X = [double[]]@(); Y = [double[]]@() }
    }
    $slope = $sumXY / $sumXX
    $intercept = $my - $slope * $mx
    $minX = ($paired.X | Measure-Object -Minimum).Minimum
    $maxX = ($paired.X | Measure-Object -Maximum).Maximum
    $lineX = [double[]]::new(2)
    $lineY = [double[]]::new(2)
    $lineX[0] = $minX
    $lineX[1] = $maxX
    $lineY[0] = $intercept + ($slope * $minX)
    $lineY[1] = $intercept + ($slope * $maxX)
    return [pscustomobject]@{
        Valid = $true
        X = $lineX
        Y = $lineY
    }
}

function Assign-AsymmetryBins {
    param([object[]]$Rows)
    $sorted = @($Rows | Sort-Object abs_halfwidth_diff_norm, T)
    $labels = @('low_asymmetry', 'medium_asymmetry', 'high_asymmetry')
    $out = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $sorted.Count; $i++) {
        $binIndex = [Math]::Min(2, [int][Math]::Floor(3.0 * $i / [Math]::Max($sorted.Count, 1)))
        [void]$out.Add([pscustomobject]@{
            T = $sorted[$i].T
            collapse_residual = $sorted[$i].collapse_residual
            halfwidth_diff_norm = $sorted[$i].halfwidth_diff_norm
            abs_halfwidth_diff_norm = $sorted[$i].abs_halfwidth_diff_norm
            width_I = $sorted[$i].width_I
            signal_fraction = $sorted[$i].signal_fraction
            mode2_coeff = $sorted[$i].mode2_coeff
            mode3_coeff = $sorted[$i].mode3_coeff
            asymmetry_bin_index = $binIndex + 1
            asymmetry_bin_label = $labels[$binIndex]
        })
    }
    return $out.ToArray()
}

$RepoRoot = Get-RepoRootPath $RepoRoot
$collapseRunDir = Join-Path $RepoRoot ("results\cross_experiment\runs\{0}" -f $CollapseRunName)
$switchRunDir = Join-Path $RepoRoot ("results\switching\runs\{0}" -f $SwitchRunName)
if (-not (Test-Path -LiteralPath $collapseRunDir)) { throw "Collapse run not found: $collapseRunDir" }
if (-not (Test-Path -LiteralPath $switchRunDir)) { throw "Switching run not found: $switchRunDir" }

$config = [ordered]@{
    collapse_run = $CollapseRunName
    switching_run = $SwitchRunName
    target_transform = 'shift_width_amp'
    asymmetry_metric = 'halfwidth_diff_norm'
    binning_strategy = 'three tertiles in |halfwidth_diff_norm|'
    correlation_metrics = @('pearson', 'spearman')
}
$run = New-RunContext -RepoRootPath $RepoRoot -Experiment 'cross_experiment' -Label $RunLabel -Dataset ("collapse:{0} | switching:{1}" -f $CollapseRunName, $SwitchRunName) -Config $config
Append-Line -Path $run.LogPath -Text ("[{0}] sources: collapse:{1} | switching:{2}" -f (Stamp-Now), $CollapseRunName, $SwitchRunName)
Write-Output ("Run directory: {0}" -f $run.RunDir)

$collapseData = Load-CollapseResidualData $collapseRunDir
$switchingData = Load-SwitchingData $switchRunDir
$svdRows = Load-SvdRows $switchRunDir
Append-Line -Path $run.LogPath -Text ("[{0}] loaded collapse residuals, switching curves, and SVD coefficients" -f (Stamp-Now))

$svdByT = @{}
foreach ($row in $svdRows) {
    $svdByT[$row.T.ToString('F0', $Invariant)] = $row
}
$curvesByT = @{}
foreach ($curve in $switchingData.Curves) {
    $curvesByT[$curve.T.ToString('F0', $Invariant)] = $curve
}

$mergedRows = foreach ($row in $collapseData.Rows) {
    $tKey = ([double][Math]::Round($row.T)).ToString('F0', $Invariant)
    $mode2 = [double]::NaN
    $mode3 = [double]::NaN
    if ($svdByT.ContainsKey($tKey)) {
        $mode2 = $svdByT[$tKey].mode2_coeff
        $mode3 = $svdByT[$tKey].mode3_coeff
    }
    [pscustomobject]@{
        T = $row.T
        collapse_residual = $row.collapse_residual
        halfwidth_diff_norm = $row.halfwidth_diff_norm
        abs_halfwidth_diff_norm = $row.abs_halfwidth_diff_norm
        width_I = $row.width_I
        signal_fraction = $row.signal_fraction
        mode2_coeff = $mode2
        mode3_coeff = $mode3
    }
}
$mergedRows = @($mergedRows | Sort-Object T)

$validRows = @($mergedRows | Where-Object {
    -not [double]::IsNaN([double]$_.collapse_residual) -and
    -not [double]::IsInfinity([double]$_.collapse_residual) -and
    -not [double]::IsNaN([double]$_.halfwidth_diff_norm) -and
    -not [double]::IsInfinity([double]$_.halfwidth_diff_norm)
})
if ($validRows.Count -lt 6) { throw 'Not enough finite residual/asymmetry pairs for analysis.' }

$annotatedRows = Assign-AsymmetryBins $validRows
$annotatedByT = @{}
foreach ($row in $annotatedRows) {
    $annotatedByT[$row.T.ToString('F0', $Invariant)] = $row
}

$rawTable = foreach ($row in $mergedRows) {
    $tKey = ([double][Math]::Round($row.T)).ToString('F0', $Invariant)
    $binIndex = $null
    $binLabel = ''
    if ($annotatedByT.ContainsKey($tKey)) {
        $binIndex = $annotatedByT[$tKey].asymmetry_bin_index
        $binLabel = $annotatedByT[$tKey].asymmetry_bin_label
    }
    [pscustomobject]@{
        T = $row.T
        collapse_residual = $row.collapse_residual
        halfwidth_diff_norm = $row.halfwidth_diff_norm
        abs_halfwidth_diff_norm = $row.abs_halfwidth_diff_norm
        mode2_coeff = $row.mode2_coeff
        mode3_coeff = $row.mode3_coeff
        width_I = $row.width_I
        signal_fraction = $row.signal_fraction
        asymmetry_bin_index = $binIndex
        asymmetry_bin_label = $binLabel
    }
}
$rawTable = @($rawTable | Sort-Object T)

$correlations = @(
    (New-CorrelationRow -MetricName 'residual_vs_halfwidth_diff_norm' -XName 'halfwidth_diff_norm' -YName 'collapse_residual' -X ($validRows | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($validRows | ForEach-Object { $_.collapse_residual }) -Interpretation 'Primary signed asymmetry test'),
    (New-CorrelationRow -MetricName 'residual_vs_abs_halfwidth_diff_norm' -XName '|halfwidth_diff_norm|' -YName 'collapse_residual' -X ($validRows | ForEach-Object { $_.abs_halfwidth_diff_norm }) -Y ($validRows | ForEach-Object { $_.collapse_residual }) -Interpretation 'Supplementary asymmetry magnitude test'),
    (New-CorrelationRow -MetricName 'residual_vs_mode2_coeff' -XName 'mode2_coeff' -YName 'collapse_residual' -X ($validRows | ForEach-Object { $_.mode2_coeff }) -Y ($validRows | ForEach-Object { $_.collapse_residual }) -Interpretation 'Residual linked to SVD mode 2'),
    (New-CorrelationRow -MetricName 'residual_vs_mode3_coeff' -XName 'mode3_coeff' -YName 'collapse_residual' -X ($validRows | ForEach-Object { $_.mode3_coeff }) -Y ($validRows | ForEach-Object { $_.collapse_residual }) -Interpretation 'Residual linked to SVD mode 3'),
    (New-CorrelationRow -MetricName 'halfwidth_diff_norm_vs_mode2_coeff' -XName 'halfwidth_diff_norm' -YName 'mode2_coeff' -X ($validRows | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($validRows | ForEach-Object { $_.mode2_coeff }) -Interpretation 'Does mode 2 track signed asymmetry?'),
    (New-CorrelationRow -MetricName 'halfwidth_diff_norm_vs_mode3_coeff' -XName 'halfwidth_diff_norm' -YName 'mode3_coeff' -X ($validRows | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($validRows | ForEach-Object { $_.mode3_coeff }) -Interpretation 'Does mode 3 track signed asymmetry?')
)

$binSummaries = foreach ($binName in @('low_asymmetry', 'medium_asymmetry', 'high_asymmetry')) {
    $binRows = @($annotatedRows | Where-Object { $_.asymmetry_bin_label -eq $binName } | Sort-Object T)
    if ($binRows.Count -eq 0) { continue }
    $subsetCurves = New-Object System.Collections.Generic.List[object]
    foreach ($row in $binRows) {
        $tKey = ([double][Math]::Round($row.T)).ToString('F0', $Invariant)
        if ($curvesByT.ContainsKey($tKey)) {
            [void]$subsetCurves.Add($curvesByT[$tKey])
        }
    }
    $eval = Evaluate-Transform -Curves $subsetCurves -TransformName 'shift_width_amp'
    [pscustomobject]@{
        asymmetry_bin_label = $binName
        asymmetry_bin_index = $binRows[0].asymmetry_bin_index
        n_temperatures = $binRows.Count
        temperatures = (($binRows | ForEach-Object { $_.T.ToString('F0', $Invariant) }) -join ', ')
        abs_asymmetry_min = ($binRows | Measure-Object -Property abs_halfwidth_diff_norm -Minimum).Minimum
        abs_asymmetry_max = ($binRows | Measure-Object -Property abs_halfwidth_diff_norm -Maximum).Maximum
        mean_abs_asymmetry = Get-Mean ($binRows | ForEach-Object { $_.abs_halfwidth_diff_norm })
        mean_signed_asymmetry = Get-Mean ($binRows | ForEach-Object { $_.halfwidth_diff_norm })
        mean_original_residual = Get-Mean ($binRows | ForEach-Object { $_.collapse_residual })
        median_original_residual = Get-Median ($binRows | ForEach-Object { $_.collapse_residual })
        recomputed_mean_residual = $eval.Summary.mean_residual
        recomputed_global_residual = $eval.Summary.global_residual
        kernel_point_count = $eval.Summary.kernel_point_count
        valid_temperature_count = $eval.Summary.valid_temperature_count
        relative_improvement_vs_all_temp_global = 1.0 - ($eval.Summary.global_residual / [Math]::Max($collapseData.OverallGlobalResidual, 1e-9))
        relative_improvement_vs_all_temp_mean = 1.0 - ($eval.Summary.mean_residual / [Math]::Max($collapseData.OverallMeanResidual, 1e-9))
    }
}
$binSummaries = @($binSummaries | Sort-Object asymmetry_bin_index)
Append-Line -Path $run.LogPath -Text ("[{0}] computed correlations and asymmetry-bin collapse summaries" -f (Stamp-Now))

Write-RunTable -Rows $rawTable -Path (Join-Path $run.TablesDir 'collapse_residual_vs_asymmetry.csv')
Write-RunTable -Rows $binSummaries -Path (Join-Path $run.TablesDir 'asymmetry_bin_residuals.csv')
Write-RunTable -Rows $correlations -Path (Join-Path $run.TablesDir 'residual_mode_correlations.csv')
Append-Line -Path $run.LogPath -Text ("[{0}] wrote tables" -f (Stamp-Now))

$scatterChart = New-LineChart -Title 'Collapse residual vs halfwidth asymmetry' -XAxisTitle 'halfwidth_diff_norm' -YAxisTitle 'shift_width_amp residual norm'
Add-PointSeries -Chart $scatterChart -Name 'temperatures' -X ([double[]]@($validRows | ForEach-Object { $_.halfwidth_diff_norm })) -Y ([double[]]@($validRows | ForEach-Object { $_.collapse_residual })) -Color (Hex-Color '#1F77B4') -MarkerStyle 'Circle' -MarkerSize 9
$fit = Get-LinearFit -X ($validRows | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($validRows | ForEach-Object { $_.collapse_residual })
if ($fit.Valid) {
    Add-LineSeries -Chart $scatterChart -Name 'linear trend' -X $fit.X -Y $fit.Y -Color (Hex-Color '#D62728') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 3
}
Save-Chart -Chart $scatterChart -Path (Join-Path $run.FiguresDir 'residual_vs_asymmetry_scatter.png')

$binChart = New-LineChart -Title 'Collapse residual by asymmetry tertile' -XAxisTitle 'Asymmetry tertile (1=low, 2=medium, 3=high)' -YAxisTitle 'Residual norm'
$binX = [double[]]@($binSummaries | ForEach-Object { [double]$_.asymmetry_bin_index })
Add-LineSeries -Chart $binChart -Name 'mean per-temperature residual' -X $binX -Y ([double[]]@($binSummaries | ForEach-Object { [double]$_.mean_original_residual })) -Color (Hex-Color '#2CA02C') -MarkerStyle 'Circle' -BorderWidth 3
Add-LineSeries -Chart $binChart -Name 'recomputed within-bin global residual' -X $binX -Y ([double[]]@($binSummaries | ForEach-Object { [double]$_.recomputed_global_residual })) -Color (Hex-Color '#FF7F0E') -MarkerStyle 'Diamond' -BorderWidth 3
Add-LineSeries -Chart $binChart -Name 'all-temperature global residual' -X ([double[]]@(1.0, 3.0)) -Y ([double[]]@($collapseData.OverallGlobalResidual, $collapseData.OverallGlobalResidual)) -Color (Hex-Color '#7F7F7F') -DashStyle 'Dash' -MarkerStyle 'None' -BorderWidth 2
Save-Chart -Chart $binChart -Path (Join-Path $run.FiguresDir 'collapse_by_asymmetry_bin.png')
Append-Line -Path $run.LogPath -Text ("[{0}] wrote figures" -f (Stamp-Now))

$primaryCorr = $correlations | Where-Object { $_.metric_name -eq 'residual_vs_halfwidth_diff_norm' } | Select-Object -First 1
$absCorr = $correlations | Where-Object { $_.metric_name -eq 'residual_vs_abs_halfwidth_diff_norm' } | Select-Object -First 1
$mode2Corr = $correlations | Where-Object { $_.metric_name -eq 'residual_vs_mode2_coeff' } | Select-Object -First 1
$mode3Corr = $correlations | Where-Object { $_.metric_name -eq 'residual_vs_mode3_coeff' } | Select-Object -First 1
$mode2Asym = $correlations | Where-Object { $_.metric_name -eq 'halfwidth_diff_norm_vs_mode2_coeff' } | Select-Object -First 1
$mode3Asym = $correlations | Where-Object { $_.metric_name -eq 'halfwidth_diff_norm_vs_mode3_coeff' } | Select-Object -First 1
$bestBin = $binSummaries | Sort-Object recomputed_global_residual | Select-Object -First 1
$worstBin = $binSummaries | Sort-Object recomputed_global_residual -Descending | Select-Object -First 1

$reportLines = @(
    '# Switching Collapse Asymmetry Test'
    ''
    '## 1. Repository State Summary'
    '- Reused the completed collapse run `run_2026_03_11_224153_switching_collapse_kernel_analysis`, specifically `tables/collapse_observables.csv` and `tables/collapse_quality_summary.csv`, to obtain the per-temperature `shift_width_amp` residuals and the all-temperature reference residual.'
    '- Reused the canonical switching producer `Switching/analysis/switching_alignment_audit.m` through saved exports in `run_2026_03_10_112659_alignment_audit`: `alignment_audit/switching_alignment_samples.csv`, `alignment_audit/switching_alignment_observables_vs_T.csv`, and `svd_mode_coefficients.csv`.'
    '- Existing observables reused directly: `halfwidth_diff_norm`, `Ipeak`, `S_peak`, `width_I`, and the saved SVD coefficients `mode2_coeff(T)` and `mode3_coeff(T)`.'
    '- No existing dedicated residual-vs-asymmetry or asymmetry-binned collapse test was found. This new analysis attaches as a standalone script under `analysis/` and consumes saved run outputs only.'
    ''
    '## 2. Code Inspected'
    '- `docs/AGENT_RULES.md`'
    '- `docs/results_system.md`'
    '- `docs/repository_structure.md`'
    '- `docs/visualization_rules.md`'
    '- `docs/output_artifacts.md`'
    '- `Switching/analysis/switching_alignment_audit.m`'
    '- `analysis/switching_collapse_kernel_analysis.ps1`'
    ''
    '## 3. Code Changed'
    '- Added `analysis/switching_collapse_asymmetry_test.ps1`.'
    '- No existing pipeline code was modified.'
    ''
    '## 4. Analyses Run'
    '- Extracted the per-temperature residuals for the best prior transform: `shift_width_amp`.'
    '- Computed Pearson and Spearman correlations between collapse residual and signed `halfwidth_diff_norm`, plus a supplementary magnitude check with `|halfwidth_diff_norm|`.'
    '- Computed Pearson and Spearman correlations between collapse residual and `mode2_coeff(T)` / `mode3_coeff(T)`, and between signed `halfwidth_diff_norm` and those same SVD modes.'
    '- Split temperatures into three tertiles by `|halfwidth_diff_norm|` and recomputed the `shift_width_amp` kernel collapse within each bin.'
    ''
    '## 5. Main Results'
    ('- Residual vs signed `halfwidth_diff_norm`: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}` over `{2}` temperatures.' -f $primaryCorr.pearson_r, $primaryCorr.spearman_rho, $primaryCorr.overlap_count)
    ('- Residual vs `|halfwidth_diff_norm|` (supplementary): Pearson `r = {0:N3}`, Spearman `rho = {1:N3}` over `{2}` temperatures.' -f $absCorr.pearson_r, $absCorr.spearman_rho, $absCorr.overlap_count)
    ('- Residual vs `mode2_coeff`: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}`.' -f $mode2Corr.pearson_r, $mode2Corr.spearman_rho)
    ('- Residual vs `mode3_coeff`: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}`.' -f $mode3Corr.pearson_r, $mode3Corr.spearman_rho)
    ('- Signed asymmetry vs `mode2_coeff`: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}`.' -f $mode2Asym.pearson_r, $mode2Asym.spearman_rho)
    ('- Signed asymmetry vs `mode3_coeff`: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}`.' -f $mode3Asym.pearson_r, $mode3Asym.spearman_rho)
    ('- Best bin-specific recomputed collapse: `{0}` with global residual `{1:N3}` over `{2}` temperatures (`{3}`).' -f $bestBin.asymmetry_bin_label, $bestBin.recomputed_global_residual, $bestBin.n_temperatures, $bestBin.temperatures)
    ('- Worst bin-specific recomputed collapse: `{0}` with global residual `{1:N3}` over `{2}` temperatures (`{3}`).' -f $worstBin.asymmetry_bin_label, $worstBin.recomputed_global_residual, $worstBin.n_temperatures, $worstBin.temperatures)
    ''
    '## 6. Interpretation'
    '### 6.1 Whether collapse residual correlates with `halfwidth_diff_norm`'
    ('- The requested signed correlation test gives Pearson `r = {0:N3}` and Spearman `rho = {1:N3}`. This is descriptive evidence only; it does not establish asymmetry as the unique control variable.' -f $primaryCorr.pearson_r, $primaryCorr.spearman_rho)
    ('- Because `low / medium / high asymmetry` is a magnitude concept, the report also checks `|halfwidth_diff_norm|`; that gives Pearson `r = {0:N3}` and Spearman `rho = {1:N3}`.' -f $absCorr.pearson_r, $absCorr.spearman_rho)
    '### 6.2 Whether grouping by asymmetry improves collapse'
    ('- The all-temperature reference global residual is `{0:N3}`. Bin-specific recomputed global residuals are reported in `asymmetry_bin_residuals.csv`; the best bin reaches `{1:N3}` and the worst bin `{2:N3}`.' -f $collapseData.OverallGlobalResidual, $bestBin.recomputed_global_residual, $worstBin.recomputed_global_residual)
    '- Any improvement from binning should be read cautiously because splitting the temperature set reduces heterogeneity by construction.'
    '### 6.3 Whether mode 2 or mode 3 capture the same effect'
    ('- `mode2_coeff` has residual correlations (Pearson `{0:N3}`, Spearman `{1:N3}`) and asymmetry correlations (Pearson `{2:N3}`, Spearman `{3:N3}`).' -f $mode2Corr.pearson_r, $mode2Corr.spearman_rho, $mode2Asym.pearson_r, $mode2Asym.spearman_rho)
    ('- `mode3_coeff` has residual correlations (Pearson `{0:N3}`, Spearman `{1:N3}`) and asymmetry correlations (Pearson `{2:N3}`, Spearman `{3:N3}`).' -f $mode3Corr.pearson_r, $mode3Corr.spearman_rho, $mode3Asym.pearson_r, $mode3Asym.spearman_rho)
    '- A mode is only a clean proxy for the same distortion if it is associated with both residual and asymmetry. This report keeps that comparison descriptive.'
    ''
    '## 7. Remaining Uncertainty'
    '- The temperature grid is small (`16` temperatures), so both Pearson and Spearman values are sensitive to a few endpoint temperatures.'
    '- The reused `halfwidth_diff_norm` export takes only a few repeated values in this run set, which limits the resolution of both correlation and tertile binning.'
    '- The SVD coefficients are descriptive coordinates of the switching map, not independently validated asymmetry observables.'
    '- Bin-specific collapse was recomputed using the same saved curves and the same best transform from the prior run; it does not introduce a new fitted remap inside each bin.'
    ''
    '## Visualization choices'
    '- number of curves: the scatter figure uses one point set plus one fit line; the bin figure uses three summary traces.'
    '- legend vs colormap: legends were used because each figure has at most three plotted series.'
    '- colormap used: none; discrete line and marker colors were chosen because these are summary plots.'
    '- smoothing applied: none.'
    '- justification: the figures are meant to answer whether residual tracks asymmetry and whether asymmetry grouping changes collapse quality.'
)
$reportPath = Join-Path $run.ReportsDir 'switching_collapse_asymmetry_test.md'
Write-TextUtf8 -Path $reportPath -Text ($reportLines -join [Environment]::NewLine)
Append-Line -Path $run.LogPath -Text ("[{0}] wrote report" -f (Stamp-Now))

$notes = @(
    'Key observations:'
    ('- signed asymmetry correlation: pearson={0:N3}, spearman={1:N3}' -f $primaryCorr.pearson_r, $primaryCorr.spearman_rho)
    ('- asymmetry magnitude correlation: pearson={0:N3}, spearman={1:N3}' -f $absCorr.pearson_r, $absCorr.spearman_rho)
    ('- best bin: {0} -> global residual {1:N3}' -f $bestBin.asymmetry_bin_label, $bestBin.recomputed_global_residual)
    ('- worst bin: {0} -> global residual {1:N3}' -f $worstBin.asymmetry_bin_label, $worstBin.recomputed_global_residual)
) -join [Environment]::NewLine
Write-TextUtf8 -Path $run.NotesPath -Text $notes

$zipPath = Build-ZipBundle -Run $run -ZipName 'switching_collapse_asymmetry_bundle.zip'
Append-Line -Path $run.LogPath -Text ("[{0}] wrote review bundle: {1}" -f (Stamp-Now), $zipPath)

Write-Output ("Report: {0}" -f $reportPath)
Write-Output ("Review bundle: {0}" -f $zipPath)
