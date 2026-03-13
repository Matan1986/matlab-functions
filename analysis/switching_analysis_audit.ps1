param(
    [string]$RepoRoot = '',
    [string]$SwitchRunName = 'run_2026_03_10_112659_alignment_audit',
    [string]$CollapseRunName = 'run_2026_03_11_224153_switching_collapse_kernel_analysis',
    [string]$AsymmetryRunName = 'run_2026_03_11_235752_switching_collapse_asymmetry_test',
    [string]$RunLabel = 'switching_analysis_audit'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

$helperPath = Join-Path $PSScriptRoot 'switching_collapse_kernel_analysis.ps1'
$helperText = Get-Content -LiteralPath $helperPath -Raw
$startIndex = $helperText.IndexOf('function Get-RepoRootPath {')
$endIndex = $helperText.IndexOf('$RepoRoot = Get-RepoRootPath $RepoRoot')
if ($startIndex -lt 0 -or $endIndex -le $startIndex) { throw 'Could not isolate helper functions.' }
Invoke-Expression ($helperText.Substring($startIndex, $endIndex - $startIndex))
$ThisScriptRoot = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
function Get-RepoRootPath {
    param([string]$InputRepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($InputRepoRoot)) { return (Resolve-Path $InputRepoRoot).Path }
    return (Split-Path $ThisScriptRoot -Parent)
}
function Get-PairedFiniteSeries {
    param([object[]]$X,[object[]]$Y)
    $xs = New-Object System.Collections.Generic.List[double]
    $ys = New-Object System.Collections.Generic.List[double]
    for ($i=0; $i -lt [Math]::Min($X.Count,$Y.Count); $i++) {
        $xv = [double]$X[$i]; $yv = [double]$Y[$i]
        if ([double]::IsNaN($xv) -or [double]::IsInfinity($xv) -or [double]::IsNaN($yv) -or [double]::IsInfinity($yv)) { continue }
        [void]$xs.Add($xv); [void]$ys.Add($yv)
    }
    return [pscustomobject]@{ X = $xs; Y = $ys }
}
function Get-AverageRanks {
    param([System.Collections.Generic.List[double]]$Values)
    $pairs = New-Object System.Collections.Generic.List[object]
    for ($i=0; $i -lt $Values.Count; $i++) { [void]$pairs.Add([pscustomobject]@{ Index=$i; Value=$Values[$i] }) }
    $sorted = @($pairs | Sort-Object Value, Index)
    $ranks = [double[]]::new($Values.Count)
    $i = 0
    while ($i -lt $sorted.Count) {
        $j = $i
        while ($j + 1 -lt $sorted.Count -and [Math]::Abs($sorted[$j + 1].Value - $sorted[$i].Value) -lt 1e-12) { $j++ }
        $avg = 0.5 * (($i + 1) + ($j + 1))
        for ($k = $i; $k -le $j; $k++) { $ranks[$sorted[$k].Index] = $avg }
        $i = $j + 1
    }
    return $ranks
}
function Get-SpearmanCorrelation {
    param([object[]]$X,[object[]]$Y)
    $paired = Get-PairedFiniteSeries $X $Y
    if ($paired.X.Count -lt 3) { return [double]::NaN }
    return Get-PearsonCorrelation (Get-AverageRanks $paired.X) (Get-AverageRanks $paired.Y)
}
function Add-PointSeries {
    param([System.Windows.Forms.DataVisualization.Charting.Chart]$Chart,[string]$Name,[double[]]$X,[double[]]$Y,[object]$Color,[string]$MarkerStyle='Circle',[int]$MarkerSize=8)
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $Name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Point
    $series.Legend = 'legend'; $series.ChartArea = 'main'; $series.IsVisibleInLegend = $true
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::$MarkerStyle
    $series.MarkerSize = $MarkerSize
    if ($null -ne $Color) { $series.Color = $Color }
    for ($i=0; $i -lt [Math]::Min($X.Length,$Y.Length); $i++) {
        if ([double]::IsNaN($X[$i]) -or [double]::IsNaN($Y[$i])) { continue }
        [void]$series.Points.AddXY($X[$i], $Y[$i])
    }
    $Chart.Series.Add($series)
}
function Normalize-MinMax {
    param([object[]]$Values)
    $arr = [double[]]::new($Values.Count)
    for ($i=0; $i -lt $Values.Count; $i++) { $arr[$i] = [double]$Values[$i] }
    $finite = Get-FiniteValues $arr
    if ($finite.Count -lt 2) { return $arr }
    $minVal = ($finite | Measure-Object -Minimum).Minimum
    $maxVal = ($finite | Measure-Object -Maximum).Maximum
    if ($maxVal -le $minVal) { return $arr }
    for ($i=0; $i -lt $arr.Length; $i++) { if (-not [double]::IsNaN($arr[$i])) { $arr[$i] = ($arr[$i]-$minVal)/($maxVal-$minVal) } }
    return $arr
}
function Get-CorrelationStats {
    param([string]$XName,[string]$YName,[object[]]$X,[object[]]$Y)
    $paired = Get-PairedFiniteSeries $X $Y
    $note = ''
    if ($paired.X.Count -gt 0 -and @($paired.X | Sort-Object -Unique).Count -lt 2) { $note = 'x is constant within subset' }
    if ($paired.X.Count -eq 0) { $note = 'no finite overlap' }
    return [pscustomobject]@{ x_metric=$XName; y_metric=$YName; overlap_count=$paired.X.Count; pearson_r=(Get-PearsonCorrelation $paired.X $paired.Y); spearman_rho=(Get-SpearmanCorrelation $paired.X $paired.Y); note=$note }
}
function Get-RegimeName {
    param([double]$Temperature)
    if ($Temperature -le 10) { return 'low_T' }
    if ($Temperature -le 20) { return 'crossover' }
    return 'high_T'
}
function Find-FirstExistingPath {
    param([string[]]$CandidatePaths)
    foreach ($candidate in $CandidatePaths) { if (Test-Path -LiteralPath $candidate) { return $candidate } }
    return $null
}$RepoRoot = Get-RepoRootPath $RepoRoot
$switchRunDir = Join-Path $RepoRoot ("results\switching\runs\{0}" -f $SwitchRunName)
$collapseRunDir = Join-Path $RepoRoot ("results\cross_experiment\runs\{0}" -f $CollapseRunName)
$asymRunDir = Join-Path $RepoRoot ("results\cross_experiment\runs\{0}" -f $AsymmetryRunName)
foreach ($dir in @($switchRunDir,$collapseRunDir,$asymRunDir)) { if (-not (Test-Path -LiteralPath $dir)) { throw "Missing required run: $dir" } }
$config = [ordered]@{ switching_run=$SwitchRunName; collapse_run=$CollapseRunName; asymmetry_run=$AsymmetryRunName; regime_definition='low=4-10 K; crossover=12-20 K; high=22-34 K'; data_policy='saved outputs only' }
$run = New-RunContext -RepoRootPath $RepoRoot -Experiment 'cross_experiment' -Label $RunLabel -Dataset ("switch:{0} | collapse:{1} | asym:{2}" -f $SwitchRunName,$CollapseRunName,$AsymmetryRunName) -Config $config
Append-Line -Path $run.LogPath -Text ("[{0}] sources: switch:{1} | collapse:{2} | asym:{3}" -f (Stamp-Now),$SwitchRunName,$CollapseRunName,$AsymmetryRunName)
Write-Output ("Run directory: {0}" -f $run.RunDir)

$inventoryRows = New-Object System.Collections.Generic.List[object]
foreach ($entry in @([pscustomobject]@{experiment='switching';root=(Join-Path $RepoRoot 'results\switching\runs')},[pscustomobject]@{experiment='cross_experiment';root=(Join-Path $RepoRoot 'results\cross_experiment\runs')})) {
    foreach ($dir in @(Get-ChildItem -Path $entry.root -Directory | Sort-Object Name)) {
        $hasObs = (Test-Path -LiteralPath (Join-Path $dir.FullName 'observables.csv')) -or (Test-Path -LiteralPath (Join-Path $dir.FullName 'tables\observables.csv'))
        $hasObsMatrix = Test-Path -LiteralPath (Join-Path $dir.FullName 'observable_matrix.csv')
        $hasSvdCoeff = Test-Path -LiteralPath (Join-Path $dir.FullName 'svd_mode_coefficients.csv')
        $hasSvdSing = ($null -ne (Find-FirstExistingPath @((Join-Path $dir.FullName 'switching_alignment_svd_singular_values.csv'),(Join-Path $dir.FullName 'alignment_audit\switching_alignment_svd_singular_values.csv'),(Join-Path $dir.FullName 'tables\switching_alignment_svd_singular_values.csv'))))
        $hasCollapse = (Test-Path -LiteralPath (Join-Path $dir.FullName 'tables\collapse_quality_summary.csv')) -or (Test-Path -LiteralPath (Join-Path $dir.FullName 'tables\collapse_observables.csv'))
        $hasAsym = Test-Path -LiteralPath (Join-Path $dir.FullName 'tables\collapse_residual_vs_asymmetry.csv')
        if (-not ($hasObs -or $hasObsMatrix -or $hasSvdCoeff -or $hasSvdSing -or $hasCollapse -or $hasAsym)) { continue }
        [void]$inventoryRows.Add([pscustomobject]@{ experiment=$entry.experiment; run_name=$dir.Name; run_path=$dir.FullName; has_observables_csv=$hasObs; has_observable_matrix_csv=$hasObsMatrix; has_svd_mode_coefficients_csv=$hasSvdCoeff; has_svd_singular_values_csv=$hasSvdSing; has_collapse_analysis_tables=$hasCollapse; has_asymmetry_test_tables=$hasAsym })
    }
}
$inventoryRows = @($inventoryRows | Sort-Object experiment, run_name)

$filesUsed = @(
    [pscustomobject]@{ purpose='canonical switching observables'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'observables.csv') },
    [pscustomobject]@{ purpose='canonical switching observable matrix'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'observable_matrix.csv') },
    [pscustomobject]@{ purpose='temperature observables'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'alignment_audit\switching_alignment_observables_vs_T.csv') },
    [pscustomobject]@{ purpose='svd singular values'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'switching_alignment_svd_singular_values.csv') },
    [pscustomobject]@{ purpose='svd mode coefficients'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'svd_mode_coefficients.csv') },
    [pscustomobject]@{ purpose='characteristic temperatures'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'alignment_audit\switching_alignment_characteristic_temperatures.csv') },
    [pscustomobject]@{ purpose='saved mode-observable correlations'; run_name=$SwitchRunName; file_path=(Join-Path $switchRunDir 'switching_alignment_mode_observable_correlations.csv') },
    [pscustomobject]@{ purpose='collapse quality summary'; run_name=$CollapseRunName; file_path=(Join-Path $collapseRunDir 'tables\collapse_quality_summary.csv') },
    [pscustomobject]@{ purpose='collapse observables'; run_name=$CollapseRunName; file_path=(Join-Path $collapseRunDir 'tables\collapse_observables.csv') },
    [pscustomobject]@{ purpose='asymmetry residual table'; run_name=$AsymmetryRunName; file_path=(Join-Path $asymRunDir 'tables\collapse_residual_vs_asymmetry.csv') },
    [pscustomobject]@{ purpose='asymmetry correlation table'; run_name=$AsymmetryRunName; file_path=(Join-Path $asymRunDir 'tables\residual_mode_correlations.csv') }
)

$svdSingRows = @(Import-Csv -Path (Join-Path $switchRunDir 'switching_alignment_svd_singular_values.csv'))
$modeCoeffRows = @(Import-Csv -Path (Join-Path $switchRunDir 'svd_mode_coefficients.csv'))
$obsVsTRows = @(Import-Csv -Path (Join-Path $switchRunDir 'alignment_audit\switching_alignment_observables_vs_T.csv'))
$observableMatrixRows = @(Import-Csv -Path (Join-Path $switchRunDir 'observable_matrix.csv'))
$charRows = @(Import-Csv -Path (Join-Path $switchRunDir 'alignment_audit\switching_alignment_characteristic_temperatures.csv'))
$modeObsCorrRows = @(Import-Csv -Path (Join-Path $switchRunDir 'switching_alignment_mode_observable_correlations.csv'))
$collapseSummaryRows = @(Import-Csv -Path (Join-Path $collapseRunDir 'tables\collapse_quality_summary.csv'))
$collapseObsRows = @(Import-Csv -Path (Join-Path $collapseRunDir 'tables\collapse_observables.csv'))
$asymRows = @(Import-Csv -Path (Join-Path $asymRunDir 'tables\collapse_residual_vs_asymmetry.csv'))
Append-Line -Path $run.LogPath -Text ("[{0}] loaded saved source tables" -f (Stamp-Now))

$obsByT = @{}; foreach ($row in $obsVsTRows) { $obsByT[[string](To-Double $row.T_K)] = $row }
$modeByT = @{}; foreach ($row in $modeCoeffRows) { $modeByT[[string](To-Double $row.T)] = $row }
$collapseByT = @{}; foreach ($row in $collapseObsRows) { $collapseByT[[string](To-Double $row.T)] = $row }
$asymByT = @{}; foreach ($row in $asymRows) { $asymByT[[string](To-Double $row.T)] = $row }
$originalTemps = @($observableMatrixRows | ForEach-Object { To-Double $_.T } | Sort-Object)
$joinedRows = New-Object System.Collections.Generic.List[object]
$coverageRows = New-Object System.Collections.Generic.List[object]
foreach ($T in $originalTemps) {
    $key = [string]$T
    $obs = if ($obsByT.ContainsKey($key)) { $obsByT[$key] } else { $null }
    $mode = if ($modeByT.ContainsKey($key)) { $modeByT[$key] } else { $null }
    $coll = if ($collapseByT.ContainsKey($key)) { $collapseByT[$key] } else { $null }
    $asym = if ($asymByT.ContainsKey($key)) { $asymByT[$key] } else { $null }
    $widthI = if ($null -ne $obs) { To-Double $obs.width_I } else { [double]::NaN }
    $halfDiff = if ($null -ne $obs) { To-Double $obs.halfwidth_diff_norm } else { [double]::NaN }
    $residual = if ($null -ne $coll) { To-Double $coll.shift_width_amp_residual } else { [double]::NaN }
    $included = (-not [double]::IsNaN($halfDiff)) -and (-not [double]::IsNaN($residual))
    $reason = if ($included) { 'included' } else { ((@($(if ([double]::IsNaN($halfDiff)) { 'missing halfwidth_diff_norm' }),$(if ([double]::IsNaN($widthI)) { 'missing width_I' }),$(if ([double]::IsNaN($residual)) { 'missing shift_width_amp residual' })) | Where-Object { $_ }) -join '; ') }
    $regime = Get-RegimeName $T
    [void]$joinedRows.Add([pscustomobject]@{ T=$T; regime=$regime; included_in_asymmetry_analysis=$included; asymmetry_bin_label=$(if ($null -ne $asym) { [string]$asym.asymmetry_bin_label } else { '' }); I_peak=$(if ($null -ne $obs) { To-Double $obs.Ipeak } else { [double]::NaN }); S_peak=$(if ($null -ne $obs) { To-Double $obs.S_peak } else { [double]::NaN }); width_I=$widthI; halfwidth_diff_norm=$halfDiff; asym_area_ratio=$(if ($null -ne $obs) { To-Double $obs.asym } else { [double]::NaN }); mode1_coeff=$(if ($null -ne $mode) { To-Double $mode.mode1_coeff } else { [double]::NaN }); mode2_coeff=$(if ($null -ne $mode) { To-Double $mode.mode2_coeff } else { [double]::NaN }); mode3_coeff=$(if ($null -ne $mode) { To-Double $mode.mode3_coeff } else { [double]::NaN }); shift_width_amp_residual=$residual; best_transform=$(if ($null -ne $coll) { [string]$coll.best_transform } else { '' }); signal_fraction=$(if ($null -ne $coll) { To-Double $coll.signal_fraction } else { [double]::NaN }); exclusion_reason=$reason })
    [void]$coverageRows.Add([pscustomobject]@{ T=$T; regime=$regime; included_in_asymmetry_analysis=$included; width_I=$widthI; halfwidth_diff_norm=$halfDiff; shift_width_amp_residual=$residual; exclusion_reason=$reason })
}
$joinedRows = @($joinedRows | Sort-Object T)
$coverageRows = @($coverageRows | Sort-Object T)
$usableRows = @($joinedRows | Where-Object { $_.included_in_asymmetry_analysis })
$energySq = [double[]]::new($svdSingRows.Count)
$sumEnergy = 0.0
for ($i=0; $i -lt $svdSingRows.Count; $i++) { $energySq[$i] = [Math]::Pow((To-Double $svdSingRows[$i].singular_value), 2); $sumEnergy += $energySq[$i] }
$svdSummaryRows = New-Object System.Collections.Generic.List[object]
for ($i=0; $i -lt $svdSingRows.Count; $i++) {
    $modeIndex = [int](To-Double $svdSingRows[$i].mode)
    $energyFrac = if ($sumEnergy -gt 0) { $energySq[$i] / $sumEnergy } else { [double]::NaN }
    [void]$svdSummaryRows.Add([pscustomobject]@{ mode=$modeIndex; singular_value=(To-Double $svdSingRows[$i].singular_value); variance_explained=$energyFrac; cumulative_energy=(To-Double $svdSingRows[$i].cumulative_energy) })
}
$modeResidualRows = New-Object System.Collections.Generic.List[object]
foreach ($modeName in @('mode1_coeff','mode2_coeff','mode3_coeff')) {
    $stats1 = Get-CorrelationStats -XName $modeName -YName 'shift_width_amp_residual' -X ($usableRows | ForEach-Object { $_.$modeName }) -Y ($usableRows | ForEach-Object { $_.shift_width_amp_residual })
    [void]$modeResidualRows.Add([pscustomobject]@{ relation='residual_vs_mode'; x_metric=$stats1.x_metric; y_metric=$stats1.y_metric; pearson_r=$stats1.pearson_r; spearman_rho=$stats1.spearman_rho; overlap_count=$stats1.overlap_count; note=$stats1.note })
    $stats2 = Get-CorrelationStats -XName $modeName -YName 'halfwidth_diff_norm' -X ($usableRows | ForEach-Object { $_.$modeName }) -Y ($usableRows | ForEach-Object { $_.halfwidth_diff_norm })
    [void]$modeResidualRows.Add([pscustomobject]@{ relation='asymmetry_vs_mode'; x_metric=$stats2.x_metric; y_metric=$stats2.y_metric; pearson_r=$stats2.pearson_r; spearman_rho=$stats2.spearman_rho; overlap_count=$stats2.overlap_count; note=$stats2.note })
}
$modeGeometryRows = New-Object System.Collections.Generic.List[object]
foreach ($modeName in @('mode1_coeff','mode2_coeff','mode3_coeff')) {
    foreach ($obsName in @('S_peak','I_peak','width_I','halfwidth_diff_norm')) {
        $stats = Get-CorrelationStats -XName $modeName -YName $obsName -X ($joinedRows | ForEach-Object { $_.$modeName }) -Y ($joinedRows | ForEach-Object { $_.$obsName })
        [void]$modeGeometryRows.Add([pscustomobject]@{ mode=$modeName; observable=$obsName; pearson_r=$stats.pearson_r; spearman_rho=$stats.spearman_rho; overlap_count=$stats.overlap_count; note=$stats.note })
    }
}
$regimeRows = New-Object System.Collections.Generic.List[object]
foreach ($regime in @('low_T','crossover','high_T')) {
    $subset = @($usableRows | Where-Object { $_.regime -eq $regime })
    $stats = Get-CorrelationStats -XName 'halfwidth_diff_norm' -YName 'shift_width_amp_residual' -X ($subset | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($subset | ForEach-Object { $_.shift_width_amp_residual })
    [void]$regimeRows.Add([pscustomobject]@{ regime=$regime; temperature_list=(($coverageRows | Where-Object { $_.regime -eq $regime } | ForEach-Object { $_.T.ToString('F0',$Invariant) }) -join ', '); total_temperatures=@($coverageRows | Where-Object { $_.regime -eq $regime }).Count; usable_temperatures=$stats.overlap_count; pearson_r=$stats.pearson_r; spearman_rho=$stats.spearman_rho; note=$stats.note })
}
$globalResidualVsAsym = Get-CorrelationStats -XName 'halfwidth_diff_norm' -YName 'shift_width_amp_residual' -X ($usableRows | ForEach-Object { $_.halfwidth_diff_norm }) -Y ($usableRows | ForEach-Object { $_.shift_width_amp_residual })
Append-Line -Path $run.LogPath -Text ("[{0}] built correlation summaries" -f (Stamp-Now))

Write-RunTable -Rows $inventoryRows -Path (Join-Path $run.TablesDir 'saved_run_inventory.csv')
Write-RunTable -Rows $filesUsed -Path (Join-Path $run.TablesDir 'files_used.csv')
Write-RunTable -Rows $svdSummaryRows -Path (Join-Path $run.TablesDir 'svd_mode_summary.csv')
Write-RunTable -Rows $coverageRows -Path (Join-Path $run.TablesDir 'temperature_coverage_audit.csv')
Write-RunTable -Rows $regimeRows -Path (Join-Path $run.TablesDir 'regime_correlations.csv')
Write-RunTable -Rows $modeResidualRows -Path (Join-Path $run.TablesDir 'mode_residual_asymmetry_correlations.csv')
Write-RunTable -Rows $modeGeometryRows -Path (Join-Path $run.TablesDir 'mode_geometry_correlations.csv')
Write-RunTable -Rows $joinedRows -Path (Join-Path $run.TablesDir 'joined_switching_audit_data.csv')
Append-Line -Path $run.LogPath -Text ("[{0}] wrote tables" -f (Stamp-Now))

$sourceFigures = @{
    'source_switching_alignment_svd_T.png' = Find-FirstExistingPath @((Join-Path $switchRunDir 'alignment_audit\switching_alignment_svd_T.png'),(Join-Path $switchRunDir 'switching_alignment_svd_T.png'));
    'source_switching_alignment_svd_I.png' = Find-FirstExistingPath @((Join-Path $switchRunDir 'alignment_audit\switching_alignment_svd_I.png'),(Join-Path $switchRunDir 'switching_alignment_svd_I.png'));
    'source_switching_alignment_svd_current_modes.png' = Find-FirstExistingPath @((Join-Path $switchRunDir 'alignment_audit\switching_alignment_svd_current_modes.png'),(Join-Path $switchRunDir 'switching_alignment_svd_current_modes.png'));
    'source_switching_alignment_mode_reconstruction.png' = Find-FirstExistingPath @((Join-Path $switchRunDir 'alignment_audit\switching_alignment_mode_reconstruction.png'),(Join-Path $switchRunDir 'switching_alignment_mode_reconstruction.png'))
}
foreach ($name in $sourceFigures.Keys) { if ($null -ne $sourceFigures[$name]) { Copy-Item -LiteralPath $sourceFigures[$name] -Destination (Join-Path $run.FiguresDir $name) -Force } }

$modeNums = [double[]]@($svdSummaryRows | ForEach-Object { [double]$_.mode })
$specChart = New-LineChart -Title 'Switching SVD spectrum' -XAxisTitle 'Mode index' -YAxisTitle 'Energy fraction / cumulative energy'
Add-LineSeries -Chart $specChart -Name 'variance explained' -X $modeNums -Y ([double[]]@($svdSummaryRows | ForEach-Object { [double]$_.variance_explained })) -Color (Hex-Color '#1F77B4') -MarkerStyle 'Circle' -BorderWidth 3
Add-LineSeries -Chart $specChart -Name 'cumulative energy' -X $modeNums -Y ([double[]]@($svdSummaryRows | ForEach-Object { [double]$_.cumulative_energy })) -Color (Hex-Color '#D62728') -MarkerStyle 'Diamond' -BorderWidth 3
Save-Chart -Chart $specChart -Path (Join-Path $run.FiguresDir 'switching_svd_spectrum.png')

$temps = [double[]]@($joinedRows | ForEach-Object { [double]$_.T })
$coeffChart = New-LineChart -Title 'SVD mode coefficients vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Coefficient (a.u.)'
Add-LineSeries -Chart $coeffChart -Name 'mode1_coeff' -X $temps -Y ([double[]]@($joinedRows | ForEach-Object { [double]$_.mode1_coeff })) -Color (Hex-Color '#1F77B4') -MarkerStyle 'Circle' -BorderWidth 3
Add-LineSeries -Chart $coeffChart -Name 'mode2_coeff' -X $temps -Y ([double[]]@($joinedRows | ForEach-Object { [double]$_.mode2_coeff })) -Color (Hex-Color '#FF7F0E') -MarkerStyle 'Diamond' -BorderWidth 3
Add-LineSeries -Chart $coeffChart -Name 'mode3_coeff' -X $temps -Y ([double[]]@($joinedRows | ForEach-Object { [double]$_.mode3_coeff })) -Color (Hex-Color '#2CA02C') -MarkerStyle 'Square' -BorderWidth 3
Save-Chart -Chart $coeffChart -Path (Join-Path $run.FiguresDir 'switching_mode_coefficients_vs_temperature.png')

$overlayChart = New-LineChart -Title 'Residual, asymmetry, and modes vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Min-max normalized value'
Add-LineSeries -Chart $overlayChart -Name 'residual' -X $temps -Y (Normalize-MinMax ($joinedRows | ForEach-Object { $_.shift_width_amp_residual })) -Color (Hex-Color '#D62728') -MarkerStyle 'Circle' -BorderWidth 3
Add-LineSeries -Chart $overlayChart -Name 'halfwidth_diff_norm' -X $temps -Y (Normalize-MinMax ($joinedRows | ForEach-Object { $_.halfwidth_diff_norm })) -Color (Hex-Color '#9467BD') -MarkerStyle 'Diamond' -BorderWidth 3
Add-LineSeries -Chart $overlayChart -Name 'mode1_coeff' -X $temps -Y (Normalize-MinMax ($joinedRows | ForEach-Object { $_.mode1_coeff })) -Color (Hex-Color '#1F77B4') -MarkerStyle 'None' -BorderWidth 3
Add-LineSeries -Chart $overlayChart -Name 'mode2_coeff' -X $temps -Y (Normalize-MinMax ($joinedRows | ForEach-Object { $_.mode2_coeff })) -Color (Hex-Color '#FF7F0E') -MarkerStyle 'None' -BorderWidth 3
Add-LineSeries -Chart $overlayChart -Name 'mode3_coeff' -X $temps -Y (Normalize-MinMax ($joinedRows | ForEach-Object { $_.mode3_coeff })) -Color (Hex-Color '#2CA02C') -MarkerStyle 'None' -BorderWidth 3
Save-Chart -Chart $overlayChart -Path (Join-Path $run.FiguresDir 'residual_asymmetry_modes_vs_temperature.png')

$scatterChart = New-LineChart -Title 'Residual vs asymmetry by regime' -XAxisTitle 'halfwidth_diff_norm' -YAxisTitle 'shift_width_amp residual norm'
$colors = @{ low_T=(Hex-Color '#1F77B4'); crossover=(Hex-Color '#FF7F0E'); high_T=(Hex-Color '#2CA02C') }
foreach ($regime in @('low_T','crossover','high_T')) {
    $subset = @($usableRows | Where-Object { $_.regime -eq $regime })
    Add-PointSeries -Chart $scatterChart -Name $regime -X ([double[]]@($subset | ForEach-Object { [double]$_.halfwidth_diff_norm })) -Y ([double[]]@($subset | ForEach-Object { [double]$_.shift_width_amp_residual })) -Color $colors[$regime] -MarkerStyle 'Circle' -MarkerSize 9
}
Save-Chart -Chart $scatterChart -Path (Join-Path $run.FiguresDir 'residual_vs_asymmetry_by_regime.png')
Append-Line -Path $run.LogPath -Text ("[{0}] wrote figures" -f (Stamp-Now))

$mode1 = $svdSummaryRows | Where-Object { $_.mode -eq 1 } | Select-Object -First 1
$mode2 = $svdSummaryRows | Where-Object { $_.mode -eq 2 } | Select-Object -First 1
$mode3 = $svdSummaryRows | Where-Object { $_.mode -eq 3 } | Select-Object -First 1
$mode1Res = $modeResidualRows | Where-Object { $_.relation -eq 'residual_vs_mode' -and $_.x_metric -eq 'mode1_coeff' } | Select-Object -First 1
$mode2Res = $modeResidualRows | Where-Object { $_.relation -eq 'residual_vs_mode' -and $_.x_metric -eq 'mode2_coeff' } | Select-Object -First 1
$mode3Res = $modeResidualRows | Where-Object { $_.relation -eq 'residual_vs_mode' -and $_.x_metric -eq 'mode3_coeff' } | Select-Object -First 1
$mode1Asym = $modeResidualRows | Where-Object { $_.relation -eq 'asymmetry_vs_mode' -and $_.x_metric -eq 'mode1_coeff' } | Select-Object -First 1
$mode2Asym = $modeResidualRows | Where-Object { $_.relation -eq 'asymmetry_vs_mode' -and $_.x_metric -eq 'mode2_coeff' } | Select-Object -First 1
$mode3Asym = $modeResidualRows | Where-Object { $_.relation -eq 'asymmetry_vs_mode' -and $_.x_metric -eq 'mode3_coeff' } | Select-Object -First 1
$low = $regimeRows | Where-Object { $_.regime -eq 'low_T' } | Select-Object -First 1
$cross = $regimeRows | Where-Object { $_.regime -eq 'crossover' } | Select-Object -First 1
$high = $regimeRows | Where-Object { $_.regime -eq 'high_T' } | Select-Object -First 1
$excluded = @($coverageRows | Where-Object { -not $_.included_in_asymmetry_analysis })
$bestCollapse = $collapseSummaryRows | Where-Object { $_.transform -eq 'shift_width_amp' } | Select-Object -First 1
$reportLines = @(
'# Switching Analysis Audit',
'',
'## Repository State Summary',
'- Runs with Switching SVD outputs found in saved results are listed in `tables/saved_run_inventory.csv`. The main modern Switching SVD run used here is `run_2026_03_10_112659_alignment_audit`.',
'- Collapse-analysis runs found are the `switching_collapse_kernel_analysis` runs in `results/cross_experiment/runs/`, with the stable reference taken from `run_2026_03_11_224153_switching_collapse_kernel_analysis`.',
'- Asymmetry-test runs found are `run_2026_03_11_235727_switching_collapse_asymmetry_test` and `run_2026_03_11_235752_switching_collapse_asymmetry_test`; this audit uses the later run.',
'- Exact source files used are listed in `tables/files_used.csv`.',
'',
'## SVD Interpretation',
('- Saved variance explained: mode1 = `{0:N3}`, mode2 = `{1:N3}`, mode3 = `{2:N3}`; cumulative energy through mode3 = `{3:N3}`.' -f $mode1.variance_explained, $mode2.variance_explained, $mode3.variance_explained, $mode3.cumulative_energy),
'- Mode1 is the dominant base ridge / amplitude component: it carries nearly all energy and the saved source correlation file shows `mode1_T_vs_S_peak = -0.987`.',
'- Mode2 behaves like a crossover drift mode, growing in magnitude toward high temperature and showing moderate alignment with both `S_peak` and `I_peak` in the saved correlations.',
'- Mode3 is a smaller higher-order correction. The saved outputs support reading it as a residual shape/tilt/skew correction, but not as the main collapse-error coordinate.',
'- Source SVD plots copied into this run support that qualitative interpretation: `source_switching_alignment_svd_T.png`, `source_switching_alignment_svd_I.png`, `source_switching_alignment_svd_current_modes.png`, and `source_switching_alignment_mode_reconstruction.png`.',
'',
'## Temperature Coverage',
('- Original saved Switching temperatures: `{0}` points -> `{1}`.' -f $originalTemps.Count, (($originalTemps | ForEach-Object { $_.ToString('F0',$Invariant) }) -join ', ')),
('- Temperatures used in the saved asymmetry analysis: `{0}` -> `{1}`.' -f $usableRows.Count, (($usableRows | ForEach-Object { $_.T.ToString('F0',$Invariant) }) -join ', ')),
('- Excluded temperatures: `{0}`.' -f (($excluded | ForEach-Object { $_.T.ToString('F0',$Invariant) + ' K (' + $_.exclusion_reason + ')' }) -join '; ')),
'- The exclusion mechanism is already visible in the saved switching observables: at 30, 32, and 34 K the canonical export loses finite `width_I` and `halfwidth_diff_norm`, so the saved `shift_width_amp` residual is also unavailable.',
'',
'## Regime Dependence',
('- Global residual vs asymmetry over the usable subset: Pearson `r = {0:N3}`, Spearman `rho = {1:N3}`, `n = {2}`.' -f $globalResidualVsAsym.pearson_r, $globalResidualVsAsym.spearman_rho, $globalResidualVsAsym.overlap_count),
('- Low-T (4-10 K): Pearson `{0}`, Spearman `{1}`, usable `n = {2}`, note: {3}.' -f $(if ([double]::IsNaN([double]$low.pearson_r)) { 'NaN' } else { '{0:N3}' -f [double]$low.pearson_r }), $(if ([double]::IsNaN([double]$low.spearman_rho)) { 'NaN' } else { '{0:N3}' -f [double]$low.spearman_rho }), $low.usable_temperatures, $low.note),
('- Crossover (12-20 K): Pearson `{0}`, Spearman `{1}`, usable `n = {2}`, note: {3}.' -f $(if ([double]::IsNaN([double]$cross.pearson_r)) { 'NaN' } else { '{0:N3}' -f [double]$cross.pearson_r }), $(if ([double]::IsNaN([double]$cross.spearman_rho)) { 'NaN' } else { '{0:N3}' -f [double]$cross.spearman_rho }), $cross.usable_temperatures, $cross.note),
('- High-T (22-34 K, usable subset 22-28 K): Pearson `{0}`, Spearman `{1}`, usable `n = {2}`, note: {3}.' -f $(if ([double]::IsNaN([double]$high.pearson_r)) { 'NaN' } else { '{0:N3}' -f [double]$high.pearson_r }), $(if ([double]::IsNaN([double]$high.spearman_rho)) { 'NaN' } else { '{0:N3}' -f [double]$high.spearman_rho }), $high.usable_temperatures, $high.note),
'- The saved results therefore imply that the apparent global residual-asymmetry relationship is mostly a between-regime effect. Inside the low-T and crossover plateaus, `halfwidth_diff_norm` is effectively constant, so no meaningful within-regime correlation can be measured.',
'',
'## Relation To SVD Modes',
('- Residual vs mode1/mode2/mode3: `(r, rho) = ({0:N3}, {1:N3}), ({2:N3}, {3:N3}), ({4:N3}, {5:N3})`.' -f $mode1Res.pearson_r, $mode1Res.spearman_rho, $mode2Res.pearson_r, $mode2Res.spearman_rho, $mode3Res.pearson_r, $mode3Res.spearman_rho),
('- Asymmetry vs mode1/mode2/mode3: `(r, rho) = ({0:N3}, {1:N3}), ({2:N3}, {3:N3}), ({4:N3}, {5:N3})`.' -f $mode1Asym.pearson_r, $mode1Asym.spearman_rho, $mode2Asym.pearson_r, $mode2Asym.spearman_rho, $mode3Asym.pearson_r, $mode3Asym.spearman_rho),
'- Mode2 and mode3 do not correlate strongly with the saved collapse residual, so the existing outputs do not support them as direct residual proxies. They align only moderately with signed asymmetry.',
'',
'## Geometric Interpretation',
'- The saved Switching map is effectively one dominant kernel plus a weaker regime-dependent distortion. Mode1 is that dominant kernel.',
'- The residual collapse distortion is not best described as a single global asymmetry axis. The stronger evidence is for a crossover/regime change involving ridge motion, width switching, and asymmetry changes across 12-24 K.',
('- The stable saved collapse result remains `shift + width + amplitude` with global residual `{0:N3}` and mean residual `{1:N3}`.' -f (To-Double $bestCollapse.global_residual), (To-Double $bestCollapse.mean_residual)),
'',
'## Visualization choices',
'- number of curves: 2 in the spectrum figure, 3 in the coefficient figure, 5 in the normalized overlay, and 3 regime point sets in the regime scatter.',
'- legend vs colormap: legends were used throughout because each new figure has six or fewer plotted series.',
'- colormap used: none for the new figures; discrete colors were used for direct comparison. Reused source SVD figures retain their original styling.',
'- smoothing applied: none.',
'- justification: this is an audit of saved outputs, so the figures emphasize coverage, regime structure, and mode relationships rather than regenerating maps.'
)
$reportPath = Join-Path $run.ReportsDir 'switching_analysis_audit.md'
Write-TextUtf8 -Path $reportPath -Text ($reportLines -join [Environment]::NewLine)
Append-Line -Path $run.LogPath -Text ("[{0}] wrote report" -f (Stamp-Now))

$notes = @('Audit notes:',('- usable asymmetry temperatures: {0}' -f (($usableRows | ForEach-Object { $_.T.ToString('F0',$Invariant) }) -join ', ')),('- excluded temperatures: {0}' -f (($excluded | ForEach-Object { $_.T.ToString('F0',$Invariant) }) -join ', '))) -join [Environment]::NewLine
Write-TextUtf8 -Path $run.NotesPath -Text $notes
$zipPath = Build-ZipBundle -Run $run -ZipName 'switching_analysis_audit_bundle.zip'
Append-Line -Path $run.LogPath -Text ("[{0}] wrote review bundle: {1}" -f (Stamp-Now), $zipPath)
Write-Output ("Report: {0}" -f $reportPath)
Write-Output ("Review bundle: {0}" -f $zipPath)
