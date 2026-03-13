$runDir = 'C:\Dev\matlab-functions\results\aging\runs\run_2026_03_12_223709_aging_timescale_extraction'
$datasetPath = 'C:\Dev\matlab-functions\results\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv'
$tablePath = Join-Path $runDir 'tables\tau_vs_Tp.csv'
$reportPath = Join-Path $runDir 'reports\aging_timescale_extraction_report.md'
$pngPath = Join-Path $runDir 'figures\tau_vs_Tp.png'
$zipPath = Join-Path $runDir 'review\aging_timescale_extraction.zip'

function To-Num($v) {
    if ($null -eq $v -or $v -eq '') { return [double]::NaN }
    return [double]::Parse($v, [System.Globalization.CultureInfo]::InvariantCulture)
}

function To-Bool($v) {
    return ($v -eq '1' -or $v -eq 'true' -or $v -eq 'True')
}

function Fmt($v) {
    if ([double]::IsNaN($v)) { return 'NaN' }
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:G3}', $v)
}

function Median($vals) {
    if ($vals.Count -eq 0) { return [double]::NaN }
    $sorted = $vals | Sort-Object
    $n = $sorted.Count
    if ($n % 2 -eq 1) { return [double]$sorted[[int][math]::Floor($n / 2)] }
    return ([double]$sorted[$n / 2 - 1] + [double]$sorted[$n / 2]) / 2.0
}

function PairStats($rows, $fieldA, $fieldB) {
    $vals = @()
    foreach ($row in $rows) {
        $a = $row.$fieldA
        $b = $row.$fieldB
        if (-not [double]::IsNaN($a) -and $a -gt 0 -and -not [double]::IsNaN($b) -and $b -gt 0) {
            $vals += [math]::Abs([math]::Log10($a) - [math]::Log10($b))
        }
    }
    [pscustomobject]@{
        Count = $vals.Count
        Median = (Median $vals)
    }
}

$rows = Import-Csv $tablePath | ForEach-Object {
    [pscustomobject]@{
        Tp = To-Num $_.Tp
        n_points = [int](To-Num $_.n_points)
        fragile_low_point_count = To-Bool $_.fragile_low_point_count
        tau_logistic_half_seconds = To-Num $_.tau_logistic_half_seconds
        tau_logistic_status = $_.tau_logistic_status
        tau_stretched_half_seconds = To-Num $_.tau_stretched_half_seconds
        tau_stretched_status = $_.tau_stretched_status
        tau_stretched_beta = To-Num $_.tau_stretched_beta
        tau_half_range_seconds = To-Num $_.tau_half_range_seconds
        tau_half_range_status = $_.tau_half_range_status
        tau_effective_seconds = To-Num $_.tau_effective_seconds
        tau_consensus_methods = $_.tau_consensus_methods
        tau_method_spread_decades = To-Num $_.tau_method_spread_decades
        n_downturns = [int](To-Num $_.n_downturns)
    }
}

$valid = $rows | Where-Object { -not [double]::IsNaN($_.tau_effective_seconds) }
$minRow = $valid | Sort-Object tau_effective_seconds | Select-Object -First 1
$maxRow = $valid | Sort-Object tau_effective_seconds -Descending | Select-Object -First 1

$pairLogHalf = PairStats $rows 'tau_logistic_half_seconds' 'tau_half_range_seconds'
$pairStretchHalf = PairStats $rows 'tau_stretched_half_seconds' 'tau_half_range_seconds'
$pairLogStretch = PairStats $rows 'tau_logistic_half_seconds' 'tau_stretched_half_seconds'

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add('# Aging timescale extraction')
$reportLines.Add('')
$reportLines.Add(('Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$reportLines.Add(('Run root: `{0}`' -f $runDir))
$reportLines.Add(('Input dataset: `{0}`' -f $datasetPath))
$reportLines.Add('')
$reportLines.Add('## Dataset summary')
$reportLines.Add('- Total rows: 30.')
$reportLines.Add('- Distinct stopping temperatures: 8 (`6, 10, 14, 18, 22, 26, 30, 34` K).')
$reportLines.Add('- Waiting-time window: 3 s to 3.6e+03 s.')
$reportLines.Add('- Fragile high-T_p cases with only 3 points: `30, 34` K.')
$reportLines.Add('')
$reportLines.Add('## Methods')
$reportLines.Add('- `Logistic fit in log(t_w)`: fit a sigmoid in `log10(t_w)` and report its half-rise time.')
$reportLines.Add('- `Stretched exponential`: fit `Dip_depth = y_0 + \\Delta (1 - exp(-(t_w / \\tau_c)^{\\beta}))` and convert it to a half-rise time.')
$reportLines.Add('- `Direct half-range`: interpolate the earliest upward crossing of half the rise from the shortest-time point to the observed peak.')
$reportLines.Add('- `Consensus`: reported only when the direct half-range is resolved; it is the median of the available method estimates in log-time.')
$reportLines.Add('')
$reportLines.Add('## Main findings')
$reportLines.Add(('- The shortest resolved consensus timescale appears at `T_p = {0} K` with `\tau \approx {1} s`.' -f (Fmt $minRow.Tp), (Fmt $minRow.tau_effective_seconds)))
$reportLines.Add(('- The longest resolved consensus timescale appears at `T_p = {0} K` with `\tau \approx {1} s`.' -f (Fmt $maxRow.Tp), (Fmt $maxRow.tau_effective_seconds)))
$reportLines.Add('- `30 K` and `34 K` remain unresolved in the consensus curve because the direct Dip-depth half-range is not observed within the sampled waiting-time window.')
$reportLines.Add('- Across the resolved `6-26 K` range, the effective tau grows from a few seconds up to roughly `10^2 s`, with the clearest agreement between methods around `18-22 K`.')
$reportLines.Add('')
$reportLines.Add('## Per-T_p summary')
foreach ($row in $rows | Sort-Object Tp) {
    $reportLines.Add(('- `T_p = {0} K`: logistic `{1} s` ({2}), stretched `{3} s` ({4}, \beta = {5}), direct half-range `{6} s` ({7}), consensus `{8} s` from `{9}`.' -f (Fmt $row.Tp), (Fmt $row.tau_logistic_half_seconds), $row.tau_logistic_status, (Fmt $row.tau_stretched_half_seconds), $row.tau_stretched_status, (Fmt $row.tau_stretched_beta), (Fmt $row.tau_half_range_seconds), $row.tau_half_range_status, (Fmt $row.tau_effective_seconds), $row.tau_consensus_methods))
}
$reportLines.Add('')
$reportLines.Add('## Method comparison')
$reportLines.Add(('- Logistic vs direct half-range: {0} overlapping T_p values, median |\Delta log_{{10}} \tau| = {1} decades.' -f $pairLogHalf.Count, (Fmt $pairLogHalf.Median)))
$reportLines.Add(('- Stretched-exp vs direct half-range: {0} overlapping T_p values, median |\Delta log_{{10}} \tau| = {1} decades.' -f $pairStretchHalf.Count, (Fmt $pairStretchHalf.Median)))
$reportLines.Add(('- Logistic vs stretched-exp: {0} overlapping T_p values, median |\Delta log_{{10}} \tau| = {1} decades.' -f $pairLogStretch.Count, (Fmt $pairLogStretch.Median)))
$reportLines.Add('- The high-T_p fit-only cases (`30, 34 K`) disagree by many decades and should be treated as unresolved rather than as genuine long aging times.')
$reportLines.Add('')
$reportLines.Add('## Cautions')
$reportLines.Add('- `30 K` and `34 K` are structurally fragile because only 3 waiting times are available and the shortest sampled point is already the local maximum.')
$reportLines.Add('- `6 K`, `10 K`, and `26 K` show late-time downturns after an earlier peak, so the monotone fit models summarize the buildup only approximately.')
$reportLines.Add('- These taus are effective timescales extracted from the saved Dip-depth observable only; they are not a claim of a unique microscopic relaxation law.')
$reportLines.Add('')
$reportLines.Add('## Visualization choices')
$reportLines.Add('- Number of curves in `Dip_depth_vs_tw_by_Tp`: 8, so a `parula` colormap plus labeled colorbar is used; dashed lines mark 3-point fragile T_p values.')
$reportLines.Add('- Number of curves in `tau_vs_Tp`: 4 method/summary curves, so an explicit legend is used instead of a colormap.')
$reportLines.Add('- Colormaps: `parula` for the multi-T_p Dip-depth sweep; no colormap for the tau comparison figure.')
$reportLines.Add('- Smoothing applied: none; all methods fit or interpolate the saved scalar Dip-depth points directly.')
$reportLines.Add('- Justification: the figure set compares the observed Dip-depth growth law first and then the method-dependent tau extraction.')
$reportLines.Add('')
$reportLines.Add('## Exported artifacts')
$reportLines.Add('- `tables/tau_vs_Tp.csv`')
$reportLines.Add('- `figures/Dip_depth_vs_tw_by_Tp.png`')
$reportLines.Add('- `figures/tau_vs_Tp.png`')
$reportLines.Add('- `reports/aging_timescale_extraction_report.md`')
$reportLines.Add('- `review/aging_timescale_extraction.zip`')
[System.IO.File]::WriteAllLines($reportPath, $reportLines, [System.Text.Encoding]::UTF8)

Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing
$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Width = 1200
$chart.Height = 800
$chart.BackColor = [System.Drawing.Color]::White
$chart.Palette = [System.Windows.Forms.DataVisualization.Charting.ChartColorPalette]::None
$area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'Main'
$area.AxisX.Title = 'Stopping temperature T_p (K)'
$area.AxisY.Title = 'Effective aging timescale tau (s)'
$area.AxisY.IsLogarithmic = $true
$area.AxisY.LogarithmBase = 10
$area.AxisX.MajorGrid.Enabled = $false
$area.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
$area.AxisY.MajorGrid.LineDashStyle = 'Dot'
$area.AxisX.LineWidth = 1
$area.AxisY.LineWidth = 1
$area.AxisX.LabelStyle.Font = New-Object System.Drawing.Font('Arial', 9)
$area.AxisY.LabelStyle.Font = New-Object System.Drawing.Font('Arial', 9)
$area.AxisX.TitleFont = New-Object System.Drawing.Font('Arial', 10)
$area.AxisY.TitleFont = New-Object System.Drawing.Font('Arial', 10)
$area.AxisX.Minimum = 5
$area.AxisX.Maximum = 35
$chart.ChartAreas.Add($area)
$legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend
$legend.Docking = 'Right'
$legend.Font = New-Object System.Drawing.Font('Arial', 8)
$chart.Legends.Add($legend)
$chart.Titles.Add('Aging timescale estimates vs stopping temperature') | Out-Null
$chart.Titles[0].Font = New-Object System.Drawing.Font('Arial', 10)

function Add-Series($chart, $name, $color, $marker, $field, $rows, $lineWidth = 2) {
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $series.BorderWidth = $lineWidth
    $series.Color = $color
    $series.MarkerStyle = $marker
    $series.MarkerSize = 8
    $series.MarkerColor = $color
    $series.MarkerBorderColor = $color
    foreach ($row in ($rows | Sort-Object Tp)) {
        $y = $row.$field
        if (-not [double]::IsNaN($y) -and $y -gt 0) {
            [void]$series.Points.AddXY($row.Tp, $y)
        }
    }
    $chart.Series.Add($series) | Out-Null
}

Add-Series $chart 'Logistic fit in log(t_w)' ([System.Drawing.Color]::FromArgb(0,115,189)) 'Circle' 'tau_logistic_half_seconds' $rows 2
Add-Series $chart 'Stretched-exp half time' ([System.Drawing.Color]::FromArgb(217,83,25)) 'Square' 'tau_stretched_half_seconds' $rows 2
Add-Series $chart 'Direct half-range' ([System.Drawing.Color]::FromArgb(0,158,115)) 'Triangle' 'tau_half_range_seconds' $rows 2
Add-Series $chart 'Consensus' ([System.Drawing.Color]::Black) 'Diamond' 'tau_effective_seconds' $rows 3

$fragile = New-Object System.Windows.Forms.DataVisualization.Charting.Series 'Fragile T_p (3 points)'
$fragile.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Point
$fragile.MarkerStyle = 'Circle'
$fragile.MarkerSize = 10
$fragile.Color = [System.Drawing.Color]::Black
$fragile.MarkerColor = [System.Drawing.Color]::White
$fragile.MarkerBorderColor = [System.Drawing.Color]::Black
$fragile.MarkerBorderWidth = 2
foreach ($row in ($rows | Where-Object { $_.fragile_low_point_count -and -not [double]::IsNaN($_.tau_logistic_half_seconds) })) {
    [void]$fragile.Points.AddXY($row.Tp, $row.tau_logistic_half_seconds)
}
$chart.Series.Add($fragile) | Out-Null

$chart.SaveImage($pngPath, 'Png')

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Push-Location $runDir
Compress-Archive -Path 'figures','tables','reports','run_manifest.json','config_snapshot.m','log.txt','run_notes.txt' -DestinationPath $zipPath -Force
Pop-Location
