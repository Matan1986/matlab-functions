param(
    [string]$RepoRoot = '',
    [string]$RelaxRunName = 'run_2026_03_10_175048_relaxation_observable_stability_audit',
    [string]$SwitchRunName = 'run_2026_03_10_112659_alignment_audit',
    [string]$MotionRunName = 'run_2026_03_11_084425_relaxation_switching_motion_test',
    [string]$RunLabel = 'switching_relaxation_amplitude_test'
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
    return Get-PearsonCorrelation (Get-AverageRanks $paired.X) (Get-AverageRanks $paired.Y)
}

function Normalize-ByMax {
    param([object[]]$Values)
    $out = [double[]]::new($Values.Count)
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $out[$i] = To-Double $Values[$i]
    }
    $finite = Get-FiniteValues $out
    if ($finite.Count -eq 0) { return $out }
    $maxAbs = 0.0
    foreach ($value in $finite) {
        $mag = [Math]::Abs($value)
        if ($mag -gt $maxAbs) { $maxAbs = $mag }
    }
    if ($maxAbs -le 0) { return $out }
    for ($i = 0; $i -lt $out.Length; $i++) {
        if (-not [double]::IsNaN($out[$i]) -and -not [double]::IsInfinity($out[$i])) {
            $out[$i] = $out[$i] / $maxAbs
        }
    }
    return $out
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

function Get-PeakRow {
    param([string]$MetricName, [string]$Definition, [object[]]$Rows, [string]$ValueField)
    $bestRow = $null
    $bestValue = [double]::NegativeInfinity
    foreach ($row in $Rows) {
        $value = To-Double $row.$ValueField
        if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { continue }
        if ($value -gt $bestValue) {
            $bestValue = $value
            $bestRow = $row
        }
    }
    if ($null -eq $bestRow) {
        return [pscustomobject]@{
            metric_name = $MetricName
            definition = $Definition
            T_peak_K = [double]::NaN
            peak_value = [double]::NaN
        }
    }
    return [pscustomobject]@{
        metric_name = $MetricName
        definition = $Definition
        T_peak_K = To-Double $bestRow.T_K
        peak_value = $bestValue
    }
}

function Build-ScatterChart {
    param([object[]]$Rows, [string]$OutputPath)
    $chart = New-LineChart -Title 'Switching amplitude vs Relaxation activity' -XAxisTitle 'A(T) on switching grid (a.u.)' -YAxisTitle 'S_peak(T) (a.u.)'
    $allRows = @($Rows | Where-Object { -not [double]::IsNaN((To-Double $_.A_interp)) -and -not [double]::IsNaN((To-Double $_.S_peak)) })
    $robustRows = @($allRows | Where-Object { [int](To-Double $_.robust_mask) -eq 1 })
    Add-PointSeries -Chart $chart -Name 'all overlap' -X ([double[]]@($allRows | ForEach-Object { To-Double $_.A_interp })) -Y ([double[]]@($allRows | ForEach-Object { To-Double $_.S_peak })) -Color (Hex-Color '#808080') -MarkerStyle 'Circle' -MarkerSize 7
    Add-PointSeries -Chart $chart -Name 'robust subset' -X ([double[]]@($robustRows | ForEach-Object { To-Double $_.A_interp })) -Y ([double[]]@($robustRows | ForEach-Object { To-Double $_.S_peak })) -Color (Hex-Color '#D62728') -MarkerStyle 'Diamond' -MarkerSize 9
    Save-Chart -Chart $chart -Path $OutputPath
}

$RepoRoot = Get-RepoRootPath $RepoRoot
$relaxRunDir = Join-Path $RepoRoot ("results\relaxation\runs\{0}" -f $RelaxRunName)
$switchRunDir = Join-Path $RepoRoot ("results\switching\runs\{0}" -f $SwitchRunName)
$motionRunDir = Join-Path $RepoRoot ("results\cross_experiment\runs\{0}" -f $MotionRunName)

$requiredFiles = @(
    (Join-Path $relaxRunDir 'tables\temperature_observables.csv'),
    (Join-Path $relaxRunDir 'tables\observables_relaxation.csv'),
    (Join-Path $switchRunDir 'observable_matrix.csv'),
    (Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv')
)
foreach ($path in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required saved-output file: $path"
    }
}

$config = [ordered]@{
    relax_run = $RelaxRunName
    switching_run = $SwitchRunName
    motion_run = $MotionRunName
    data_policy = 'saved outputs only'
    primary_hypothesis = 'S_peak(T) proportional to A(T)'
    reuse_note = 'extends switching_relaxation_observable_comparison without recomputing maps'
}

$run = New-RunContext -RepoRootPath $RepoRoot -Experiment 'cross_experiment' -Label $RunLabel -Dataset ("relax:{0} | switch:{1} | motion:{2}" -f $RelaxRunName, $SwitchRunName, $MotionRunName) -Config $config
Append-Line -Path $run.LogPath -Text ("[{0}] switching-relaxation amplitude test started" -f (Stamp-Now))
Append-Line -Path $run.LogPath -Text ("Relaxation source: {0}" -f $RelaxRunName)
Append-Line -Path $run.LogPath -Text ("Switching source: {0}" -f $SwitchRunName)
Append-Line -Path $run.LogPath -Text ("Motion source: {0}" -f $MotionRunName)

$relaxObsRows = @(Import-Csv -Path (Join-Path $relaxRunDir 'tables\observables_relaxation.csv'))
$switchRows = @(Import-Csv -Path (Join-Path $switchRunDir 'observable_matrix.csv'))
$motionRows = @(Import-Csv -Path (Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv'))
Append-Line -Path $run.LogPath -Text ("[{0}] loaded saved source tables" -f (Stamp-Now))

$widthByT = @{}
foreach ($row in $switchRows) {
    $widthByT[[string](To-Double $row.T)] = $row
}

$joinedRows = New-Object System.Collections.Generic.List[object]
foreach ($row in ($motionRows | Sort-Object { To-Double $_.T_K })) {
    $T = To-Double $row.T_K
    $switchRow = if ($widthByT.ContainsKey([string]$T)) { $widthByT[[string]$T] } else { $null }
    [void]$joinedRows.Add([pscustomobject]@{
        T_K = $T
        A_interp = To-Double $row.A_interp
        A_norm = To-Double $row.A_norm
        S_peak = To-Double $row.S_peak
        S_norm = if ($row.PSObject.Properties.Name -contains 'S_peak_norm') { To-Double $row.S_peak_norm } else { [double]::NaN }
        width_I = if ($null -ne $switchRow) { To-Double $switchRow.width_I } else { [double]::NaN }
        motion_abs_dI_peak_dT = To-Double $row.motion_abs_dI_peak_dT
        motion_norm = To-Double $row.motion_norm
        I_peak = if ($null -ne $switchRow) { To-Double $switchRow.I_peak } else { [double]::NaN }
        robust_mask = To-Double $row.robust_mask
        comparison_mask = To-Double $row.comparison_mask
    })
}

$widthNorm = Normalize-ByMax ($joinedRows | ForEach-Object { $_.width_I })
for ($i = 0; $i -lt $joinedRows.Count; $i++) {
    $joinedRows[$i] | Add-Member -NotePropertyName width_norm -NotePropertyValue $widthNorm[$i]
}
$joinedRows = @($joinedRows | Sort-Object T_K)

$allRows = @($joinedRows | Where-Object { -not [double]::IsNaN($_.A_interp) -and -not [double]::IsNaN($_.S_peak) })
$robustRows = @($allRows | Where-Object { [int]$_.robust_mask -eq 1 })

$correlationRows = @(
    [pscustomobject]@{
        relation = 'A_interp_vs_S_peak'
        subset = 'all_overlap'
        n_points = $allRows.Count
        pearson_r = Get-PearsonCorrelation ($allRows | ForEach-Object { $_.A_interp }) ($allRows | ForEach-Object { $_.S_peak })
        spearman_rho = Get-SpearmanCorrelation ($allRows | ForEach-Object { $_.A_interp }) ($allRows | ForEach-Object { $_.S_peak })
        interpretation = 'primary saved-grid test'
    },
    [pscustomobject]@{
        relation = 'A_interp_vs_S_peak'
        subset = 'robust_overlap'
        n_points = $robustRows.Count
        pearson_r = Get-PearsonCorrelation ($robustRows | ForEach-Object { $_.A_interp }) ($robustRows | ForEach-Object { $_.S_peak })
        spearman_rho = Get-SpearmanCorrelation ($robustRows | ForEach-Object { $_.A_interp }) ($robustRows | ForEach-Object { $_.S_peak })
        interpretation = 'saved robust subset from motion test'
    }
)

$relaxSourcePeakT = To-Double $relaxObsRows[0].Relax_T_peak
$relaxSourcePeakAmp = To-Double $relaxObsRows[0].Relax_Amp_peak
$alignedAPeak = Get-PeakRow -MetricName 'A_interp_on_switching_grid' -Definition 'Relaxation A(T) interpolated onto switching temperatures' -Rows $joinedRows -ValueField 'A_interp'
$sPeak = Get-PeakRow -MetricName 'S_peak' -Definition 'Saved switching peak amplitude on switching temperature grid' -Rows $joinedRows -ValueField 'S_peak'

$peakRows = @(
    [pscustomobject]@{
        metric_name = 'A_source'
        definition = 'Saved Relaxation activity peak from observables_relaxation.csv'
        T_peak_K = $relaxSourcePeakT
        peak_value = $relaxSourcePeakAmp
        delta_vs_A_source_K = 0.0
        delta_vs_A_aligned_K = $relaxSourcePeakT - $alignedAPeak.T_peak_K
    },
    [pscustomobject]@{
        metric_name = $alignedAPeak.metric_name
        definition = $alignedAPeak.definition
        T_peak_K = $alignedAPeak.T_peak_K
        peak_value = $alignedAPeak.peak_value
        delta_vs_A_source_K = $alignedAPeak.T_peak_K - $relaxSourcePeakT
        delta_vs_A_aligned_K = 0.0
    },
    [pscustomobject]@{
        metric_name = $sPeak.metric_name
        definition = $sPeak.definition
        T_peak_K = $sPeak.T_peak_K
        peak_value = $sPeak.peak_value
        delta_vs_A_source_K = $sPeak.T_peak_K - $relaxSourcePeakT
        delta_vs_A_aligned_K = $sPeak.T_peak_K - $alignedAPeak.T_peak_K
    }
)

$manifestRows = @(
    [pscustomobject]@{ purpose = 'existing partial comparison script inspected'; path = (Join-Path $RepoRoot 'analysis\switching_relaxation_observable_comparison.m') },
    [pscustomobject]@{ purpose = 'relaxation A(T) source'; path = (Join-Path $relaxRunDir 'tables\temperature_observables.csv') },
    [pscustomobject]@{ purpose = 'relaxation peak metadata'; path = (Join-Path $relaxRunDir 'tables\observables_relaxation.csv') },
    [pscustomobject]@{ purpose = 'switching observables source'; path = (Join-Path $switchRunDir 'observable_matrix.csv') },
    [pscustomobject]@{ purpose = 'saved switching-relaxation alignment table'; path = (Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv') }
)

$overlayTablePath = Join-Path $run.TablesDir 'switching_relaxation_amplitude_overlay.csv'
$corrTablePath = Join-Path $run.TablesDir 'switching_relaxation_amplitude_correlation.csv'
$peakTablePath = Join-Path $run.TablesDir 'switching_relaxation_peak_temperature_summary.csv'
$manifestTablePath = Join-Path $run.TablesDir 'source_run_manifest.csv'
Write-RunTable -Rows $joinedRows -Path $overlayTablePath
Write-RunTable -Rows $correlationRows -Path $corrTablePath
Write-RunTable -Rows $peakRows -Path $peakTablePath
Write-RunTable -Rows $manifestRows -Path $manifestTablePath
Append-Line -Path $run.LogPath -Text ("[{0}] wrote tables" -f (Stamp-Now))

$temps = [double[]]@($joinedRows | ForEach-Object { $_.T_K })
$pairDefs = @(
    [pscustomobject]@{ Name = 'A_norm'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.A_norm }); Color = (Hex-Color '#1F77B4'); DashStyle = 'Solid'; MarkerStyle = 'Circle'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'S_norm'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.S_norm }); Color = (Hex-Color '#D62728'); DashStyle = 'Solid'; MarkerStyle = 'Diamond'; BorderWidth = 3 }
)
$contextDefs = @(
    [pscustomobject]@{ Name = 'A_norm'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.A_norm }); Color = (Hex-Color '#1F77B4'); DashStyle = 'Solid'; MarkerStyle = 'Circle'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'S_norm'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.S_norm }); Color = (Hex-Color '#D62728'); DashStyle = 'Solid'; MarkerStyle = 'Diamond'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'width_I/max(width_I)'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.width_norm }); Color = (Hex-Color '#2CA02C'); DashStyle = 'Dash'; MarkerStyle = 'Square'; BorderWidth = 3 },
    [pscustomobject]@{ Name = '|dI_peak/dT|/max'; X = $temps; Y = [double[]]@($joinedRows | ForEach-Object { $_.motion_norm }); Color = (Hex-Color '#9467BD'); DashStyle = 'Dash'; MarkerStyle = 'Triangle'; BorderWidth = 3 }
)

$pairFigurePath = Join-Path $run.FiguresDir 'switching_relaxation_activity_pair_overlay.png'
$contextFigurePath = Join-Path $run.FiguresDir 'switching_relaxation_activity_context_overlay.png'
$scatterFigurePath = Join-Path $run.FiguresDir 'switching_relaxation_activity_scatter.png'
Build-SimpleLinePlot -Title 'Relaxation activity and Switching amplitude vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Normalized value' -SeriesDefs $pairDefs -OutputPath $pairFigurePath
Build-SimpleLinePlot -Title 'Relaxation activity with switching amplitude, width, and motion' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Overlay value (normalized)' -SeriesDefs $contextDefs -OutputPath $contextFigurePath
Build-ScatterChart -Rows $joinedRows -OutputPath $scatterFigurePath
Append-Line -Path $run.LogPath -Text ("[{0}] wrote figures" -f (Stamp-Now))

$allCorr = $correlationRows | Where-Object { $_.subset -eq 'all_overlap' } | Select-Object -First 1
$robustCorr = $correlationRows | Where-Object { $_.subset -eq 'robust_overlap' } | Select-Object -First 1
$relaxTempPath = Join-Path $relaxRunDir 'tables\temperature_observables.csv'
$relaxObsPath = Join-Path $relaxRunDir 'tables\observables_relaxation.csv'
$switchObsPath = Join-Path $switchRunDir 'observable_matrix.csv'
$motionTablePath = Join-Path $motionRunDir 'tables\relaxation_switching_motion_table.csv'
$allPearsonText = [string]::Format($Invariant, '{0:F3}', $allCorr.pearson_r)
$allSpearmanText = [string]::Format($Invariant, '{0:F3}', $allCorr.spearman_rho)
$robustPearsonText = [string]::Format($Invariant, '{0:F3}', $robustCorr.pearson_r)
$robustSpearmanText = [string]::Format($Invariant, '{0:F3}', $robustCorr.spearman_rho)
$relaxSourcePeakText = [string]::Format($Invariant, '{0:F1}', $relaxSourcePeakT)
$alignedPeakText = [string]::Format($Invariant, '{0:F1}', $alignedAPeak.T_peak_K)
$sPeakText = [string]::Format($Invariant, '{0:F1}', $sPeak.T_peak_K)
$deltaSourceText = [string]::Format($Invariant, '{0:F1}', ($sPeak.T_peak_K - $relaxSourcePeakT))
$deltaAlignedText = [string]::Format($Invariant, '{0:F1}', ($sPeak.T_peak_K - $alignedAPeak.T_peak_K))

$reportText = @"
# Switching-Relaxation Amplitude Test

## Repository-state summary
- Repository rules inspected before analysis: docs/AGENT_RULES.md, docs/results_system.md, docs/repository_structure.md, docs/output_artifacts.md, docs/visualization_rules.md.
- Existing related code inspected: analysis/switching_relaxation_observable_comparison.m.
- Existing functionality already present: the saved comparison script already tested A(T) against saved switching motion, centroid, width, and curvature observables.
- Gap found: S_peak(T) itself was not tested directly against A(T), so this run adds that amplitude-focused check without changing earlier analyses.
- New code added: analysis/switching_relaxation_amplitude_test.ps1.

## Exact saved files reused
- Relaxation activity source: $relaxTempPath
- Relaxation peak metadata: $relaxObsPath
- Switching observable table: $switchObsPath
- Saved cross-experiment motion table: $motionTablePath

## Analysis performed
- A(T) was reused from the saved Relaxation exports and compared on the saved switching temperature grid through the existing A_interp column from the motion-test run.
- S_peak(T) was reused from the same saved motion table, which already carries the switching ridge amplitude on the switching grid.
- width_I(T) was joined from the canonical switching observable_matrix.csv.
- |dI_peak/dT| was reused from the saved motion table for context only; it was not recomputed here.
- A_norm(T) and S_norm(T) were taken from the saved normalized columns. width_I and |dI_peak/dT| were max-normalized only for the four-curve overlay figure.

## Correlation results
- Primary overlap-grid test (n = $($allCorr.n_points)): Pearson = $allPearsonText, Spearman = $allSpearmanText.
- Saved robust subset (n = $($robustCorr.n_points)): Pearson = $robustPearsonText, Spearman = $robustSpearmanText.
- Sign of the relationship: negative in both subsets, so the saved data do not support a proportional-tracking picture S_peak(T) proportional to A(T).

## Peak temperatures
- Saved Relaxation source peak: T_peak_A = $relaxSourcePeakText K.
- Relaxation peak after interpolation onto the switching grid: T_peak_A_interp = $alignedPeakText K.
- Switching amplitude peak: T_peak_Speak = $sPeakText K.
- Peak offset versus saved Relaxation source peak: $deltaSourceText K.
- Peak offset versus interpolated Relaxation peak on the switching grid: $deltaAlignedText K.

## Main finding
- S_peak(T) does not track the Relaxation activity A(T) in the saved outputs used here.
- The mismatch is not subtle: A(T) peaks near 26-27 K, while S_peak(T) is maximal at 4 K and then generally decreases as A(T) rises toward the crossover region.
- In the same saved comparison framework, |dI_peak/dT| remains the much more plausible Relaxation-linked switching observable, while amplitude behaves in the opposite direction.

## Uncertainty and limits
- This run reused the same saved source runs as the existing cross-experiment observable comparison so the conclusion is specific to those canonical exports.
- No switching maps or relaxation maps were recomputed, so this run does not test whether alternative smoothing or a different Relaxation A(T) export would change the result.
- width_I and |dI_peak/dT| are included only as context overlays here; their detailed correlation study lives in the earlier saved comparison run.

## Visualization choices
- number of curves: 2 in the direct amplitude/activity overlay; 4 in the context overlay
- legend vs colormap: explicit legends only
- colormap used: none
- smoothing applied: none in this run; all values were reused from saved tables
- justification: the figures focus on the amplitude hypothesis directly and keep the previously relevant switching observables visible for context
"@

$reportPath = Join-Path $run.ReportsDir 'switching_relaxation_amplitude_test.md'
Write-TextUtf8 -Path $reportPath -Text $reportText

$zipPath = Build-ZipBundle -Run $run -ZipName 'switching_relaxation_amplitude_test.zip'
Append-Line -Path $run.LogPath -Text ("[{0}] wrote report: {1}" -f (Stamp-Now), $reportPath)
Append-Line -Path $run.LogPath -Text ("[{0}] wrote review bundle: {1}" -f (Stamp-Now), $zipPath)
Append-Line -Path $run.NotesPath -Text ("Amplitude-vs-activity all-overlap Pearson = {0}" -f ([string]::Format($Invariant, '{0:F6}', $allCorr.pearson_r)))
Append-Line -Path $run.NotesPath -Text ("Amplitude-vs-activity all-overlap Spearman = {0}" -f ([string]::Format($Invariant, '{0:F6}', $allCorr.spearman_rho)))
Append-Line -Path $run.NotesPath -Text ("S_peak source-grid offset from Relax_T_peak = {0} K" -f ([string]::Format($Invariant, '{0:F1}', ($sPeak.T_peak_K - $relaxSourcePeakT))))

Write-Output ("Run directory: {0}" -f $run.RunDir)
Write-Output ("Report: {0}" -f $reportPath)
Write-Output ("Review bundle: {0}" -f $zipPath)
