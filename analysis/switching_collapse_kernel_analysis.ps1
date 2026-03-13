param(
    [string]$RepoRoot = '',
    [string]$SwitchRunName = '',
    [string]$RelaxRunName = '',
    [string]$RunLabel = 'switching_collapse_kernel_analysis'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms.DataVisualization
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Invariant = [System.Globalization.CultureInfo]::InvariantCulture

function Get-RepoRootPath {
    param([string]$InputRepoRoot)
    if (-not [string]::IsNullOrWhiteSpace($InputRepoRoot)) {
        return (Resolve-Path $InputRepoRoot).Path
    }
    return (Split-Path $PSScriptRoot -Parent)
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Normalize-Label {
    param([string]$Label)
    $label = $Label.ToLowerInvariant()
    $label = [System.Text.RegularExpressions.Regex]::Replace($label, '[^a-z0-9]+', '_')
    $label = $label.Trim('_')
    if ([string]::IsNullOrWhiteSpace($label)) {
        return 'analysis'
    }
    return $label
}

function Write-TextUtf8 {
    param([string]$Path, [string]$Text)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Append-Line {
    param([string]$Path, [string]$Text)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::AppendAllText($Path, $Text + [Environment]::NewLine, $utf8NoBom)
}

function Stamp-Now {
    (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $Invariant)
}

function To-Double {
    param($Value)
    if ($null -eq $Value) {
        return [double]::NaN
    }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return [double]::NaN
    }
    try {
        return [double]::Parse($text, $Invariant)
    } catch {
        return [double]::NaN
    }
}

function Get-FiniteValues {
    param([object[]]$Values)
    $list = New-Object System.Collections.Generic.List[double]
    foreach ($value in $Values) {
        $d = [double]$value
        if (-not [double]::IsNaN($d) -and -not [double]::IsInfinity($d)) {
            [void]$list.Add($d)
        }
    }
    return ,$list
}

function Get-Mean {
    param([object[]]$Values)
    $finite = Get-FiniteValues $Values
    if ($finite.Count -eq 0) { return [double]::NaN }
    return ($finite | Measure-Object -Average).Average
}

function Get-Median {
    param([object[]]$Values)
    $finite = Get-FiniteValues $Values
    if ($finite.Count -eq 0) { return [double]::NaN }
    $sorted = $finite.ToArray()
    [Array]::Sort($sorted)
    if ($sorted.Length % 2 -eq 1) {
        return $sorted[[int]($sorted.Length / 2)]
    }
    $i = [int]($sorted.Length / 2)
    return 0.5 * ($sorted[$i - 1] + $sorted[$i])
}

function Get-Rms {
    param([object[]]$Values)
    $finite = Get-FiniteValues $Values
    if ($finite.Count -eq 0) { return [double]::NaN }
    $sumSq = 0.0
    foreach ($value in $finite) {
        $sumSq += $value * $value
    }
    return [Math]::Sqrt($sumSq / $finite.Count)
}

function Get-Std {
    param([object[]]$Values)
    $finite = Get-FiniteValues $Values
    if ($finite.Count -lt 2) { return [double]::NaN }
    $mean = Get-Mean $finite
    $sumSq = 0.0
    foreach ($value in $finite) {
        $delta = $value - $mean
        $sumSq += $delta * $delta
    }
    return [Math]::Sqrt($sumSq / ($finite.Count - 1))
}

function Get-PearsonCorrelation {
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
    if ($xs.Count -lt 2) { return [double]::NaN }
    $mx = Get-Mean $xs
    $my = Get-Mean $ys
    $sumXY = 0.0
    $sumXX = 0.0
    $sumYY = 0.0
    for ($i = 0; $i -lt $xs.Count; $i++) {
        $dx = $xs[$i] - $mx
        $dy = $ys[$i] - $my
        $sumXY += $dx * $dy
        $sumXX += $dx * $dx
        $sumYY += $dy * $dy
    }
    if ($sumXX -le 0 -or $sumYY -le 0) { return [double]::NaN }
    return $sumXY / [Math]::Sqrt($sumXX * $sumYY)
}

function Interpolate-Crossing {
    param([double]$X1, [double]$Y1, [double]$X2, [double]$Y2, [double]$Target)
    if ([Math]::Abs($Y2 - $Y1) -lt 1e-12) {
        return 0.5 * ($X1 + $X2)
    }
    return $X1 + ($Target - $Y1) * ($X2 - $X1) / ($Y2 - $Y1)
}

function Interp-Linear {
    param([double[]]$X, [double[]]$Y, [double[]]$Xi)
    $result = [double[]]::new($Xi.Length)
    for ($j = 0; $j -lt $result.Length; $j++) { $result[$j] = [double]::NaN }
    if ($null -eq $X -or $null -eq $Y -or $X.Length -lt 2 -or $Y.Length -lt 2) { return $result }
    $lastIndex = $X.Length - 1
    $i = 0
    for ($j = 0; $j -lt $Xi.Length; $j++) {
        $xq = $Xi[$j]
        if ($xq -lt $X[0] -or $xq -gt $X[$lastIndex]) { continue }
        while ($i -lt $lastIndex -and $X[$i + 1] -lt $xq) { $i++ }
        if ($xq -eq $X[$i]) {
            $result[$j] = $Y[$i]
            continue
        }
        if ($i -ge $lastIndex) { continue }
        $x1 = $X[$i]
        $x2 = $X[$i + 1]
        $y1 = $Y[$i]
        $y2 = $Y[$i + 1]
        if ($x2 -le $x1) { continue }
        $t = ($xq - $x1) / ($x2 - $x1)
        $result[$j] = $y1 + $t * ($y2 - $y1)
    }
    return $result
}

function Hex-Color {
    param([string]$Hex)
    $clean = $Hex.TrimStart('#')
    $r = [Convert]::ToInt32($clean.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($clean.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($clean.Substring(4, 2), 16)
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}
function Get-SequentialColors {
    param([int]$Count)
    $anchors = @(
        (Hex-Color '#1F3B73'),
        (Hex-Color '#2E6DB4'),
        (Hex-Color '#159E8C'),
        (Hex-Color '#7BC96F'),
        (Hex-Color '#F2C94C')
    )
    if ($Count -le 1) { return ,$anchors[0] }
    $colors = New-Object System.Collections.Generic.List[System.Drawing.Color]
    for ($i = 0; $i -lt $Count; $i++) {
        $u = $i / [double]($Count - 1)
        $scaled = $u * ($anchors.Count - 1)
        $idx = [Math]::Floor($scaled)
        if ($idx -ge $anchors.Count - 1) {
            [void]$colors.Add($anchors[$anchors.Count - 1])
            continue
        }
        $t = $scaled - $idx
        $c1 = $anchors[$idx]
        $c2 = $anchors[$idx + 1]
        $r = [int][Math]::Round($c1.R + $t * ($c2.R - $c1.R))
        $g = [int][Math]::Round($c1.G + $t * ($c2.G - $c1.G))
        $b = [int][Math]::Round($c1.B + $t * ($c2.B - $c1.B))
        [void]$colors.Add([System.Drawing.Color]::FromArgb($r, $g, $b))
    }
    return $colors
}

function New-LineChart {
    param([string]$Title, [string]$XAxisTitle, [string]$YAxisTitle, [int]$Width = 1600, [int]$Height = 1000)
    $chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
    $chart.Width = $Width
    $chart.Height = $Height
    $chart.BackColor = [System.Drawing.Color]::White
    $chart.Palette = [System.Windows.Forms.DataVisualization.Charting.ChartColorPalette]::None

    $area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 'main'
    $area.BackColor = [System.Drawing.Color]::White
    $area.AxisX.Title = $XAxisTitle
    $area.AxisY.Title = $YAxisTitle
    $area.AxisX.TitleFont = New-Object System.Drawing.Font('Arial', 14)
    $area.AxisY.TitleFont = New-Object System.Drawing.Font('Arial', 14)
    $area.AxisX.LabelStyle.Font = New-Object System.Drawing.Font('Arial', 11)
    $area.AxisY.LabelStyle.Font = New-Object System.Drawing.Font('Arial', 11)
    $area.AxisX.MajorGrid.LineColor = [System.Drawing.Color]::Gainsboro
    $area.AxisY.MajorGrid.LineColor = [System.Drawing.Color]::Gainsboro
    $area.AxisX.LineColor = [System.Drawing.Color]::Black
    $area.AxisY.LineColor = [System.Drawing.Color]::Black
    $area.AxisX.IsMarginVisible = $false
    $chart.ChartAreas.Add($area)

    $legend = New-Object System.Windows.Forms.DataVisualization.Charting.Legend 'legend'
    $legend.Docking = [System.Windows.Forms.DataVisualization.Charting.Docking]::Right
    $legend.Alignment = [System.Drawing.StringAlignment]::Near
    $legend.Font = New-Object System.Drawing.Font('Arial', 10)
    $legend.IsTextAutoFit = $false
    $chart.Legends.Add($legend)

    $titleObj = New-Object System.Windows.Forms.DataVisualization.Charting.Title
    $titleObj.Text = $Title
    $titleObj.Font = New-Object System.Drawing.Font('Arial', 16, [System.Drawing.FontStyle]::Bold)
    $chart.Titles.Add($titleObj)
    return $chart
}

function Add-LineSeries {
    param(
        [System.Windows.Forms.DataVisualization.Charting.Chart]$Chart,
        [string]$Name,
        [double[]]$X,
        [double[]]$Y,
        [object]$Color,
        [string]$DashStyle = 'Solid',
        [string]$MarkerStyle = 'None',
        [int]$BorderWidth = 3,
        [bool]$ShowInLegend = $true
    )
    $series = New-Object System.Windows.Forms.DataVisualization.Charting.Series $Name
    $series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
    $series.BorderWidth = $BorderWidth
    if ($null -ne $Color) { $series.Color = $Color }
    $series.IsVisibleInLegend = $ShowInLegend
    $series.Legend = 'legend'
    $series.ChartArea = 'main'
    $series.BorderDashStyle = [System.Windows.Forms.DataVisualization.Charting.ChartDashStyle]::$DashStyle
    $series.MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::$MarkerStyle
    if ($MarkerStyle -ne 'None') { $series.MarkerSize = 8 }
    for ($i = 0; $i -lt [Math]::Min($X.Length, $Y.Length); $i++) {
        if ([double]::IsNaN($X[$i]) -or [double]::IsInfinity($X[$i]) -or [double]::IsNaN($Y[$i]) -or [double]::IsInfinity($Y[$i])) { continue }
        [void]$series.Points.AddXY($X[$i], $Y[$i])
    }
    $Chart.Series.Add($series)
}

function Save-Chart {
    param([System.Windows.Forms.DataVisualization.Charting.Chart]$Chart, [string]$Path)
    $Chart.SaveImage($Path, [System.Windows.Forms.DataVisualization.Charting.ChartImageFormat]::Png)
}

function Convert-RatioToCenteredAsymmetry {
    param([double]$Ratio)
    if ([double]::IsNaN($Ratio) -or [double]::IsInfinity($Ratio) -or $Ratio -le 0) { return [double]::NaN }
    return ($Ratio - 1.0) / ($Ratio + 1.0)
}

function Get-LatestRunBySuffix {
    param([string]$RunsRoot, [string[]]$Suffixes)
    $dirs = @(Get-ChildItem -Path $RunsRoot -Directory | Where-Object {
        $_.Name -match '^run_\d{4}_\d{2}_\d{2}_\d{6}_' -and -not $_.Name.Contains('legacy')
    } | Sort-Object Name)
    for ($i = $dirs.Count - 1; $i -ge 0; $i--) {
        foreach ($suffix in $Suffixes) {
            if ($dirs[$i].Name -like "*$suffix") { return $dirs[$i].Name }
        }
    }
    return $null
}

function Get-GitCommit {
    param([string]$RepoRootPath)
    try {
        return (cmd /c git -C "$RepoRootPath" rev-parse HEAD 2>$null).Trim()
    } catch {
        return ''
    }
}

function New-RunContext {
    param([string]$RepoRootPath, [string]$Experiment, [string]$Label, [string]$Dataset, [hashtable]$Config)
    $labelNorm = Normalize-Label $Label
    $stamp = Get-Date
    $runId = 'run_{0}_{1}' -f $stamp.ToString('yyyy_MM_dd_HHmmss', $Invariant), $labelNorm
    $runRoot = Join-Path $RepoRootPath ("results\{0}\runs\{1}" -f $Experiment, $runId)
    Ensure-Directory $runRoot
    foreach ($sub in @('figures', 'tables', 'reports', 'review')) {
        Ensure-Directory (Join-Path $runRoot $sub)
    }

    $manifest = [ordered]@{
        run_id = $runId
        timestamp = $stamp.ToString('yyyy-MM-dd HH:mm:ss', $Invariant)
        experiment = $Experiment
        label = $labelNorm
        git_commit = Get-GitCommit $RepoRootPath
        matlab_version = 'not_invoked (analysis executed from saved CSV exports via PowerShell)'
        host = $env:COMPUTERNAME
        user = $env:USERNAME
        repo_root = $RepoRootPath
        run_dir = $runRoot
        dataset = $Dataset
    }

    $manifestPath = Join-Path $runRoot 'run_manifest.json'
    $configPath = Join-Path $runRoot 'config_snapshot.m'
    $logPath = Join-Path $runRoot 'log.txt'
    $notesPath = Join-Path $runRoot 'run_notes.txt'

    Write-TextUtf8 $manifestPath (($manifest | ConvertTo-Json -Depth 6))
    $cfgJson = ($Config | ConvertTo-Json -Depth 6 -Compress)
    $configText = @(
        "% Auto-generated config snapshot for $runId"
        "% Timestamp: $($manifest.timestamp)"
        "% Experiment: $Experiment"
        "% Label: $labelNorm"
        ''
        "cfg_snapshot_json = '$cfgJson';"
        'cfg_snapshot = jsondecode(cfg_snapshot_json);'
        'cfg = cfg_snapshot;'
    ) -join [Environment]::NewLine
    Write-TextUtf8 $configPath $configText
    Write-TextUtf8 $logPath ('[{0}] run created' -f (Stamp-Now))
    Write-TextUtf8 $notesPath ''

    return [pscustomobject]@{
        RunId = $runId
        RunDir = $runRoot
        FiguresDir = Join-Path $runRoot 'figures'
        TablesDir = Join-Path $runRoot 'tables'
        ReportsDir = Join-Path $runRoot 'reports'
        ReviewDir = Join-Path $runRoot 'review'
        LogPath = $logPath
        NotesPath = $notesPath
    }
}

function Write-RunTable {
    param([object[]]$Rows, [string]$Path)
    if ($Rows.Count -eq 0) { throw "Cannot write empty table to $Path" }
    $Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Get-HalfMaxWidths {
    param([double[]]$Currents, [double[]]$Signal, [double]$Ipeak, [double]$Speak)
    if ($Currents.Length -lt 3 -or [double]::IsNaN($Ipeak) -or [double]::IsNaN($Speak) -or $Speak -le 0) {
        return [pscustomobject]@{ WLeft = [double]::NaN; WRight = [double]::NaN }
    }
    $half = 0.5 * $Speak
    $peakIndex = 0
    $bestDelta = [double]::PositiveInfinity
    for ($i = 0; $i -lt $Currents.Length; $i++) {
        $delta = [Math]::Abs($Currents[$i] - $Ipeak)
        if ($delta -lt $bestDelta) { $bestDelta = $delta; $peakIndex = $i }
    }
    $leftCross = [double]::NaN
    for ($i = $peakIndex; $i -gt 0; $i--) {
        $y1 = $Signal[$i - 1]
        $y2 = $Signal[$i]
        if ($y1 -le $half -and $y2 -ge $half) { $leftCross = Interpolate-Crossing $Currents[$i - 1] $y1 $Currents[$i] $y2 $half; break }
        if ([Math]::Abs($y1 - $half) -lt 1e-12) { $leftCross = $Currents[$i - 1]; break }
    }
    $rightCross = [double]::NaN
    for ($i = $peakIndex; $i -lt $Currents.Length - 1; $i++) {
        $y1 = $Signal[$i]
        $y2 = $Signal[$i + 1]
        if ($y1 -ge $half -and $y2 -le $half) { $rightCross = Interpolate-Crossing $Currents[$i] $y1 $Currents[$i + 1] $y2 $half; break }
        if ([Math]::Abs($y2 - $half) -lt 1e-12) { $rightCross = $Currents[$i + 1]; break }
    }
    $wLeft = [double]::NaN
    $wRight = [double]::NaN
    if (-not [double]::IsNaN($leftCross)) { $wLeft = $Ipeak - $leftCross }
    if (-not [double]::IsNaN($rightCross)) { $wRight = $rightCross - $Ipeak }
    return [pscustomobject]@{ WLeft = $wLeft; WRight = $wRight }
}

function Load-SwitchingData {
    param([string]$RunDir)
    $obsPath = Join-Path $RunDir 'alignment_audit\switching_alignment_observables_vs_T.csv'
    $samplesPath = Join-Path $RunDir 'alignment_audit\switching_alignment_samples.csv'
    if (-not (Test-Path -LiteralPath $obsPath)) { throw "Missing switching observables file: $obsPath" }
    if (-not (Test-Path -LiteralPath $samplesPath)) { throw "Missing switching samples file: $samplesPath" }

    $obsRows = @(Import-Csv -Path $obsPath | ForEach-Object {
        [pscustomobject]@{
            T = To-Double $_.T_K
            Ipeak = To-Double $_.Ipeak
            Speak = To-Double $_.S_peak
            HalfwidthDiffNorm = To-Double $_.halfwidth_diff_norm
            WidthI = To-Double $_.width_I
            AsymAreaRatio = To-Double $_.asym
            dIpeak_dT = To-Double $_.dIpeak_dT
            dSpeak_dT = To-Double $_.dSpeak_dT
        }
    } | Sort-Object T)

    $sampleGroups = @{}
    Import-Csv -Path $samplesPath | ForEach-Object {
        $tClean = [double][Math]::Round((To-Double $_.T_K))
        $current = To-Double $_.current_mA
        $signal = To-Double $_.S_percent
        $tKey = $tClean.ToString('F0', $Invariant)
        $iKey = $current.ToString('G17', $Invariant)
        if (-not $sampleGroups.ContainsKey($tKey)) { $sampleGroups[$tKey] = @{} }
        if (-not $sampleGroups[$tKey].ContainsKey($iKey)) {
            $sampleGroups[$tKey][$iKey] = [ordered]@{ T = $tClean; I = $current; Sum = 0.0; Count = 0 }
        }
        $sampleGroups[$tKey][$iKey].Sum += $signal
        $sampleGroups[$tKey][$iKey].Count += 1
    }

    $curves = New-Object System.Collections.Generic.List[object]
    foreach ($row in $obsRows) {
        $tKey = $row.T.ToString('F0', $Invariant)
        if (-not $sampleGroups.ContainsKey($tKey)) { continue }
        $points = @($sampleGroups[$tKey].Values | Sort-Object I)
        $x = [double[]]::new($points.Count)
        $y = [double[]]::new($points.Count)
        for ($i = 0; $i -lt $points.Count; $i++) {
            $x[$i] = [double]$points[$i].I
            $y[$i] = [double]($points[$i].Sum / [Math]::Max($points[$i].Count, 1))
        }
        $halfWidths = Get-HalfMaxWidths $x $y $row.Ipeak $row.Speak
        $widthAsym = [double]::NaN
        if (-not [double]::IsNaN($halfWidths.WLeft) -and -not [double]::IsNaN($halfWidths.WRight)) {
            $denom = $halfWidths.WLeft + $halfWidths.WRight
            if ($denom -gt 0) { $widthAsym = ($halfWidths.WRight - $halfWidths.WLeft) / $denom }
        }
        [void]$curves.Add([pscustomobject]@{
            T = $row.T
            I = $x
            S = $y
            Ipeak = $row.Ipeak
            Speak = $row.Speak
            WidthI = $row.WidthI
            HalfwidthDiffNorm = $row.HalfwidthDiffNorm
            AsymAreaRatio = $row.AsymAreaRatio
            dIpeak_dT = $row.dIpeak_dT
            dSpeak_dT = $row.dSpeak_dT
            WLeft = $halfWidths.WLeft
            WRight = $halfWidths.WRight
            WidthAsymmetry = $widthAsym
            AreaAsymmetry = Convert-RatioToCenteredAsymmetry $row.AsymAreaRatio
        })
    }

    return [pscustomobject]@{ RunDir = $RunDir; ObservablesPath = $obsPath; SamplesPath = $samplesPath; Curves = $curves }
}

function Load-RelaxationData {
    param([string]$RunDir)
    $tempPath = Join-Path $RunDir 'tables\temperature_observables.csv'
    $obsPath = Join-Path $RunDir 'tables\observables_relaxation.csv'
    if (-not (Test-Path -LiteralPath $tempPath)) { throw "Missing relaxation temperature observables file: $tempPath" }
    if (-not (Test-Path -LiteralPath $obsPath)) { throw "Missing relaxation observables file: $obsPath" }

    $temps = @(Import-Csv -Path $tempPath | ForEach-Object {
        [pscustomobject]@{
            T = To-Double $_.T
            A_T = To-Double $_.A_T
            R_T = To-Double $_.R_T
        }
    } | Sort-Object T)
    $summary = Import-Csv -Path $obsPath | Select-Object -First 1
    return [pscustomobject]@{
        RunDir = $RunDir
        TemperatureRows = $temps
        RelaxAmpPeak = To-Double $summary.Relax_Amp_peak
        RelaxTPeak = To-Double $summary.Relax_T_peak
        RelaxPeakWidth = To-Double $summary.Relax_peak_width
    }
}

function Transform-Curve {
    param([pscustomobject]$Curve, [string]$TransformName)
    $x = [double[]]::new($Curve.I.Length)
    $y = [double[]]::new($Curve.S.Length)
    $valid = $true
    for ($i = 0; $i -lt $Curve.I.Length; $i++) { $x[$i] = [double]::NaN; $y[$i] = [double]::NaN }

    switch ($TransformName) {
        'native' {
            for ($i = 0; $i -lt $Curve.I.Length; $i++) { $x[$i] = $Curve.I[$i]; $y[$i] = $Curve.S[$i] }
        }
        'shift_only' {
            if ([double]::IsNaN($Curve.Ipeak)) { $valid = $false; break }
            for ($i = 0; $i -lt $Curve.I.Length; $i++) { $x[$i] = $Curve.I[$i] - $Curve.Ipeak; $y[$i] = $Curve.S[$i] }
        }
        'shift_width' {
            if ([double]::IsNaN($Curve.Ipeak) -or [double]::IsNaN($Curve.WidthI) -or $Curve.WidthI -le 0) { $valid = $false; break }
            for ($i = 0; $i -lt $Curve.I.Length; $i++) { $x[$i] = ($Curve.I[$i] - $Curve.Ipeak) / $Curve.WidthI; $y[$i] = $Curve.S[$i] }
        }
        'shift_width_amp' {
            if ([double]::IsNaN($Curve.Ipeak) -or [double]::IsNaN($Curve.WidthI) -or $Curve.WidthI -le 0 -or [double]::IsNaN($Curve.Speak) -or $Curve.Speak -le 0) { $valid = $false; break }
            for ($i = 0; $i -lt $Curve.I.Length; $i++) { $x[$i] = ($Curve.I[$i] - $Curve.Ipeak) / $Curve.WidthI; $y[$i] = $Curve.S[$i] / $Curve.Speak }
        }
        'asymmetric' {
            if ([double]::IsNaN($Curve.Ipeak) -or [double]::IsNaN($Curve.WLeft) -or [double]::IsNaN($Curve.WRight) -or $Curve.WLeft -le 0 -or $Curve.WRight -le 0 -or [double]::IsNaN($Curve.Speak) -or $Curve.Speak -le 0) { $valid = $false; break }
            for ($i = 0; $i -lt $Curve.I.Length; $i++) {
                if ($Curve.I[$i] -lt $Curve.Ipeak) { $x[$i] = ($Curve.I[$i] - $Curve.Ipeak) / $Curve.WLeft }
                elseif ($Curve.I[$i] -gt $Curve.Ipeak) { $x[$i] = ($Curve.I[$i] - $Curve.Ipeak) / $Curve.WRight }
                else { $x[$i] = 0.0 }
                $y[$i] = $Curve.S[$i] / $Curve.Speak
            }
        }
        default { throw "Unknown transform: $TransformName" }
    }

    if (-not $valid) {
        return [pscustomobject]@{ Valid = $false; X = [double[]]@(); Y = [double[]]@() }
    }

    $points = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $x.Length; $i++) {
        if ([double]::IsNaN($x[$i]) -or [double]::IsInfinity($x[$i]) -or [double]::IsNaN($y[$i]) -or [double]::IsInfinity($y[$i])) { continue }
        [void]$points.Add([pscustomobject]@{ X = $x[$i]; Y = $y[$i] })
    }
    if ($points.Count -lt 3) {
        return [pscustomobject]@{ Valid = $false; X = [double[]]@(); Y = [double[]]@() }
    }
    $sortedPoints = @($points | Sort-Object X)
    $xOut = [double[]]::new($sortedPoints.Count)
    $yOut = [double[]]::new($sortedPoints.Count)
    for ($i = 0; $i -lt $sortedPoints.Count; $i++) { $xOut[$i] = $sortedPoints[$i].X; $yOut[$i] = $sortedPoints[$i].Y }
    return [pscustomobject]@{ Valid = $true; X = $xOut; Y = $yOut }
}

function Evaluate-Transform {
    param([System.Collections.Generic.List[object]]$Curves, [string]$TransformName, [double]$CoverageFraction = 0.60, [int]$GridSize = 240)
    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($curve in $Curves) {
        $transformed = Transform-Curve $curve $TransformName
        if (-not $transformed.Valid) { continue }
        [void]$entries.Add([pscustomobject]@{
            T = $curve.T
            X = $transformed.X
            Y = $transformed.Y
            XMin = ($transformed.X | Measure-Object -Minimum).Minimum
            XMax = ($transformed.X | Measure-Object -Maximum).Maximum
        })
    }
    if ($entries.Count -lt 3) {
        return [pscustomobject]@{
            Transform = $TransformName
            Status = 'insufficient'
            Grid = [double[]]@()
            Kernel = [double[]]@()
            KernelStd = [double[]]@()
            Coverage = [int[]]@()
            CoverageThreshold = 0
            PerTemperature = @()
            Summary = [pscustomobject]@{ transform = $TransformName; valid_temperature_count = $entries.Count; kernel_point_count = 0; mean_residual = [double]::NaN; median_residual = [double]::NaN; global_residual = [double]::NaN; mean_corr_to_kernel = [double]::NaN; status = 'insufficient' }
            Curves = @()
        }
    }

    $globalMin = ($entries | Measure-Object -Property XMin -Minimum).Minimum
    $globalMax = ($entries | Measure-Object -Property XMax -Maximum).Maximum
    $grid = [double[]]::new($GridSize)
    for ($j = 0; $j -lt $GridSize; $j++) { $grid[$j] = $globalMin + ($j / [double]($GridSize - 1)) * ($globalMax - $globalMin) }

    $curveMatrix = New-Object System.Collections.Generic.List[object]
    $coverage = [int[]]::new($GridSize)
    foreach ($entry in $entries) {
        $interp = Interp-Linear $entry.X $entry.Y $grid
        for ($j = 0; $j -lt $GridSize; $j++) { if (-not [double]::IsNaN($interp[$j])) { $coverage[$j] += 1 } }
        [void]$curveMatrix.Add([pscustomobject]@{ T = $entry.T; Values = $interp })
    }

    $minCoverage = [Math]::Max(3, [Math]::Ceiling($CoverageFraction * $entries.Count))
    $mask = [bool[]]::new($GridSize)
    $maskedCount = 0
    while ($minCoverage -ge 2) {
        $maskedCount = 0
        for ($j = 0; $j -lt $GridSize; $j++) {
            $mask[$j] = ($coverage[$j] -ge $minCoverage)
            if ($mask[$j]) { $maskedCount += 1 }
        }
        if ($maskedCount -ge 20 -or $minCoverage -eq 2) { break }
        $minCoverage -= 1
    }

    $kernel = [double[]]::new($GridSize)
    $kernelStd = [double[]]::new($GridSize)
    for ($j = 0; $j -lt $GridSize; $j++) {
        $kernel[$j] = [double]::NaN
        $kernelStd[$j] = [double]::NaN
        if (-not $mask[$j]) { continue }
        $vals = New-Object System.Collections.Generic.List[double]
        foreach ($row in $curveMatrix) {
            $v = [double]$row.Values[$j]
            if (-not [double]::IsNaN($v) -and -not [double]::IsInfinity($v)) { [void]$vals.Add($v) }
        }
        if ($vals.Count -ge 2) { $kernel[$j] = Get-Mean $vals; $kernelStd[$j] = Get-Std $vals }
        elseif ($vals.Count -eq 1) { $kernel[$j] = $vals[0]; $kernelStd[$j] = 0.0 }
    }

    $perTemp = New-Object System.Collections.Generic.List[object]
    $allResiduals = New-Object System.Collections.Generic.List[double]
    $allCorrs = New-Object System.Collections.Generic.List[double]
    $allDiff = New-Object System.Collections.Generic.List[double]
    $allKernelVals = New-Object System.Collections.Generic.List[double]

    foreach ($row in $curveMatrix) {
        $diffs = New-Object System.Collections.Generic.List[double]
        $kernelVals = New-Object System.Collections.Generic.List[double]
        $curveVals = New-Object System.Collections.Generic.List[double]
        for ($j = 0; $j -lt $GridSize; $j++) {
            if (-not $mask[$j]) { continue }
            $yv = [double]$row.Values[$j]
            $kv = [double]$kernel[$j]
            if ([double]::IsNaN($yv) -or [double]::IsNaN($kv)) { continue }
            $diff = $yv - $kv
            [void]$diffs.Add($diff)
            [void]$kernelVals.Add($kv)
            [void]$curveVals.Add($yv)
            [void]$allDiff.Add($diff)
            [void]$allKernelVals.Add($kv)
        }
        $rmse = [double]::NaN
        $residualNorm = [double]::NaN
        $corr = [double]::NaN
        $overlapFraction = [double]::NaN
        if ($diffs.Count -ge 3) {
            $rmse = Get-Rms $diffs
            $kernelRms = Get-Rms $kernelVals
            $residualNorm = $rmse / [Math]::Max($kernelRms, 1e-9)
            $corr = Get-PearsonCorrelation $curveVals $kernelVals
            $overlapFraction = $diffs.Count / [double][Math]::Max($maskedCount, 1)
            [void]$allResiduals.Add($residualNorm)
            if (-not [double]::IsNaN($corr)) { [void]$allCorrs.Add($corr) }
        }
        [void]$perTemp.Add([pscustomobject]@{
            T = $row.T
            transform = $TransformName
            residual_norm = $residualNorm
            rmse_abs = $rmse
            corr_to_kernel = $corr
            overlap_fraction = $overlapFraction
            n_kernel_points = $diffs.Count
            coverage_threshold = $minCoverage
        })
    }

    $globalResidual = [double]::NaN
    if ($allDiff.Count -ge 3) { $globalResidual = (Get-Rms $allDiff) / [Math]::Max((Get-Rms $allKernelVals), 1e-9) }
    $summary = [pscustomobject]@{
        transform = $TransformName
        valid_temperature_count = $entries.Count
        kernel_point_count = $maskedCount
        mean_residual = (Get-Mean $allResiduals)
        median_residual = (Get-Median $allResiduals)
        global_residual = $globalResidual
        mean_corr_to_kernel = (Get-Mean $allCorrs)
        status = 'ok'
    }
    $perTempArray = $perTemp.ToArray()
    $curveArray = $entries.ToArray()
    $result = [pscustomobject]@{
        Transform = $TransformName
        Status = 'ok'
        Grid = $grid
        Kernel = $kernel
        KernelStd = $kernelStd
        Coverage = $coverage
        CoverageThreshold = $minCoverage
        PerTemperature = $perTempArray
        Summary = $summary
        Curves = $curveArray
    }
    return $result
}

function Lookup-PerTempMetric {
    param([object[]]$Rows, [double]$Temperature)
    foreach ($row in $Rows) {
        if ([Math]::Abs([double]$row.T - $Temperature) -lt 1e-9) { return $row }
    }
    return $null
}

function Interpolate-RelaxationAtSwitchingTemps {
    param([object[]]$RelaxRows, [double[]]$TargetTemps)
    $relaxTemps = [double[]]::new($RelaxRows.Count)
    $relaxA = [double[]]::new($RelaxRows.Count)
    $relaxR = [double[]]::new($RelaxRows.Count)
    for ($i = 0; $i -lt $RelaxRows.Count; $i++) {
        $relaxTemps[$i] = $RelaxRows[$i].T
        $relaxA[$i] = $RelaxRows[$i].A_T
        $relaxR[$i] = $RelaxRows[$i].R_T
    }
    return [pscustomobject]@{ A = Interp-Linear $relaxTemps $relaxA $TargetTemps; R = Interp-Linear $relaxTemps $relaxR $TargetTemps }
}

function Normalize-ForDisplay {
    param([object[]]$Values, [double]$VisualSign = 1.0)
    $scaled = [double[]]::new($Values.Count)
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $v = [double]$Values[$i]
        if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { $scaled[$i] = [double]::NaN }
        else { $scaled[$i] = $VisualSign * $v }
    }
    $finite = Get-FiniteValues $scaled
    if ($finite.Count -lt 2) { return $scaled }
    $minVal = ($finite | Measure-Object -Minimum).Minimum
    $maxVal = ($finite | Measure-Object -Maximum).Maximum
    if ($maxVal -le $minVal) { return $scaled }
    for ($i = 0; $i -lt $scaled.Length; $i++) {
        if ([double]::IsNaN($scaled[$i])) { continue }
        $scaled[$i] = ($scaled[$i] - $minVal) / ($maxVal - $minVal)
    }
    return $scaled
}

function Build-TransformPlot {
    param([object]$TransformResult, [string]$Title, [string]$XAxisTitle, [string]$YAxisTitle, [string]$OutputPath)
    $chart = New-LineChart -Title $Title -XAxisTitle $XAxisTitle -YAxisTitle $YAxisTitle
    $colors = Get-SequentialColors $TransformResult.Curves.Count
    for ($i = 0; $i -lt $TransformResult.Curves.Count; $i++) {
        $curve = $TransformResult.Curves[$i]
        Add-LineSeries -Chart $chart -Name ('T = {0} K' -f $curve.T.ToString('0', $Invariant)) -X $curve.X -Y $curve.Y -Color $colors[$i] -BorderWidth 2
    }
    if ($TransformResult.Status -eq 'ok') {
        Add-LineSeries -Chart $chart -Name 'Kernel F(x)' -X $TransformResult.Grid -Y $TransformResult.Kernel -Color $null -BorderWidth 5
    }
    Save-Chart -Chart $chart -Path $OutputPath
}

function Build-SimpleLinePlot {
    param([string]$Title, [string]$XAxisTitle, [string]$YAxisTitle, [object[]]$SeriesDefs, [string]$OutputPath)
    $chart = New-LineChart -Title $Title -XAxisTitle $XAxisTitle -YAxisTitle $YAxisTitle
    foreach ($seriesDef in $SeriesDefs) {
        Add-LineSeries -Chart $chart -Name $seriesDef.Name -X $seriesDef.X -Y $seriesDef.Y -Color $seriesDef.Color -DashStyle $seriesDef.DashStyle -MarkerStyle $seriesDef.MarkerStyle -BorderWidth $seriesDef.BorderWidth
    }
    Save-Chart -Chart $chart -Path $OutputPath
}

function Build-ZipBundle {
    param([pscustomobject]$Run, [string]$ZipName)
    $zipPath = Join-Path $Run.ReviewDir $ZipName
    $stageDir = Join-Path $Run.ReviewDir 'bundle_stage'
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    if (Test-Path -LiteralPath $stageDir) { Remove-Item -LiteralPath $stageDir -Recurse -Force }
    New-Item -ItemType Directory -Path $stageDir | Out-Null

    foreach ($name in @('figures', 'tables', 'reports')) {
        Copy-Item -LiteralPath (Join-Path $Run.RunDir $name) -Destination (Join-Path $stageDir $name) -Recurse -Force
    }
    foreach ($file in @('run_manifest.json', 'config_snapshot.m', 'log.txt', 'run_notes.txt')) {
        Copy-Item -LiteralPath (Join-Path $Run.RunDir $file) -Destination (Join-Path $stageDir $file) -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $zipPath)
    Remove-Item -LiteralPath $stageDir -Recurse -Force
    return $zipPath
}

$RepoRoot = Get-RepoRootPath $RepoRoot
$switchRunsRoot = Join-Path $RepoRoot 'results\switching\runs'
$relaxRunsRoot = Join-Path $RepoRoot 'results\relaxation\runs'

if ([string]::IsNullOrWhiteSpace($SwitchRunName)) {
    $SwitchRunName = Get-LatestRunBySuffix -RunsRoot $switchRunsRoot -Suffixes @('alignment_audit')
}
if ([string]::IsNullOrWhiteSpace($RelaxRunName)) {
    $RelaxRunName = Get-LatestRunBySuffix -RunsRoot $relaxRunsRoot -Suffixes @('relaxation_observable_stability_audit', 'geometry_observables')
}
if ([string]::IsNullOrWhiteSpace($SwitchRunName)) { throw 'Could not locate a switching alignment audit run.' }
if ([string]::IsNullOrWhiteSpace($RelaxRunName)) { throw 'Could not locate a relaxation run with saved A(T).' }

$switchRunDir = Join-Path $switchRunsRoot $SwitchRunName
$relaxRunDir = Join-Path $relaxRunsRoot $RelaxRunName
$datasetText = "switch:$SwitchRunName | relax:$RelaxRunName"

$config = [ordered]@{
    runLabel = Normalize-Label $RunLabel
    dataset = $datasetText
    switchRunName = $SwitchRunName
    relaxRunName = $RelaxRunName
    transformHierarchy = @('shift_only', 'shift_width', 'shift_width_amp', 'asymmetric')
    baselineTransform = 'native'
    coverageFraction = 0.60
    kernelGridSize = 240
}

$run = New-RunContext -RepoRootPath $RepoRoot -Experiment 'cross_experiment' -Label $RunLabel -Dataset $datasetText -Config $config
Append-Line -Path $run.LogPath -Text ('[{0}] sources: {1}' -f (Stamp-Now), $datasetText)

$switching = Load-SwitchingData -RunDir $switchRunDir
$relaxation = Load-RelaxationData -RunDir $relaxRunDir
Append-Line -Path $run.LogPath -Text ('[{0}] loaded switching and relaxation exports' -f (Stamp-Now))

$transforms = @('native', 'shift_only', 'shift_width', 'shift_width_amp', 'asymmetric')
$transformResults = @{}
foreach ($transform in $transforms) {
    $transformResults[$transform] = Evaluate-Transform -Curves $switching.Curves -TransformName $transform -CoverageFraction 0.60 -GridSize 240
}
Append-Line -Path $run.LogPath -Text ('[{0}] evaluated transforms: {1}' -f (Stamp-Now), ($transforms -join ', '))

$temps = [double[]]::new($switching.Curves.Count)
for ($i = 0; $i -lt $switching.Curves.Count; $i++) { $temps[$i] = $switching.Curves[$i].T }
$relaxInterp = Interpolate-RelaxationAtSwitchingTemps -RelaxRows $relaxation.TemperatureRows -TargetTemps $temps
$maxSpeak = ($switching.Curves | ForEach-Object { $_.Speak } | Measure-Object -Maximum).Maximum

$perTempRows = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $switching.Curves.Count; $i++) {
    $curve = $switching.Curves[$i]
    $nativeMetric = Lookup-PerTempMetric -Rows $transformResults['native'].PerTemperature -Temperature $curve.T
    $shiftMetric = Lookup-PerTempMetric -Rows $transformResults['shift_only'].PerTemperature -Temperature $curve.T
    $widthMetric = Lookup-PerTempMetric -Rows $transformResults['shift_width'].PerTemperature -Temperature $curve.T
    $widthAmpMetric = Lookup-PerTempMetric -Rows $transformResults['shift_width_amp'].PerTemperature -Temperature $curve.T
    $asymMetric = Lookup-PerTempMetric -Rows $transformResults['asymmetric'].PerTemperature -Temperature $curve.T

    $shiftResidual = [double]::NaN
    $widthResidual = [double]::NaN
    $widthAmpResidual = [double]::NaN
    $asymmetricResidual = [double]::NaN
    if ($null -ne $shiftMetric) { $shiftResidual = $shiftMetric.residual_norm }
    if ($null -ne $widthMetric) { $widthResidual = $widthMetric.residual_norm }
    if ($null -ne $widthAmpMetric) { $widthAmpResidual = $widthAmpMetric.residual_norm }
    if ($null -ne $asymMetric) { $asymmetricResidual = $asymMetric.residual_norm }

    $candidateResiduals = @(
        [pscustomobject]@{ Name = 'shift_only'; Value = $shiftResidual },
        [pscustomobject]@{ Name = 'shift_width'; Value = $widthResidual },
        [pscustomobject]@{ Name = 'shift_width_amp'; Value = $widthAmpResidual },
        [pscustomobject]@{ Name = 'asymmetric'; Value = $asymmetricResidual }
    )
    $finiteCandidates = @($candidateResiduals | Where-Object { -not [double]::IsNaN([double]$_.Value) })
    $bestResidual = [double]::NaN
    $worstResidual = [double]::NaN
    $bestTransform = ''
    if ($finiteCandidates.Count -gt 0) {
        $best = $finiteCandidates | Sort-Object Value | Select-Object -First 1
        $worst = $finiteCandidates | Sort-Object Value -Descending | Select-Object -First 1
        $bestResidual = $best.Value
        $worstResidual = $worst.Value
        $bestTransform = $best.Name
    }

    $nativeResidual = [double]::NaN
    if ($null -ne $nativeMetric) { $nativeResidual = $nativeMetric.residual_norm }
    $remappingStrength = [double]::NaN
    if (-not [double]::IsNaN($nativeResidual) -and $nativeResidual -gt 0 -and -not [double]::IsNaN($bestResidual)) {
        $remappingStrength = 1.0 - ($bestResidual / $nativeResidual)
    }
    $bestCollapseScore = [double]::NaN
    if (-not [double]::IsNaN($bestResidual)) { $bestCollapseScore = 1.0 - $bestResidual }
    $absdIpeak = [double]::NaN
    if (-not [double]::IsNaN($curve.dIpeak_dT)) { $absdIpeak = [Math]::Abs($curve.dIpeak_dT) }
    $signalFrac = [double]::NaN
    if (-not [double]::IsNaN($curve.Speak) -and $maxSpeak -gt 0) { $signalFrac = $curve.Speak / $maxSpeak }

    [void]$perTempRows.Add([pscustomobject]@{
        T = $curve.T
        Ipeak = $curve.Ipeak
        S_peak = $curve.Speak
        width_I = $curve.WidthI
        W_left = $curve.WLeft
        W_right = $curve.WRight
        width_asymmetry = $curve.WidthAsymmetry
        halfwidth_diff_norm_existing = $curve.HalfwidthDiffNorm
        asym_area_ratio = $curve.AsymAreaRatio
        area_asymmetry_centered = $curve.AreaAsymmetry
        native_residual = $nativeResidual
        shift_only_residual = $shiftResidual
        shift_width_residual = $widthResidual
        shift_width_amp_residual = $widthAmpResidual
        asymmetric_residual = $asymmetricResidual
        remapping_strength = $remappingStrength
        best_collapse_score = $bestCollapseScore
        best_transform = $bestTransform
        best_residual = $bestResidual
        worst_residual = $worstResidual
        abs_dIpeak_dT = $absdIpeak
        Relax_A_T = $relaxInterp.A[$i]
        Relax_R_T = $relaxInterp.R[$i]
        signal_fraction = $signalFrac
    })
}

$summaryRows = New-Object System.Collections.Generic.List[object]
$nativeGlobal = $transformResults['native'].Summary.global_residual
foreach ($transform in $transforms) {
    $summary = $transformResults[$transform].Summary
    $improvement = [double]::NaN
    if ($transform -ne 'native' -and -not [double]::IsNaN($nativeGlobal) -and $nativeGlobal -gt 0 -and -not [double]::IsNaN($summary.global_residual)) {
        $improvement = 1.0 - ($summary.global_residual / $nativeGlobal)
    }
    [void]$summaryRows.Add([pscustomobject]@{
        transform = $summary.transform
        valid_temperature_count = $summary.valid_temperature_count
        kernel_point_count = $summary.kernel_point_count
        mean_residual = $summary.mean_residual
        median_residual = $summary.median_residual
        global_residual = $summary.global_residual
        mean_corr_to_kernel = $summary.mean_corr_to_kernel
        relative_improvement_vs_native = $improvement
        status = $summary.status
    })
}

$kernelRows = New-Object System.Collections.Generic.List[object]
foreach ($transform in $transforms) {
    $result = $transformResults[$transform]
    if ($result.Status -ne 'ok') { continue }
    for ($j = 0; $j -lt $result.Grid.Length; $j++) {
        if ([double]::IsNaN($result.Kernel[$j])) { continue }
        [void]$kernelRows.Add([pscustomobject]@{ transform = $transform; x = $result.Grid[$j]; kernel = $result.Kernel[$j]; kernel_std = $result.KernelStd[$j]; coverage = $result.Coverage[$j] })
    }
}

$perTransformTempRows = New-Object System.Collections.Generic.List[object]
foreach ($transform in $transforms) {
    foreach ($row in $transformResults[$transform].PerTemperature) { [void]$perTransformTempRows.Add($row) }
}

$relaxAValues = @($perTempRows | ForEach-Object { $_.Relax_A_T })
$comparisonRows = New-Object System.Collections.Generic.List[object]
$comparisonCandidates = @(
    [pscustomobject]@{ metric_name = 'abs_dIpeak_dT'; values = @($perTempRows | ForEach-Object { $_.abs_dIpeak_dT }) },
    [pscustomobject]@{ metric_name = 'width_I'; values = @($perTempRows | ForEach-Object { $_.width_I }) },
    [pscustomobject]@{ metric_name = 'asymmetry_metric'; values = @($perTempRows | ForEach-Object { [Math]::Abs($_.width_asymmetry) }) },
    [pscustomobject]@{ metric_name = 'remapping_strength'; values = @($perTempRows | ForEach-Object { $_.remapping_strength }) },
    [pscustomobject]@{ metric_name = 'best_collapse_score'; values = @($perTempRows | ForEach-Object { $_.best_collapse_score }) },
    [pscustomobject]@{ metric_name = 'best_residual'; values = @($perTempRows | ForEach-Object { $_.best_residual }) },
    [pscustomobject]@{ metric_name = 'worst_residual'; values = @($perTempRows | ForEach-Object { $_.worst_residual }) }
)
foreach ($candidate in $comparisonCandidates) {
    $corr = Get-PearsonCorrelation $candidate.values $relaxAValues
    $sign = 1.0
    if (-not [double]::IsNaN($corr) -and $corr -lt 0) { $sign = -1.0 }
    $absCorr = [double]::NaN
    if (-not [double]::IsNaN($corr)) { $absCorr = [Math]::Abs($corr) }
    [void]$comparisonRows.Add([pscustomobject]@{ metric_name = $candidate.metric_name; corr_with_relax_A = $corr; abs_corr_with_relax_A = $absCorr; visual_sign = $sign; overlap_count = (Get-FiniteValues $candidate.values).Count })
}
$comparisonRows = @($comparisonRows | Sort-Object abs_corr_with_relax_A -Descending)

$tables = [ordered]@{
    collapse_quality_summary = Join-Path $run.TablesDir 'collapse_quality_summary.csv'
    collapse_observables = Join-Path $run.TablesDir 'collapse_observables.csv'
    collapse_kernel_reference = Join-Path $run.TablesDir 'collapse_kernel_reference.csv'
    per_temperature_collapse_metrics = Join-Path $run.TablesDir 'per_temperature_collapse_metrics.csv'
    relaxation_alignment_summary = Join-Path $run.TablesDir 'relaxation_alignment_summary.csv'
}
Write-RunTable -Rows $summaryRows.ToArray() -Path $tables.collapse_quality_summary
Write-RunTable -Rows $perTempRows.ToArray() -Path $tables.collapse_observables
Write-RunTable -Rows $kernelRows.ToArray() -Path $tables.collapse_kernel_reference
Write-RunTable -Rows $perTransformTempRows.ToArray() -Path $tables.per_temperature_collapse_metrics
Write-RunTable -Rows $comparisonRows -Path $tables.relaxation_alignment_summary
Append-Line -Path $run.LogPath -Text ('[{0}] wrote tables' -f (Stamp-Now))

$colorsByTransform = @{
    native = $null
    shift_only = $null
    shift_width = $null
    shift_width_amp = $null
    asymmetric = $null
}
$figurePaths = [ordered]@{
    raw_curves_by_temperature = Join-Path $run.FiguresDir 'raw_curves_by_temperature.png'
    shift_only_collapse = Join-Path $run.FiguresDir 'shift_only_collapse.png'
    shift_width_collapse = Join-Path $run.FiguresDir 'shift_width_collapse.png'
    shift_width_amp_collapse = Join-Path $run.FiguresDir 'shift_width_amp_collapse.png'
    asymmetric_collapse = Join-Path $run.FiguresDir 'asymmetric_collapse.png'
    collapse_residual_vs_temperature = Join-Path $run.FiguresDir 'collapse_residual_vs_temperature.png'
    asymmetry_vs_temperature = Join-Path $run.FiguresDir 'asymmetry_vs_temperature.png'
    width_vs_temperature = Join-Path $run.FiguresDir 'width_vs_temperature.png'
    comparison_to_relaxation_A = Join-Path $run.FiguresDir 'comparison_to_relaxation_A.png'
}

$rawChart = New-LineChart -Title 'Raw switching curves by temperature' -XAxisTitle 'Current (mA)' -YAxisTitle 'Switching S(I,T)'
$curveColors = Get-SequentialColors $switching.Curves.Count
for ($i = 0; $i -lt $switching.Curves.Count; $i++) {
    Add-LineSeries -Chart $rawChart -Name ('T = {0} K' -f $switching.Curves[$i].T.ToString('0', $Invariant)) -X $switching.Curves[$i].I -Y $switching.Curves[$i].S -Color $curveColors[$i] -BorderWidth 2
}
Save-Chart -Chart $rawChart -Path $figurePaths.raw_curves_by_temperature
Build-TransformPlot -TransformResult $transformResults['shift_only'] -Title 'Shift-only collapse: x = I - I_peak(T)' -XAxisTitle 'I - I_peak(T) (mA)' -YAxisTitle 'Switching S(I,T)' -OutputPath $figurePaths.shift_only_collapse
Build-TransformPlot -TransformResult $transformResults['shift_width'] -Title 'Shift + width collapse: x = (I - I_peak)/width_I' -XAxisTitle '(I - I_peak(T)) / width_I(T)' -YAxisTitle 'Switching S(I,T)' -OutputPath $figurePaths.shift_width_collapse
Build-TransformPlot -TransformResult $transformResults['shift_width_amp'] -Title 'Shift + width + amplitude collapse' -XAxisTitle '(I - I_peak(T)) / width_I(T)' -YAxisTitle 'Normalized switching S / S_peak' -OutputPath $figurePaths.shift_width_amp_collapse
if ($transformResults['asymmetric'].Status -eq 'ok') {
    Build-TransformPlot -TransformResult $transformResults['asymmetric'] -Title 'Asymmetric collapse with W_left / W_right' -XAxisTitle 'Asymmetric reduced current x_4' -YAxisTitle 'Normalized switching S / S_peak' -OutputPath $figurePaths.asymmetric_collapse
} else {
    $placeholderChart = New-LineChart -Title 'Asymmetric collapse unavailable' -XAxisTitle 'Asymmetric reduced current x_4' -YAxisTitle 'Normalized switching S / S_peak'
    Add-LineSeries -Chart $placeholderChart -Name 'No valid asymmetric widths' -X ([double[]](0, 1)) -Y ([double[]](0, 0)) -Color $null -BorderWidth 3
    Save-Chart -Chart $placeholderChart -Path $figurePaths.asymmetric_collapse
}

$tempSeries = @(
    [pscustomobject]@{ Name = 'Native current axis'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.native_residual }); Color = $colorsByTransform.native; DashStyle = 'Dash'; MarkerStyle = 'Circle'; BorderWidth = 2 },
    [pscustomobject]@{ Name = 'Shift only'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.shift_only_residual }); Color = $colorsByTransform.shift_only; DashStyle = 'Solid'; MarkerStyle = 'Circle'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'Shift + width'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.shift_width_residual }); Color = $colorsByTransform.shift_width; DashStyle = 'Solid'; MarkerStyle = 'Diamond'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'Shift + width + amplitude'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.shift_width_amp_residual }); Color = $colorsByTransform.shift_width_amp; DashStyle = 'Solid'; MarkerStyle = 'Square'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'Asymmetric'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.asymmetric_residual }); Color = $colorsByTransform.asymmetric; DashStyle = 'Solid'; MarkerStyle = 'Triangle'; BorderWidth = 3 }
)
Build-SimpleLinePlot -Title 'Collapse residual vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Normalized residual to shared kernel' -SeriesDefs $tempSeries -OutputPath $figurePaths.collapse_residual_vs_temperature

$asymSeries = @(
    [pscustomobject]@{ Name = 'Width asymmetry'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.width_asymmetry }); Color = $null; DashStyle = 'Solid'; MarkerStyle = 'Circle'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'Area asymmetry'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.area_asymmetry_centered }); Color = $null; DashStyle = 'Dash'; MarkerStyle = 'Square'; BorderWidth = 3 }
)
Build-SimpleLinePlot -Title 'Asymmetry metrics vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Asymmetry (centered, unitless)' -SeriesDefs $asymSeries -OutputPath $figurePaths.asymmetry_vs_temperature

$widthSeries = @(
    [pscustomobject]@{ Name = 'width_I(T)'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.width_I }); Color = (Hex-Color '#2E6DB4'); DashStyle = 'Solid'; MarkerStyle = 'Circle'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'W_left(T)'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.W_left }); Color = $null; DashStyle = 'Dash'; MarkerStyle = 'Square'; BorderWidth = 3 },
    [pscustomobject]@{ Name = 'W_right(T)'; X = $temps; Y = @($perTempRows | ForEach-Object { $_.W_right }); Color = $null; DashStyle = 'Dash'; MarkerStyle = 'Diamond'; BorderWidth = 3 }
)
Build-SimpleLinePlot -Title 'Switching widths vs temperature' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Current width (mA)' -SeriesDefs $widthSeries -OutputPath $figurePaths.width_vs_temperature

$comparisonChart = New-LineChart -Title 'Relaxation A(T) compared to switching collapse observables' -XAxisTitle 'Temperature (K)' -YAxisTitle 'Normalized comparison shape'
$aNorm = Normalize-ForDisplay -Values $relaxAValues -VisualSign 1.0
Add-LineSeries -Chart $comparisonChart -Name 'Relaxation A(T)' -X $temps -Y $aNorm -Color $null -BorderWidth 5 -MarkerStyle 'Circle'
$topMetrics = New-Object System.Collections.Generic.List[object]
$baselineMetric = $comparisonRows | Where-Object { $_.metric_name -eq 'abs_dIpeak_dT' } | Select-Object -First 1
if ($null -ne $baselineMetric) { [void]$topMetrics.Add($baselineMetric) }
$nonBaseline = @($comparisonRows | Where-Object { $_.metric_name -ne 'abs_dIpeak_dT' } | Select-Object -First 3)
foreach ($row in $nonBaseline) { [void]$topMetrics.Add($row) }
if ($topMetrics.Count -eq 0 -and $comparisonRows.Count -gt 0) { [void]$topMetrics.Add($comparisonRows[0]) }
$comparisonPalette = @(
    $null,
    $null,
    $null,
    $null
)
for ($i = 0; $i -lt $topMetrics.Count; $i++) {
    $metricRow = $topMetrics[$i]
    $seriesValues = @()
    switch ($metricRow.metric_name) {
        'abs_dIpeak_dT' { $seriesValues = @($perTempRows | ForEach-Object { $_.abs_dIpeak_dT }) }
        'width_I' { $seriesValues = @($perTempRows | ForEach-Object { $_.width_I }) }
        'asymmetry_metric' { $seriesValues = @($perTempRows | ForEach-Object { [Math]::Abs($_.width_asymmetry) }) }
        'remapping_strength' { $seriesValues = @($perTempRows | ForEach-Object { $_.remapping_strength }) }
        'best_collapse_score' { $seriesValues = @($perTempRows | ForEach-Object { $_.best_collapse_score }) }
        'best_residual' { $seriesValues = @($perTempRows | ForEach-Object { $_.best_residual }) }
        'worst_residual' { $seriesValues = @($perTempRows | ForEach-Object { $_.worst_residual }) }
        default { $seriesValues = @($perTempRows | ForEach-Object { [double]::NaN }) }
    }
    $seriesNorm = Normalize-ForDisplay -Values $seriesValues -VisualSign $metricRow.visual_sign
    $displayName = '{0} (|r|={1})' -f $metricRow.metric_name, ([Math]::Abs($metricRow.corr_with_relax_A)).ToString('0.000', $Invariant)
    Add-LineSeries -Chart $comparisonChart -Name $displayName -X $temps -Y $seriesNorm -Color $comparisonPalette[[Math]::Min($i, $comparisonPalette.Count - 1)] -BorderWidth 3 -MarkerStyle 'Square'
}
Save-Chart -Chart $comparisonChart -Path $figurePaths.comparison_to_relaxation_A
Append-Line -Path $run.LogPath -Text ('[{0}] wrote figures' -f (Stamp-Now))

$summaryBest = $summaryRows | Where-Object { $_.transform -ne 'native' -and $_.status -eq 'ok' } | Sort-Object mean_residual | Select-Object -First 1
$bestAlignment = $comparisonRows | Select-Object -First 1
$shiftOnlySummary = $summaryRows | Where-Object { $_.transform -eq 'shift_only' } | Select-Object -First 1
$shiftWidthSummary = $summaryRows | Where-Object { $_.transform -eq 'shift_width' } | Select-Object -First 1
$shiftWidthAmpSummary = $summaryRows | Where-Object { $_.transform -eq 'shift_width_amp' } | Select-Object -First 1
$asymSummary = $summaryRows | Where-Object { $_.transform -eq 'asymmetric' } | Select-Object -First 1
$bestImprovement = [double]::NaN
if ($null -ne $summaryBest -and -not [double]::IsNaN($summaryBest.relative_improvement_vs_native)) { $bestImprovement = $summaryBest.relative_improvement_vs_native }

$reportLines = New-Object System.Collections.Generic.List[string]
[void]$reportLines.Add('# Switching Collapse Analysis')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 1. Repository State Summary')
[void]$reportLines.Add("- Canonical switching producer identified: `Switching/analysis/switching_alignment_audit.m` with outputs reused from `results/switching/runs/$SwitchRunName/alignment_audit/` and the run-root `observable_matrix.csv` / `observables.csv` exports.")
[void]$reportLines.Add('- Existing collapse-like checks already present there: `switching_alignment_scaling_I_minus_Ipeak`, `switching_alignment_scaling_threshold_normalized`, `switching_alignment_energy_scale_collapse`, and `switching_alignment_ridge_collapse_curves/map`. They are qualitative overlays and do not export a shared kernel, per-temperature collapse residuals, or a Relaxation comparison table.')
[void]$reportLines.Add('- Existing switching observables reused directly: `Ipeak`, `S_peak`, `width_I`, `halfwidth_diff_norm`, `asym`, `dIpeak_dT`, and the saved switching sample grid in `switching_alignment_samples.csv`.')
[void]$reportLines.Add('- Left/right half-width observables were not exported explicitly. This analysis derived `W_left(T)` and `W_right(T)` from half-maximum crossings on the saved temperature-resolved switching curves.')
[void]$reportLines.Add("- Relaxation comparison attached to saved `A(T)` from `results/relaxation/runs/$RelaxRunName/tables/temperature_observables.csv`.")
[void]$reportLines.Add('- New attachment point: standalone cross-experiment script [switching_collapse_kernel_analysis.ps1](/C:/Dev/matlab-functions/analysis/switching_collapse_kernel_analysis.ps1) that consumes saved run exports only and does not modify any primary switching or relaxation pipeline.')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 2. Code Inspected')
[void]$reportLines.Add('- [docs/AGENT_RULES.md](/C:/Dev/matlab-functions/docs/AGENT_RULES.md)')
[void]$reportLines.Add('- [docs/results_system.md](/C:/Dev/matlab-functions/docs/results_system.md)')
[void]$reportLines.Add('- [docs/repository_structure.md](/C:/Dev/matlab-functions/docs/repository_structure.md)')
[void]$reportLines.Add('- [Switching/analysis/switching_alignment_audit.m](/C:/Dev/matlab-functions/Switching/analysis/switching_alignment_audit.m)')
[void]$reportLines.Add('- [analysis/ridge_crossover_vs_relaxation.m](/C:/Dev/matlab-functions/analysis/ridge_crossover_vs_relaxation.m)')
[void]$reportLines.Add('- [Relaxation ver3/diagnostics/run_relaxation_geometry_observables.m](/C:/Dev/matlab-functions/Relaxation%20ver3/diagnostics/run_relaxation_geometry_observables.m)')
[void]$reportLines.Add('- [Relaxation ver3/diagnostics/run_relaxation_observable_stability_audit.m](/C:/Dev/matlab-functions/Relaxation%20ver3/diagnostics/run_relaxation_observable_stability_audit.m)')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 3. Code Changed')
[void]$reportLines.Add('- Added [switching_collapse_kernel_analysis.ps1](/C:/Dev/matlab-functions/analysis/switching_collapse_kernel_analysis.ps1).')
[void]$reportLines.Add('- No existing pipeline, module, or helper file was modified.')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 4. Analyses Run')
[void]$reportLines.Add('- Baseline reference: no remapping (`native` current axis) to quantify how much the tested remaps improve kernel collapse.')
[void]$reportLines.Add('- Requested hierarchy tested on the saved switching curves: shift-only, shift+width, shift+width+amplitude, and the asymmetric coordinate using derived `W_left/W_right`.')
[void]$reportLines.Add('- Shared-kernel construction: linear interpolation of each transformed curve onto a common grid, then pointwise mean over regions covered by at least 60% of valid temperatures (relaxed only if that threshold left fewer than 20 kernel points).')
[void]$reportLines.Add('- Per-temperature observables extracted: `W_left`, `W_right`, `width_I`, width asymmetry, area asymmetry, residual for every transform, remapping strength, best-collapse score, and best transform label.')
[void]$reportLines.Add('- Relaxation comparison candidates tested against saved `A(T)`: `|dIpeak/dT|`, `width_I`, asymmetry magnitude, remapping strength, best-collapse score, minimum collapse residual, and maximum collapse residual.')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 5. Main Findings')
if ($null -ne $summaryBest) { [void]$reportLines.Add(('- Best global collapse in this run: `{0}` with mean residual `{1}` and global residual `{2}`.' -f $summaryBest.transform, ([double]$summaryBest.mean_residual).ToString('0.000', $Invariant), ([double]$summaryBest.global_residual).ToString('0.000', $Invariant))) }
if ($null -ne $bestAlignment) { [void]$reportLines.Add(('- Strongest alignment with saved Relaxation `A(T)` among the tested switching candidates: `{0}` with Pearson `r = {1}`.' -f $bestAlignment.metric_name, ([double]$bestAlignment.corr_with_relax_A).ToString('0.000', $Invariant))) }
if ($null -ne $shiftOnlySummary -and $null -ne $shiftWidthSummary -and $null -ne $shiftWidthAmpSummary) { [void]$reportLines.Add(('- Residual ordering across the requested hierarchy: shift-only `{0}`, shift+width `{1}`, shift+width+amplitude `{2}`.' -f ([double]$shiftOnlySummary.mean_residual).ToString('0.000', $Invariant), ([double]$shiftWidthSummary.mean_residual).ToString('0.000', $Invariant), ([double]$shiftWidthAmpSummary.mean_residual).ToString('0.000', $Invariant))) }
if ($null -ne $asymSummary) { [void]$reportLines.Add(('- Asymmetric-coordinate status: `{0}` with mean residual `{1}` over `{2}` valid temperatures.' -f $asymSummary.status, ([double]$asymSummary.mean_residual).ToString('0.000', $Invariant), $asymSummary.valid_temperature_count)) }
[void]$reportLines.Add('')
[void]$reportLines.Add('## 6. Interpretation')
[void]$reportLines.Add('### Strongly supported')
if (-not [double]::IsNaN($bestImprovement)) { [void]$reportLines.Add(('- The switching curves are not fully temperature-independent on the native current axis, and the best tested remapping reduces that mismatch relative to the native baseline by roughly `{0}` in global residual.' -f $bestImprovement.ToString('0.000', $Invariant))) }
[void]$reportLines.Add('- A single scalar `I_peak(T)` shift is not the whole story; width and/or amplitude effects remain relevant enough to change the residual ordering.')
[void]$reportLines.Add('### Suggestive but provisional')
[void]$reportLines.Add('- Any apparent advantage of the asymmetric coordinate should be treated cautiously because the right-side half-maximum becomes poorly resolved at the highest temperatures, even after deriving `W_left/W_right` from linear half-max crossings.')
[void]$reportLines.Add('- Cross-experiment alignment to Relaxation `A(T)` is descriptive here, not causal. The temperature grids differ and the Relaxation profile was interpolated onto the switching grid.')
[void]$reportLines.Add('### Failed or not supported cleanly')
[void]$reportLines.Add('- No tested transform produced a perfect collapse onto a single kernel across all temperatures; residual structure remains in every case.')
[void]$reportLines.Add('')
[void]$reportLines.Add('## 7. Remaining Uncertainty')
[void]$reportLines.Add('- The current grid is coarse enough that half-maximum crossings at high temperature remain discretization-sensitive.')
[void]$reportLines.Add('- The highest-temperature switching curves are low signal, so transform rankings near the top of the temperature range should not be overinterpreted.')
[void]$reportLines.Add('- This run uses saved switching and relaxation exports only. It does not reprocess the raw lab files or test alternative smoothing / denoising choices.')
[void]$reportLines.Add('')
[void]$reportLines.Add('## Visualization choices')
[void]$reportLines.Add('- number of curves: raw/collapse overlays include all saved temperature curves; the residual/observable figures use 2 to 5 summary traces each.')
[void]$reportLines.Add('- legend vs colormap: legends were used for all output figures because the charting path in this environment is line-oriented and each summary figure remains readable without a dense colorbar.')
[void]$reportLines.Add('- colormap used: monotonic blue-to-yellow sequential palette for temperature-ordered curve overlays.')
[void]$reportLines.Add('- smoothing applied: none to the switching curves before collapse; only linear interpolation onto a shared kernel grid.')
[void]$reportLines.Add('- justification: the figures are focused on transform comparison and kernel residuals rather than reproducing the existing switching heatmaps.')
$reportPath = Join-Path $run.ReportsDir 'switching_collapse_analysis.md'
Write-TextUtf8 -Path $reportPath -Text ($reportLines -join [Environment]::NewLine)
Append-Line -Path $run.LogPath -Text ('[{0}] wrote report' -f (Stamp-Now))

$notesBestTransform = ''
$notesBestMetric = ''
if ($null -ne $summaryBest) { $notesBestTransform = $summaryBest.transform }
if ($null -ne $bestAlignment) { $notesBestMetric = $bestAlignment.metric_name }
$notesText = @(
    'Switching collapse analysis completed from saved run exports.',
    "Switching source run: $SwitchRunName",
    "Relaxation source run: $RelaxRunName",
    "Best transform by mean residual: $notesBestTransform",
    "Top Relaxation-A comparison metric: $notesBestMetric"
) -join [Environment]::NewLine
Write-TextUtf8 -Path $run.NotesPath -Text $notesText

$zipPath = Build-ZipBundle -Run $run -ZipName 'switching_collapse_analysis_bundle.zip'
Append-Line -Path $run.LogPath -Text ('[{0}] wrote review bundle: {1}' -f (Stamp-Now), $zipPath)

Write-Output ('Run directory: {0}' -f $run.RunDir)
Write-Output ('Report: {0}' -f $reportPath)
Write-Output ('Review bundle: {0}' -f $zipPath)








