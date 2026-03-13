param(
    [string]$RepoRoot = '',
    [string]$DatasetPath = '',
    [string]$RunLabel = 'aging_time_rescaling_collapse'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.Drawing
$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

function Get-RepoRootPath {
    param([string]$InputRepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($InputRepoRoot)) {
        return (Resolve-Path $InputRepoRoot).Path
    }
    return (Split-Path $PSScriptRoot -Parent)
}

function Stamp-Now {
    Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}

function Get-RunTimestamp {
    Get-Date -Format 'yyyy_MM_dd_HHmmss'
}

function Append-Line {
    param([string]$Path,[string]$Text)
    Add-Content -Path $Path -Value $Text -Encoding UTF8
}

function Get-GitCommit {
    param([string]$RepoRootPath)
    try {
        return (git -C $RepoRootPath rev-parse HEAD).Trim()
    } catch {
        return 'unknown'
    }
}

function New-RunContext {
    param([string]$RepoRootPath,[string]$Label,[string]$Dataset)

    $runsRoot = Join-Path $RepoRootPath 'results\aging\runs'
    if (-not (Test-Path $runsRoot)) { [void](New-Item -ItemType Directory -Path $runsRoot -Force) }

    $base = 'run_{0}_{1}' -f (Get-RunTimestamp), $Label
    $runId = $base
    $suffix = 1
    while (Test-Path (Join-Path $runsRoot $runId)) {
        $runId = '{0}_{1:D2}' -f $base, $suffix
        $suffix++
    }

    $runDir = Join-Path $runsRoot $runId
    $figDir = Join-Path $runDir 'figures'
    $tabDir = Join-Path $runDir 'tables'
    $repDir = Join-Path $runDir 'reports'
    $revDir = Join-Path $runDir 'review'
    foreach ($dir in @($runDir,$figDir,$tabDir,$repDir,$revDir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }

    $manifest = [ordered]@{
        run_id = $runId
        timestamp = (Stamp-Now)
        experiment = 'aging'
        label = $Label
        git_commit = (Get-GitCommit $RepoRootPath)
        host = $env:COMPUTERNAME
        user = $env:USERNAME
        repo_root = $RepoRootPath
        run_dir = $runDir
        dataset = $Dataset
    }
    $manifestPath = Join-Path $runDir 'run_manifest.json'
    $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8

    $cfgPath = Join-Path $runDir 'config_snapshot.m'
    @(
        ('% Auto-generated config snapshot for {0}' -f $runId)
        ('cfg_snapshot_json = ''{0}'';' -f (($manifest | ConvertTo-Json -Compress -Depth 4).Replace("'","''")))
        'cfg_snapshot = jsondecode(cfg_snapshot_json);'
        'cfg = cfg_snapshot;'
    ) | Set-Content -Path $cfgPath -Encoding UTF8

    $logPath = Join-Path $runDir 'log.txt'
    @(
        ('[{0}] Run initialized' -f (Stamp-Now))
        ('run_id: {0}' -f $runId)
        ('label: {0}' -f $Label)
        'experiment: aging'
        ('git_commit: {0}' -f $manifest.git_commit)
        ''
    ) | Set-Content -Path $logPath -Encoding UTF8

    $notesPath = Join-Path $runDir 'run_notes.txt'
    Set-Content -Path $notesPath -Value '' -Encoding UTF8

    return [pscustomobject]@{
        RunId = $runId
        RunDir = $runDir
        FiguresDir = $figDir
        TablesDir = $tabDir
        ReportsDir = $repDir
        ReviewDir = $revDir
        ManifestPath = $manifestPath
        LogPath = $logPath
        NotesPath = $notesPath
    }
}

function Get-Double {
    param([object]$Value)
    if ($null -eq $Value) { return [double]::NaN }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return [double]::NaN }
    $s = $s.Trim().Trim('"')
    $out = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $Invariant, [ref]$out)) {
        return $out
    }
    return [double]::NaN
}

function Get-GeometricMean {
    param([double[]]$Values)
    $vals = @($Values | Where-Object { $_ -gt 0 -and -not [double]::IsNaN($_) -and -not [double]::IsInfinity($_) })
    if ($vals.Count -eq 0) { return [double]::NaN }
    $logs = $vals | ForEach-Object { [Math]::Log($_) }
    return [Math]::Exp(($logs | Measure-Object -Average).Average)
}

function Normalize-Series {
    param([double[]]$Values)
    $maxVal = ($Values | Measure-Object -Maximum).Maximum
    if ($maxVal -le 0 -or [double]::IsNaN($maxVal)) { throw 'Cannot normalize series with non-positive max.' }
    return @($Values | ForEach-Object { $_ / $maxVal })
}

function Interp-Linear {
    param([double[]]$X,[double[]]$Y,[double]$Xq)
    if ($Xq -lt $X[0] -or $Xq -gt $X[$X.Length - 1]) { return [double]::NaN }
    for ($i=0; $i -lt $X.Length - 1; $i++) {
        if ($Xq -ge $X[$i] -and $Xq -le $X[$i + 1]) {
            $dx = $X[$i + 1] - $X[$i]
            if ([Math]::Abs($dx) -lt 1e-12) { return $Y[$i] }
            $a = ($Xq - $X[$i]) / $dx
            return $Y[$i] + $a * ($Y[$i + 1] - $Y[$i])
        }
    }
    return $Y[$Y.Length - 1]
}

function New-ShiftedX {
    param($Curve,[double]$Shift)
    return @($Curve.LogTw | ForEach-Object { $_ - $Shift })
}

function Get-CollapseObjective {
    param([double[]]$Shifts,[object[]]$Curves)
    $pairScores = New-Object System.Collections.Generic.List[double]
    for ($i=0; $i -lt $Curves.Count - 1; $i++) {
        $xi = New-ShiftedX $Curves[$i] $Shifts[$i]
        $yi = $Curves[$i].Norm
        $spanI = $xi[$xi.Length - 1] - $xi[0]
        for ($j=$i + 1; $j -lt $Curves.Count; $j++) {
            $xj = New-ShiftedX $Curves[$j] $Shifts[$j]
            $yj = $Curves[$j].Norm
            $spanJ = $xj[$xj.Length - 1] - $xj[0]
            $lo = [Math]::Max($xi[0], $xj[0])
            $hi = [Math]::Min($xi[$xi.Length - 1], $xj[$xj.Length - 1])
            $overlap = $hi - $lo
            if ($overlap -lt 0.20) {
                [void]$pairScores.Add(0.35)
                continue
            }
            $diffs = New-Object System.Collections.Generic.List[double]
            for ($k=0; $k -lt 15; $k++) {
                $xq = $lo + ($overlap * $k / 14.0)
                $vi = Interp-Linear $xi $yi $xq
                $vj = Interp-Linear $xj $yj $xq
                if ([double]::IsNaN($vi) -or [double]::IsNaN($vj)) { continue }
                [void]$diffs.Add([Math]::Pow($vi - $vj, 2))
            }
            if ($diffs.Count -lt 5) {
                [void]$pairScores.Add(0.35)
                continue
            }
            $mse = ($diffs | Measure-Object -Average).Average
            $overlapFrac = $overlap / [Math]::Max([Math]::Min($spanI, $spanJ), 1e-12)
            [void]$pairScores.Add($mse + 0.03 * [Math]::Pow(1.0 - $overlapFrac, 2))
        }
    }
    if ($pairScores.Count -eq 0) { return [double]::PositiveInfinity }
    return ($pairScores | Measure-Object -Average).Average
}

function Get-OptimizedShifts {
    param([double[]]$Initial,[object[]]$Curves)
    $best = @($Initial)
    $mean0 = ($best | Measure-Object -Average).Average
    for ($i=0; $i -lt $best.Length; $i++) { $best[$i] -= $mean0 }
    $bestObjective = Get-CollapseObjective $best $Curves
    $steps = @(0.25,0.10,0.05)
    foreach ($step in $steps) {
        $improved = $true
        $pass = 0
        while ($improved -and $pass -lt 4) {
            $improved = $false
            $pass++
            for ($i=0; $i -lt $best.Length; $i++) {
                foreach ($delta in @(-$step, $step)) {
                    $candidate = @($best)
                    $candidate[$i] += $delta
                    $meanCand = ($candidate | Measure-Object -Average).Average
                    for ($j=0; $j -lt $candidate.Length; $j++) { $candidate[$j] -= $meanCand }
                    $obj = Get-CollapseObjective $candidate $Curves
                    if ($obj + 1e-10 -lt $bestObjective) {
                        $best = $candidate
                        $bestObjective = $obj
                        $improved = $true
                    }
                }
            }
        }
    }
    return [pscustomobject]@{ Shifts = $best; Objective = $bestObjective }
}

function Get-ProfileStats {
    param([object[]]$Curves,[double[]]$Shifts)
    $xMin = [double]::PositiveInfinity
    $xMax = [double]::NegativeInfinity
    for ($i=0; $i -lt $Curves.Count; $i++) {
        $xs = New-ShiftedX $Curves[$i] $Shifts[$i]
        if ($xs[0] -lt $xMin) { $xMin = $xs[0] }
        if ($xs[$xs.Length - 1] -gt $xMax) { $xMax = $xs[$xs.Length - 1] }
    }
    $grid = New-Object double[] 120
    for ($k=0; $k -lt $grid.Length; $k++) {
        $grid[$k] = $xMin + (($xMax - $xMin) * $k / ($grid.Length - 1))
    }
    $meanVals = New-Object double[] $grid.Length
    $stdVals = New-Object double[] $grid.Length
    $counts = New-Object int[] $grid.Length
    $variances = New-Object System.Collections.Generic.List[double]
    for ($k=0; $k -lt $grid.Length; $k++) {
        $vals = New-Object System.Collections.Generic.List[double]
        for ($i=0; $i -lt $Curves.Count; $i++) {
            $xs = New-ShiftedX $Curves[$i] $Shifts[$i]
            $v = Interp-Linear $xs $Curves[$i].Norm $grid[$k]
            if (-not [double]::IsNaN($v)) { [void]$vals.Add($v) }
        }
        $counts[$k] = $vals.Count
        if ($vals.Count -gt 0) {
            $mean = ($vals | Measure-Object -Average).Average
            $meanVals[$k] = $mean
            if ($vals.Count -gt 1) {
                $sum = 0.0
                foreach ($v in $vals) { $sum += [Math]::Pow($v - $mean, 2) }
                $var = $sum / ($vals.Count - 1)
                $stdVals[$k] = [Math]::Sqrt($var)
                if ($vals.Count -ge 3) { [void]$variances.Add($var) }
            }
        }
    }
    $meanVariance = if ($variances.Count -gt 0) { ($variances | Measure-Object -Average).Average } else { [double]::NaN }
    return [pscustomobject]@{ XGrid = $grid; Mean = $meanVals; Std = $stdVals; Counts = $counts; MeanVariance = $meanVariance }
}

function Get-Verdict {
    param([double]$RawObjective,[double]$OptObjective,[double]$RawVariance,[double]$OptVariance)
    $improvement = 1.0 - ($OptObjective / [Math]::Max($RawObjective, 1e-12))
    if ($improvement -ge 0.50 -and $OptVariance -le 0.02) {
        return 'Strong collapse after time rescaling.'
    }
    if ($improvement -ge 0.25 -and $OptVariance -lt $RawVariance) {
        return 'Partial collapse: the rescaling reduces spread but does not fully unify the curves.'
    }
    return 'Weak collapse: rescaling does not remove most of the inter-curve variation.'
}

function New-LineSeries {
    param($Chart,[string]$Area,[string]$Legend,[string]$Name,[double[]]$X,[double[]]$Y,[System.Drawing.Color]$Color,[bool]$ShowInLegend)
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $Name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $series.ChartArea = $Area
    $series.Legend = $Legend
    $series.Color = $Color
    $series.BorderWidth = 3
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::Circle
    $series.MarkerSize = 7
    $series.IsVisibleInLegend = $ShowInLegend
    for ($i=0; $i -lt [Math]::Min($X.Length,$Y.Length); $i++) {
        if ([double]::IsNaN($X[$i]) -or [double]::IsNaN($Y[$i])) { continue }
        [void]$series.Points.AddXY($X[$i], $Y[$i])
    }
    [void]$Chart.Series.Add($series)
}

function Add-AreaTitle {
    param($Chart,[string]$Text,[string]$Area,[int]$DockingOffset)
    $title = New-Object System.Windows.Forms.DataVisualization.Charting.Title
    $title.Text = $Text
    $title.DockedToChartArea = $Area
    $title.Docking = [System.Windows.Forms.DataVisualization.Charting.Docking]::Top
    $title.DockingOffset = $DockingOffset
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
    [void]$Chart.Titles.Add($title)
}

function Save-CollapseAttemptFigure {
    param([string]$Path,[object[]]$Curves,[double[]]$TauSeconds,[double]$RawObjective,[double]$OptObjective)
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 1500; $chart.Height = 620; $chart.BackColor = [System.Drawing.Color]::White
    $legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend 'legend'
    $legend.Docking = 'Right'; $legend.Alignment = 'Center'; $legend.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    [void]$chart.Legends.Add($legend)
    $raw = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'raw'
    $raw.Position.Auto = $false; $raw.Position.X = 5; $raw.Position.Y = 12; $raw.Position.Width = 40; $raw.Position.Height = 78
    $raw.AxisX.IsLogarithmic = $true; $raw.AxisX.Title = 't_w (s)'; $raw.AxisY.Title = 'Normalized Dip depth'; $raw.AxisY.Minimum = 0; $raw.AxisY.Maximum = 1.1
    $raw.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray; $raw.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    [void]$chart.ChartAreas.Add($raw)
    $resc = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'rescaled'
    $resc.Position.Auto = $false; $resc.Position.X = 50; $resc.Position.Y = 12; $resc.Position.Width = 34; $resc.Position.Height = 78
    $resc.AxisX.IsLogarithmic = $true; $resc.AxisX.Title = 't_w / tau(T_p)'; $resc.AxisY.Title = 'Normalized Dip depth'; $resc.AxisY.Minimum = 0; $resc.AxisY.Maximum = 1.1
    $resc.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray; $resc.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    [void]$chart.ChartAreas.Add($resc)
    Add-AreaTitle $chart ('Before rescaling (obj {0:F4})' -f $RawObjective) 'raw' 0
    Add-AreaTitle $chart ('After rescaling (obj {0:F4})' -f $OptObjective) 'rescaled' 0
    $palette = @(
        [System.Drawing.Color]::FromArgb(31,119,180),
        [System.Drawing.Color]::FromArgb(255,127,14),
        [System.Drawing.Color]::FromArgb(44,160,44),
        [System.Drawing.Color]::FromArgb(214,39,40),
        [System.Drawing.Color]::FromArgb(148,103,189),
        [System.Drawing.Color]::FromArgb(140,86,75),
        [System.Drawing.Color]::FromArgb(227,119,194),
        [System.Drawing.Color]::FromArgb(127,127,127)
    )
    for ($i=0; $i -lt $Curves.Count; $i++) {
        $curve = $Curves[$i]
        $color = $palette[$i % $palette.Count]
        New-LineSeries $chart 'raw' 'legend' ('raw_{0}' -f $curve.Tp) $curve.Tw $curve.Norm $color $false
        $z = @($curve.Tw | ForEach-Object { $_ / $TauSeconds[$i] })
        New-LineSeries $chart 'rescaled' 'legend' ('Tp = {0} K' -f $curve.Tp) $z $curve.Norm $color $true
    }
    $chart.SaveImage($Path, 'Png')
}

function Save-RescaledCurvesFigure {
    param([string]$Path,[object[]]$Curves,[double[]]$TauSeconds,[double[]]$Shifts,[double]$Gauge)
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = 1480; $chart.Height = 680; $chart.BackColor = [System.Drawing.Color]::White
    $legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend 'legend'
    $legend.Docking = 'Right'; $legend.Alignment = 'Center'; $legend.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    [void]$chart.Legends.Add($legend)
    $left = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'rescaled'
    $left.Position.Auto = $false; $left.Position.X = 5; $left.Position.Y = 12; $left.Position.Width = 40; $left.Position.Height = 78
    $left.AxisX.IsLogarithmic = $true; $left.AxisX.Title = 't_w / tau(T_p)'; $left.AxisY.Title = 'Normalized Dip depth'; $left.AxisY.Minimum = 0; $left.AxisY.Maximum = 1.1
    $left.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray; $left.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    [void]$chart.ChartAreas.Add($left)
    $right = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'tau'
    $right.Position.Auto = $false; $right.Position.X = 52; $right.Position.Y = 12; $right.Position.Width = 30; $right.Position.Height = 78
    $right.AxisY.IsLogarithmic = $true; $right.AxisX.Title = 'T_p (K)'; $right.AxisY.Title = 'tau(T_p) [s]';
    $right.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::LightGray; $right.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::LightGray
    [void]$chart.ChartAreas.Add($right)
    Add-AreaTitle $chart 'Optimized rescaled curves' 'rescaled' 0
    Add-AreaTitle $chart ('Estimated tau(T_p), gauge = {0:F2} s' -f $Gauge) 'tau' 0
    $palette = @(
        [System.Drawing.Color]::FromArgb(31,119,180),
        [System.Drawing.Color]::FromArgb(255,127,14),
        [System.Drawing.Color]::FromArgb(44,160,44),
        [System.Drawing.Color]::FromArgb(214,39,40),
        [System.Drawing.Color]::FromArgb(148,103,189),
        [System.Drawing.Color]::FromArgb(140,86,75),
        [System.Drawing.Color]::FromArgb(227,119,194),
        [System.Drawing.Color]::FromArgb(127,127,127)
    )
    for ($i=0; $i -lt $Curves.Count; $i++) {
        $curve = $Curves[$i]
        $color = $palette[$i % $palette.Count]
        $z = @($curve.Tw | ForEach-Object { $_ / $TauSeconds[$i] })
        New-LineSeries $chart 'rescaled' 'legend' ('Tp = {0} K' -f $curve.Tp) $z $curve.Norm $color $true
    }
    $tauSeries = New-Object System.Windows.Forms.DataVisualization.Charting.Series 'tau_series'
    $tauSeries.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $tauSeries.ChartArea = 'tau'; $tauSeries.Legend = 'legend'; $tauSeries.IsVisibleInLegend = $false
    $tauSeries.Color = [System.Drawing.Color]::FromArgb(40,40,40); $tauSeries.BorderWidth = 2
    $tauSeries.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::Circle; $tauSeries.MarkerSize = 8
    for ($i=0; $i -lt $Curves.Count; $i++) { [void]$tauSeries.Points.AddXY($Curves[$i].Tp, $TauSeconds[$i]) }
    [void]$chart.Series.Add($tauSeries)
    $chart.SaveImage($Path, 'Png')
}

$RepoRoot = Get-RepoRootPath $RepoRoot
if ([string]::IsNullOrWhiteSpace($DatasetPath)) {
    $DatasetPath = Join-Path $RepoRoot 'results\aging\runs\run_2026_03_12_211204_aging_dataset_build\tables\aging_observable_dataset.csv'
}
if (-not (Test-Path $DatasetPath)) { throw "Dataset not found: $DatasetPath" }

$run = New-RunContext -RepoRootPath $RepoRoot -Label $RunLabel -Dataset $DatasetPath
Append-Line -Path $run.LogPath -Text ("[{0}] dataset: {1}" -f (Stamp-Now), $DatasetPath)
Write-Output ("Run directory: {0}" -f $run.RunDir)

$rows = @(Import-Csv -Path $DatasetPath)
$data = @()
foreach ($row in $rows) {
    $data += [pscustomobject]@{
        Tp = Get-Double $row.Tp
        Tw = Get-Double $row.tw
        DipDepth = Get-Double $row.Dip_depth
        SourceRun = [string]$row.source_run
    }
}
$data = @($data | Where-Object { $_.Tp -eq $_.Tp -and $_.Tw -gt 0 -and $_.DipDepth -eq $_.DipDepth } | Sort-Object Tp, Tw)

$curves = @()
foreach ($group in ($data | Group-Object Tp | Sort-Object Name)) {
    $items = @($group.Group | Sort-Object Tw)
    $tw = @($items | ForEach-Object { [double]$_.Tw })
    $dip = @($items | ForEach-Object { [double]$_.DipDepth })
    $norm = Normalize-Series $dip
    $maxIdx = 0
    $maxVal = -1.0
    for ($i=0; $i -lt $norm.Count; $i++) { if ($norm[$i] -gt $maxVal) { $maxVal = $norm[$i]; $maxIdx = $i } }
    $curves += [pscustomobject]@{
        Tp = [double]$group.Name
        Tw = [double[]]$tw
        LogTw = [double[]](@($tw | ForEach-Object { [Math]::Log10($_) }))
        Norm = [double[]]$norm
        Dip = [double[]]$dip
        PeakTw = [double]$tw[$maxIdx]
        NPoints = $tw.Count
        SourceRuns = (($items | Select-Object -ExpandProperty SourceRun -Unique) -join '; ')
    }
}

if ($curves.Count -lt 2) { throw 'Need at least two T_p curves to test collapse.' }

$allTw = [double[]](@($curves | ForEach-Object { $_.Tw } | ForEach-Object { $_ }))
$gauge = Get-GeometricMean $allTw
$shift0 = [double[]](@($curves | ForEach-Object { [Math]::Log10($_.PeakTw) }))
$shiftMean = ($shift0 | Measure-Object -Average).Average
for ($i=0; $i -lt $shift0.Length; $i++) { $shift0[$i] -= $shiftMean }

$rawShifts = New-Object double[] $curves.Count
$rawObjective = Get-CollapseObjective $rawShifts $curves
$seedObjective = Get-CollapseObjective $shift0 $curves
$seedShifts = if ($seedObjective -lt $rawObjective) { $shift0 } else { $rawShifts }
$opt = Get-OptimizedShifts $seedShifts $curves
$shifts = [double[]]$opt.Shifts
$tauRelative = [double[]](@($shifts | ForEach-Object { [Math]::Pow(10.0, $_) }))
$tauSeconds = [double[]](@($tauRelative | ForEach-Object { $_ * $gauge }))
$rawProfile = Get-ProfileStats $curves $rawShifts
$rescaledProfile = Get-ProfileStats $curves $shifts
$verdict = Get-Verdict $rawObjective $opt.Objective $rawProfile.MeanVariance $rescaledProfile.MeanVariance
$varianceReduction = 1.0 - ($opt.Objective / [Math]::Max($rawObjective, 1e-12))
Append-Line -Path $run.LogPath -Text ("[{0}] raw objective = {1}" -f (Stamp-Now), $rawObjective.ToString('G6',$Invariant))
Append-Line -Path $run.LogPath -Text ("[{0}] optimized objective = {1}" -f (Stamp-Now), $opt.Objective.ToString('G6',$Invariant))

$tauRows = for ($i=0; $i -lt $curves.Count; $i++) {
    [pscustomobject]@{
        Tp = $curves[$i].Tp
        n_points = $curves[$i].NPoints
        tw_min_seconds = ($curves[$i].Tw | Measure-Object -Minimum).Minimum
        tw_max_seconds = ($curves[$i].Tw | Measure-Object -Maximum).Maximum
        peak_tw_seconds = $curves[$i].PeakTw
        tau_relative_geomean1 = $tauRelative[$i]
        tau_estimate_seconds = $tauSeconds[$i]
        log10_tau_shift = $shifts[$i]
        tau_over_peak_tw = $tauSeconds[$i] / [Math]::Max($curves[$i].PeakTw, 1e-12)
        source_runs = $curves[$i].SourceRuns
    }
}
$tauPath = Join-Path $run.TablesDir 'tau_rescaling_estimates.csv'
$tauRows | Export-Csv -Path $tauPath -NoTypeInformation -Encoding UTF8

$collapsePng = Join-Path $run.FiguresDir 'collapse_attempt.png'
$rescaledPng = Join-Path $run.FiguresDir 'rescaled_curves.png'
Save-CollapseAttemptFigure -Path $collapsePng -Curves $curves -TauSeconds $tauSeconds -RawObjective $rawObjective -OptObjective $opt.Objective
Save-RescaledCurvesFigure -Path $rescaledPng -Curves $curves -TauSeconds $tauSeconds -Shifts $shifts -Gauge $gauge

$reportLines = @(
    '# Aging collapse test under time rescaling'
    ''
    ('Generated: {0}' -f (Stamp-Now))
    ('Run root: `{0}`' -f $run.RunDir)
    ''
    '## Task'
    '- Test whether `Dip_depth(t_w)` curves collapse after normalizing each `T_p` trace and rescaling time as `t_w / tau(T_p)`.'
    ('- Source dataset: `{0}`' -f $DatasetPath)
    '- Normalization used: `divide_by_max`.'
    '- Objective used for `tau(T_p)`: mean interpolated pairwise squared mismatch in `log10(t_w / tau)` with an overlap penalty.'
    ('- Global scale convention: `geommean(tau) = {0}` s.' -f $gauge.ToString('G6',$Invariant))
    ''
    '## Dataset summary'
    ('- Total rows in dataset: {0}' -f $data.Count)
    ('- Distinct `T_p` values analyzed: {0}' -f $curves.Count)
    ('- Distinct waiting times present: `{0}` s' -f ((@($allTw | Sort-Object -Unique | ForEach-Object { $_.ToString('G',$Invariant) }) -join ', ')))
    ''
    '## Collapse summary'
    ('- Raw objective: `{0}`' -f $rawObjective.ToString('G6',$Invariant))
    ('- Rescaled objective: `{0}`' -f $opt.Objective.ToString('G6',$Invariant))
    ('- Objective reduction: `{0}%`' -f (100.0 * $varianceReduction).ToString('F2',$Invariant))
    ('- Mean gridded variance before rescaling: `{0}`' -f $rawProfile.MeanVariance.ToString('G6',$Invariant))
    ('- Mean gridded variance after rescaling: `{0}`' -f $rescaledProfile.MeanVariance.ToString('G6',$Invariant))
    ('- Verdict: {0}' -f $verdict)
    ''
    '## Estimated timescales'
    '| T_p (K) | n | peak t_w (s) | tau relative | tau (s, gauge-fixed) | log10 shift | tau / peak t_w |'
    '| ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
)
foreach ($row in $tauRows) {
    $reportLines += ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f 
        $row.Tp.ToString('G',$Invariant),
        $row.n_points,
        ([double]$row.peak_tw_seconds).ToString('G6',$Invariant),
        ([double]$row.tau_relative_geomean1).ToString('G6',$Invariant),
        ([double]$row.tau_estimate_seconds).ToString('G6',$Invariant),
        ([double]$row.log10_tau_shift).ToString('G6',$Invariant),
        ([double]$row.tau_over_peak_tw).ToString('G6',$Invariant))
}
$reportLines += @(
    ''
    '## Interpretation'
    ('- {0}' -f $verdict)
    '- Because the optimization only identifies relative horizontal shifts, the absolute magnitude of `tau(T_p)` is conventional up to one common multiplicative factor.'
    '- The reported gauge-fixed seconds are chosen only to keep the `t_w / tau(T_p)` axis numerically readable.'
    ''
    '## Outputs'
    '- `tables/tau_rescaling_estimates.csv`'
    '- `figures/collapse_attempt.png`'
    '- `figures/rescaled_curves.png`'
    '- `reports/aging_collapse_test_report.md`'
    '- `review/aging_time_rescaling_collapse.zip`'
)
$reportPath = Join-Path $run.ReportsDir 'aging_collapse_test_report.md'
$reportLines | Set-Content -Path $reportPath -Encoding UTF8

$zipPath = Join-Path $run.ReviewDir 'aging_time_rescaling_collapse.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $run.TablesDir '*'), (Join-Path $run.FiguresDir '*'), (Join-Path $run.ReportsDir '*') -DestinationPath $zipPath -Force

Append-Line -Path $run.LogPath -Text ("[{0}] completed" -f (Stamp-Now))
Append-Line -Path $run.LogPath -Text ("report: {0}" -f $reportPath)
Append-Line -Path $run.LogPath -Text ("zip: {0}" -f $zipPath)
Append-Line -Path $run.NotesPath -Text ("Verdict: {0}" -f $verdict)
Append-Line -Path $run.NotesPath -Text ("Variance reduction = {0}%" -f (100.0 * $varianceReduction).ToString('F3',$Invariant))

Write-Output ("Report: {0}" -f $reportPath)
Write-Output ("ZIP: {0}" -f $zipPath)

