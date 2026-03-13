param()

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$repoRoot = 'C:\Dev\matlab-functions'
$relaxRunDir = Join-Path $repoRoot 'results\relaxation\runs\run_2026_03_10_175048_relaxation_observable_stability_audit'
$switchRunDir = Join-Path $repoRoot 'results\switching\runs\run_2026_03_10_112659_alignment_audit'
$agingRunsRoot = Join-Path $repoRoot 'results\aging\runs'

function Get-LatestRunDir([string]$root, [string]$pattern) {
    $dirs = Get-ChildItem -Path $root -Directory -Filter $pattern | Sort-Object Name
    if (-not $dirs) { throw "No run directories found for pattern $pattern under $root" }
    return $dirs[-1].FullName
}

function To-Double($value) {
    if ($null -eq $value) { return [double]::NaN }
    $text = "$value".Trim()
    if ($text -eq '' -or $text -eq 'NaN') { return [double]::NaN }
    return [double]$text
}

function IsFiniteD($value) {
    if ($null -eq $value) { return $false }
    $d = [double]$value
    return (-not [double]::IsNaN($d)) -and (-not [double]::IsInfinity($d))
}

function Get-FiniteValues([double[]]$values) {
    return $values | Where-Object { IsFiniteD $_ }
}

function MinMaxScale([double[]]$values) {
    $finite = Get-FiniteValues $values
    $result = New-Object double[] $values.Count
    for ($i = 0; $i -lt $result.Count; $i++) { $result[$i] = [double]::NaN }
    if (-not $finite -or $finite.Count -eq 0) { return $result }
    $min = ($finite | Measure-Object -Minimum).Minimum
    $max = ($finite | Measure-Object -Maximum).Maximum
    if ($max -le $min) {
        for ($i = 0; $i -lt $values.Count; $i++) {
            if ((IsFiniteD $values[$i])) { $result[$i] = 0.5 }
        }
        return $result
    }
    for ($i = 0; $i -lt $values.Count; $i++) {
        if ((IsFiniteD $values[$i])) {
            $result[$i] = ($values[$i] - $min) / ($max - $min)
        }
    }
    return $result
}

function Gradient([double[]]$x, [double[]]$y) {
    $n = $x.Count
    $grad = New-Object double[] $n
    for ($i = 0; $i -lt $n; $i++) { $grad[$i] = [double]::NaN }
    if ($n -lt 2) { return $grad }
    $grad[0] = ($y[1] - $y[0]) / [Math]::Max($x[1] - $x[0], 1e-12)
    $grad[$n - 1] = ($y[$n - 1] - $y[$n - 2]) / [Math]::Max($x[$n - 1] - $x[$n - 2], 1e-12)
    for ($i = 1; $i -lt $n - 1; $i++) {
        $grad[$i] = ($y[$i + 1] - $y[$i - 1]) / [Math]::Max($x[$i + 1] - $x[$i - 1], 1e-12)
    }
    return $grad
}

function InterpolateLinear([double[]]$x, [double[]]$y, [double[]]$query) {
    $pairs = @()
    for ($i = 0; $i -lt $x.Count; $i++) {
        if ((IsFiniteD $x[$i]) -and (IsFiniteD $y[$i])) {
            $pairs += [pscustomobject]@{ X = $x[$i]; Y = $y[$i] }
        }
    }
    $pairs = $pairs | Sort-Object X
    $result = New-Object double[] $query.Count
    for ($i = 0; $i -lt $result.Count; $i++) { $result[$i] = [double]::NaN }
    if ($pairs.Count -lt 2) { return $result }

    for ($qi = 0; $qi -lt $query.Count; $qi++) {
        $qx = $query[$qi]
        if ($qx -lt $pairs[0].X -or $qx -gt $pairs[-1].X) { continue }
        for ($pi = 0; $pi -lt $pairs.Count - 1; $pi++) {
            $x0 = $pairs[$pi].X
            $x1 = $pairs[$pi + 1].X
            if ($qx -ge $x0 -and $qx -le $x1) {
                if ($x1 -eq $x0) {
                    $result[$qi] = $pairs[$pi].Y
                } else {
                    $t = ($qx - $x0) / ($x1 - $x0)
                    $result[$qi] = (1 - $t) * $pairs[$pi].Y + $t * $pairs[$pi + 1].Y
                }
                break
            }
        }
    }
    return $result
}

function MeanAvailable([double[]]$values) {
    $finite = Get-FiniteValues $values
    if (-not $finite -or $finite.Count -eq 0) { return [double]::NaN }
    return ($finite | Measure-Object -Average).Average
}

function MaxFinite([double[]]$values) {
    $finite = Get-FiniteValues $values
    if (-not $finite -or $finite.Count -eq 0) { return [double]::NaN }
    return ($finite | Measure-Object -Maximum).Maximum
}

function FindMaxFiniteIndex([double[]]$values) {
    $bestValue = [double]::NegativeInfinity
    $bestIndex = 0
    for ($i = 0; $i -lt $values.Count; $i++) {
        if ((IsFiniteD $values[$i]) -and $values[$i] -gt $bestValue) {
            $bestValue = $values[$i]
            $bestIndex = $i
        }
    }
    return $bestIndex
}

function New-BitmapContext([int]$width, [int]$height) {
    $bmp = New-Object System.Drawing.Bitmap $width, $height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::White)
    return [pscustomobject]@{ Bitmap = $bmp; Graphics = $g }
}

function Save-BitmapContext($ctx, [string]$path) {
    $ctx.Bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $ctx.Graphics.Dispose()
    $ctx.Bitmap.Dispose()
}

function New-PenObj([System.Drawing.Color]$color, [float]$width, [string]$dash = 'Solid') {
    $pen = New-Object System.Drawing.Pen $color, $width
    if ($dash -eq 'Dash') {
        $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    }
    return $pen
}

function Draw-StringCentered($g, [string]$text, $font, $brush, [System.Drawing.RectangleF]$rect) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($text, $font, $brush, $rect, $sf)
    $sf.Dispose()
}

function Draw-LinePanel {
    param(
        $g,
        [System.Drawing.RectangleF]$rect,
        [string]$title,
        [string]$xLabel,
        [string]$yLabel,
        [array]$series,
        [double]$yMin,
        [double]$yMax,
        [array]$bands = @(),
        [bool]$showLegend = $false
    )

    $plot = New-Object System.Drawing.RectangleF ($rect.X + 55), ($rect.Y + 30), ($rect.Width - 80), ($rect.Height - 65)
    $fontTitle = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Bold)
    $fontAxis = New-Object System.Drawing.Font 'Segoe UI', 9
    $brushBlack = [System.Drawing.Brushes]::Black
    $brushGrid = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(18, 0, 0, 0))
    $penAxis = New-PenObj ([System.Drawing.Color]::FromArgb(255, 80, 80, 80)) 1.0
    $penGrid = New-PenObj ([System.Drawing.Color]::FromArgb(60, 180, 180, 180)) 1.0

    $allX = @()
    foreach ($s in $series) {
        $allX += ($s.X | Where-Object { (IsFiniteD $_) })
    }
    $xMin = ($allX | Measure-Object -Minimum).Minimum
    $xMax = ($allX | Measure-Object -Maximum).Maximum
    if ($xMax -le $xMin) { $xMax = $xMin + 1 }
    if ($yMax -le $yMin) { $yMax = $yMin + 1 }

    foreach ($band in $bands) {
        $bx0 = $plot.X + (($band.X0 - $xMin) / ($xMax - $xMin)) * $plot.Width
        $bx1 = $plot.X + (($band.X1 - $xMin) / ($xMax - $xMin)) * $plot.Width
        $bandBrush = New-Object System.Drawing.SolidBrush $band.Color
        $g.FillRectangle($bandBrush, $bx0, $plot.Y, ($bx1 - $bx0), $plot.Height)
        $bandBrush.Dispose()
    }

    for ($i = 0; $i -le 4; $i++) {
        $gx = $plot.X + $i * $plot.Width / 4.0
        $gy = $plot.Y + $i * $plot.Height / 4.0
        $g.DrawLine($penGrid, $gx, $plot.Y, $gx, $plot.Bottom)
        $g.DrawLine($penGrid, $plot.X, $gy, $plot.Right, $gy)
    }

    $g.DrawRectangle($penAxis, $plot.X, $plot.Y, $plot.Width, $plot.Height)

    foreach ($s in $series) {
        $pen = New-PenObj $s.Color ([float]$s.Width) $s.Dash
        $points = New-Object System.Collections.Generic.List[System.Drawing.PointF]
        for ($i = 0; $i -lt $s.X.Count; $i++) {
            if ((IsFiniteD $s.X[$i]) -and (IsFiniteD $s.Y[$i])) {
                $px = $plot.X + (($s.X[$i] - $xMin) / ($xMax - $xMin)) * $plot.Width
                $py = $plot.Bottom - (($s.Y[$i] - $yMin) / ($yMax - $yMin)) * $plot.Height
                $points.Add((New-Object System.Drawing.PointF ([float]$px), ([float]$py)))
            } elseif ($points.Count -ge 2) {
                $g.DrawLines($pen, $points.ToArray())
                $points.Clear()
            } else {
                $points.Clear()
            }
        }
        if ($points.Count -ge 2) {
            $g.DrawLines($pen, $points.ToArray())
        }
        $pen.Dispose()
    }

    Draw-StringCentered $g $title $fontTitle $brushBlack (New-Object System.Drawing.RectangleF $rect.X, $rect.Y, $rect.Width, 22)
    Draw-StringCentered $g $xLabel $fontAxis $brushBlack (New-Object System.Drawing.RectangleF $plot.X, ($rect.Bottom - 20), $plot.Width, 20)
    $g.DrawString($yLabel, $fontAxis, $brushBlack, ($rect.X + 2), ($plot.Y - 2))

    for ($i = 0; $i -le 4; $i++) {
        $xTickVal = $xMin + $i * ($xMax - $xMin) / 4.0
        $yTickVal = $yMax - $i * ($yMax - $yMin) / 4.0
        $gx = $plot.X + $i * $plot.Width / 4.0
        $gy = $plot.Y + $i * $plot.Height / 4.0
        Draw-StringCentered $g ([Math]::Round($xTickVal, 1).ToString()) $fontAxis $brushBlack (New-Object System.Drawing.RectangleF ($gx - 20), $plot.Bottom + 2, 40, 16)
        $g.DrawString(([Math]::Round($yTickVal, 2).ToString()), $fontAxis, $brushBlack, ($rect.X + 2), ($gy - 7))
    }

    if ($showLegend) {
        $legendX = $plot.Right - 170
        $legendY = $plot.Y + 8
        foreach ($s in $series) {
            $pen = New-PenObj $s.Color 2.2 $s.Dash
            $g.DrawLine($pen, $legendX, $legendY + 8, $legendX + 20, $legendY + 8)
            $g.DrawString($s.Name, $fontAxis, $brushBlack, ($legendX + 26), $legendY)
            $legendY += 18
            $pen.Dispose()
        }
    }

    $fontTitle.Dispose()
    $fontAxis.Dispose()
    $brushGrid.Dispose()
    $penAxis.Dispose()
    $penGrid.Dispose()
}
function Get-Color([string]$name) {
    switch ($name) {
        'mobile' { return [System.Drawing.Color]::FromArgb(72, 176, 120) }
        'pinned' { return [System.Drawing.Color]::FromArgb(185, 94, 73) }
        'activation' { return [System.Drawing.Color]::FromArgb(209, 171, 51) }
        'participation' { return [System.Drawing.Color]::FromArgb(52, 94, 179) }
        'motion' { return [System.Drawing.Color]::FromArgb(135, 57, 157) }
        'inactive' { return [System.Drawing.Color]::FromArgb(210, 210, 210) }
        default { return [System.Drawing.Color]::Black }
    }
}

function Draw-HeatmapFigure($gridRows, $outputPath) {
    $ctx = New-BitmapContext 1280 780
    $g = $ctx.Graphics
    $fontTitle = New-Object System.Drawing.Font 'Segoe UI', 15, ([System.Drawing.FontStyle]::Bold)
    $fontAxis = New-Object System.Drawing.Font 'Segoe UI', 9
    $brushBlack = [System.Drawing.Brushes]::Black

    $g.DrawString('Barrier mechanism map', $fontTitle, $brushBlack, 40, 20)
    $stripRect = New-Object System.Drawing.RectangleF 150, 70, 1030, 40
    $heatRect = New-Object System.Drawing.RectangleF 150, 150, 1030, 480
    $labels = @('A(T)', 'Dip depth', 'FM abs', 'S_peak', 'motion', 'current ease')
    $keys = @('A_scale', 'Dip_scale', 'FM_scale', 'S_scale', 'motion_scale', 'current_ease_scale')

    $n = $gridRows.Count
    for ($i = 0; $i -lt $n; $i++) {
        $row = $gridRows[$i]
        $x0 = $stripRect.X + $i * $stripRect.Width / $n
        $x1 = $stripRect.X + ($i + 1) * $stripRect.Width / $n
        $color = switch ($row.cluster_label) {
            'mobile_memory' { Get-Color 'mobile' }
            'pinned_dominant' { Get-Color 'pinned' }
            'activation_dominant' { Get-Color 'activation' }
            'participation_tail' { Get-Color 'participation' }
            default { Get-Color 'inactive' }
        }
        $brush = New-Object System.Drawing.SolidBrush $color
        $g.FillRectangle($brush, $x0, $stripRect.Y, ($x1 - $x0), $stripRect.Height)
        $brush.Dispose()
    }
    $g.DrawRectangle((New-PenObj ([System.Drawing.Color]::Black) 1.0), $stripRect.X, $stripRect.Y, $stripRect.Width, $stripRect.Height)
    $g.DrawString('feature-state clustering', $fontAxis, $brushBlack, 40, 82)

    for ($r = 0; $r -lt $keys.Count; $r++) {
        $g.DrawString($labels[$r], $fontAxis, $brushBlack, 35, ($heatRect.Y + $r * $heatRect.Height / $keys.Count + 18))
        for ($i = 0; $i -lt $n; $i++) {
            $value = To-Double $gridRows[$i].($keys[$r])
            if (-not (IsFiniteD $value)) { $value = 0 }
            $c0 = [int](255 * $value)
            $c1 = [int](220 * (1 - $value) + 35)
            $color = [System.Drawing.Color]::FromArgb(255, $c0, 80, $c1)
            $brush = New-Object System.Drawing.SolidBrush $color
            $x0 = $heatRect.X + $i * $heatRect.Width / $n
            $y0 = $heatRect.Y + $r * $heatRect.Height / $keys.Count
            $w = $heatRect.Width / $n + 1
            $h = $heatRect.Height / $keys.Count + 1
            $g.FillRectangle($brush, $x0, $y0, $w, $h)
            $brush.Dispose()
        }
    }
    $g.DrawRectangle((New-PenObj ([System.Drawing.Color]::Black) 1.0), $heatRect.X, $heatRect.Y, $heatRect.Width, $heatRect.Height)

    for ($i = 0; $i -le 5; $i++) {
        $x = $heatRect.X + $i * $heatRect.Width / 5.0
        $idx = [Math]::Min($n - 1, [int][Math]::Round($i * ($n - 1) / 5.0))
        $lbl = [Math]::Round((To-Double $gridRows[$idx].barrier_meV), 1)
        Draw-StringCentered $g $lbl $fontAxis $brushBlack (New-Object System.Drawing.RectangleF ($x - 20), ($heatRect.Bottom + 8), 40, 15)
    }
    Draw-StringCentered $g 'Effective barrier E_eff (meV)' $fontAxis $brushBlack (New-Object System.Drawing.RectangleF $heatRect.X, ($heatRect.Bottom + 25), $heatRect.Width, 18)

    $fontTitle.Dispose()
    $fontAxis.Dispose()
    Save-BitmapContext $ctx $outputPath
}

$agingObservableRunDir = Get-LatestRunDir $agingRunsRoot 'run_*_observable_identification_audit'
$agingShapeRunDir = Get-LatestRunDir $agingRunsRoot 'run_*_aging_shape_collapse_analysis*'

$relaxTemp = Import-Csv (Join-Path $relaxRunDir 'tables\temperature_observables.csv')
$relaxSummary = (Import-Csv (Join-Path $relaxRunDir 'tables\observables_relaxation.csv'))[0]
$switchObs = Import-Csv (Join-Path $switchRunDir 'alignment_audit\switching_alignment_observables_vs_T.csv')
$agingMetrics = Import-Csv (Join-Path $agingObservableRunDir 'tables\aging_tp_observable_metrics.csv')
$agingShape = Import-Csv (Join-Path $agingShapeRunDir 'tables\aging_shape_variation_vs_Tp.csv')

$referenceTime = To-Double $relaxSummary.Relax_t_half
if (-not (IsFiniteD $referenceTime) -or $referenceTime -le 0) {
    $referenceTime = To-Double $relaxSummary.Relax_tau_global
}
$attemptTime = 1e-9
$logFactor = [Math]::Log($referenceTime / $attemptTime)
$kBmeV = 0.08617333262

$relaxT = @($relaxTemp | ForEach-Object { To-Double $_.T })
$relaxA = @($relaxTemp | ForEach-Object { To-Double $_.A_T })

$switchT = @($switchObs | ForEach-Object { To-Double $_.T_K })
$switchI = @($switchObs | ForEach-Object { To-Double $_.Ipeak })
$switchS = @($switchObs | ForEach-Object { To-Double $_.S_peak })
$switchMotion = Gradient $switchT $switchI | ForEach-Object { [Math]::Abs($_) }
$currentEaseRaw = @()
$imax = MaxFinite $switchI
for ($i = 0; $i -lt $switchI.Count; $i++) {
    if ((IsFiniteD $switchI[$i]) -and (IsFiniteD $imax)) { $currentEaseRaw += ($imax - $switchI[$i]) } else { $currentEaseRaw += [double]::NaN }
}

$dipMap = @{}
$fmMap = @{}
foreach ($row in $agingMetrics) {
    $tp = [int](To-Double $row.Tp_K)
    if ($row.observable -eq 'Dip_depth') { $dipMap[$tp] = To-Double $row.mean_value }
    if ($row.observable -eq 'FM_abs') { $fmMap[$tp] = To-Double $row.mean_value }
}
$shapeMap = @{}
foreach ($row in $agingShape) {
    $shapeMap[[int](To-Double $row.Tp_K)] = [pscustomobject]@{
        shape_variation = To-Double $row.shape_variation
        rank1 = To-Double $row.rank1_explained_variance_ratio
    }
}

$agingT = @($dipMap.Keys | Sort-Object)
$agingDip = @($agingT | ForEach-Object { [double]$dipMap[$_] })
$agingFmT = @($fmMap.Keys | Sort-Object)
$agingFm = @($agingFmT | ForEach-Object { [double]$fmMap[$_] })

$projectionRows = @()
function Add-ProjectionRows([string]$experiment, [string]$observable, [double[]]$temps, [double[]]$values, [string]$sourceRun) {
    for ($i = 0; $i -lt $temps.Count; $i++) {
        $projectionRows += [pscustomobject]@{
            experiment = $experiment
            observable = $observable
            temperature_K = $temps[$i]
            barrier_over_kB_K = if ((IsFiniteD $temps[$i])) { $temps[$i] * $logFactor } else { [double]::NaN }
            barrier_meV = if ((IsFiniteD $temps[$i])) { $temps[$i] * $logFactor * $kBmeV } else { [double]::NaN }
            value = $values[$i]
            source_run = $sourceRun
        }
    }
}

Add-ProjectionRows 'relaxation' 'A_T' $relaxT $relaxA $relaxRunDir
Add-ProjectionRows 'aging' 'Dip_depth' $agingT $agingDip $agingObservableRunDir
Add-ProjectionRows 'aging' 'FM_abs' $agingFmT $agingFm $agingObservableRunDir
Add-ProjectionRows 'switching' 'I_peak' $switchT $switchI $switchRunDir
Add-ProjectionRows 'switching' 'S_peak' $switchT $switchS $switchRunDir
Add-ProjectionRows 'switching' 'motion' $switchT $switchMotion $switchRunDir

foreach ($group in ($projectionRows | Group-Object observable)) {
    $scaled = MinMaxScale @($group.Group | ForEach-Object { To-Double $_.value })
    for ($i = 0; $i -lt $group.Group.Count; $i++) {
        $group.Group[$i] | Add-Member -NotePropertyName normalized_value -NotePropertyValue $scaled[$i] -Force
    }
}
$gridTemps = 4..34 | ForEach-Object { [double]$_ }
$Agrid = InterpolateLinear $relaxT $relaxA $gridTemps
$DipGrid = InterpolateLinear $agingT $agingDip $gridTemps
$FMgrid = InterpolateLinear $agingFmT $agingFm $gridTemps
$Igrid = InterpolateLinear $switchT $switchI $gridTemps
$Sgrid = InterpolateLinear $switchT $switchS $gridTemps
$motionGrid = InterpolateLinear $switchT $switchMotion $gridTemps

$A_scale = MinMaxScale $Agrid
$Dip_scale = MinMaxScale $DipGrid
$FM_scale = MinMaxScale $FMgrid
$S_scale = MinMaxScale $Sgrid
$motion_scale = MinMaxScale $motionGrid
$current_ease_scale = MinMaxScale (InterpolateLinear $switchT $currentEaseRaw $gridTemps)

$gridRows = @()
$regionId = 0
$prevLabel = ''
for ($i = 0; $i -lt $gridTemps.Count; $i++) {
    $mobile = MeanAvailable @($A_scale[$i], $Dip_scale[$i])
    $pinned = MeanAvailable @($A_scale[$i], $FM_scale[$i])
    $activation = MeanAvailable @($A_scale[$i], $S_scale[$i], $motion_scale[$i], $current_ease_scale[$i])
    $label = 'inactive_tail'
    $scores = @($mobile, $pinned, $activation)
    $best = MaxFinite $scores
    if ((IsFiniteD $best) -and $best -ge 0.12 -and (IsFiniteD $A_scale[$i]) -and $A_scale[$i] -ge 0.05) {
        if ($activation -eq $best -and $best -ge 0.18) { $label = 'switching_activation_window' }
        elseif ($pinned -eq $best) { $label = 'pinned_sector' }
        else { $label = 'mobile_sector' }
    }
    if ($label -ne $prevLabel) { $regionId += 1 }
    $prevLabel = $label

    $cluster = switch ($label) {
        'mobile_sector' { 'mobile_memory' }
        'pinned_sector' { 'pinned_dominant' }
        'switching_activation_window' { 'activation_dominant' }
        default {
            if ((IsFiniteD $A_scale[$i]) -and $A_scale[$i] -ge 0.18) { 'participation_tail' } else { 'inactive_tail' }
        }
    }

    $gridRows += [pscustomobject]@{
        temperature_K = $gridTemps[$i]
        barrier_over_kB_K = $gridTemps[$i] * $logFactor
        barrier_meV = $gridTemps[$i] * $logFactor * $kBmeV
        A_T = $Agrid[$i]
        Dip_depth = $DipGrid[$i]
        FM_abs = $FMgrid[$i]
        I_peak = $Igrid[$i]
        S_peak = $Sgrid[$i]
        motion = $motionGrid[$i]
        A_scale = $A_scale[$i]
        Dip_scale = $Dip_scale[$i]
        FM_scale = $FM_scale[$i]
        S_scale = $S_scale[$i]
        motion_scale = $motion_scale[$i]
        current_ease_scale = $current_ease_scale[$i]
        mobile_score = $mobile
        pinned_score = $pinned
        activation_score = $activation
        mobile_minus_pinned = if ((IsFiniteD $mobile) -and (IsFiniteD $pinned)) { $mobile - $pinned } else { [double]::NaN }
        dominant_region = $label
        region_id = $regionId
        cluster_label = $cluster
        cluster_id = switch ($cluster) { 'mobile_memory' { 1 } 'pinned_dominant' { 2 } 'activation_dominant' { 3 } 'participation_tail' { 4 } default { 5 } }
    }
}

$regionSummary = @()
foreach ($group in ($gridRows | Group-Object region_id)) {
    $rows = $group.Group
    $label = $rows[0].dominant_region
    $mobileMean = MeanAvailable @($rows | ForEach-Object { To-Double $_.mobile_score })
    $pinnedMean = MeanAvailable @($rows | ForEach-Object { To-Double $_.pinned_score })
    $activationMean = MeanAvailable @($rows | ForEach-Object { To-Double $_.activation_score })
    $dominantSignal = 'Dip_depth x A(T)'
    if ($pinnedMean -ge $mobileMean -and $pinnedMean -ge $activationMean) { $dominantSignal = 'FM_abs x A(T)' }
    if ($activationMean -ge $mobileMean -and $activationMean -ge $pinnedMean) { $dominantSignal = 'S_peak x motion x current ease' }
    $regionSummary += [pscustomobject]@{
        region_id = [int]$group.Name
        label = $label
        T_min_K = (($rows | ForEach-Object { To-Double $_.temperature_K }) | Measure-Object -Minimum).Minimum
        T_max_K = (($rows | ForEach-Object { To-Double $_.temperature_K }) | Measure-Object -Maximum).Maximum
        E_min_meV = (($rows | ForEach-Object { To-Double $_.barrier_meV }) | Measure-Object -Minimum).Minimum
        E_max_meV = (($rows | ForEach-Object { To-Double $_.barrier_meV }) | Measure-Object -Maximum).Maximum
        dominant_signal = $dominantSignal
    }
}

$runStamp = Get-Date -Format 'yyyy_MM_dd_HHmmss'
$runDir = Join-Path $repoRoot ("results\cross_experiment\runs\run_${runStamp}_unified_barrier_mechanism")
$tablesDir = Join-Path $runDir 'tables'
$figuresDir = Join-Path $runDir 'figures'
$reportsDir = Join-Path $runDir 'reports'
$reviewDir = Join-Path $runDir 'review'
New-Item -ItemType Directory -Force -Path $tablesDir, $figuresDir, $reportsDir, $reviewDir | Out-Null

$projectionRows | Export-Csv (Join-Path $tablesDir 'observable_barrier_projections.csv') -NoTypeInformation
$gridRows | Export-Csv (Join-Path $tablesDir 'barrier_region_classification.csv') -NoTypeInformation

$bands = @()
foreach ($r in $regionSummary) {
    $bands += [pscustomobject]@{
        X0 = To-Double $r.E_min_meV
        X1 = To-Double $r.E_max_meV
        Color = switch ($r.label) {
            'mobile_sector' { [System.Drawing.Color]::FromArgb(65, 216, 242, 227) }
            'pinned_sector' { [System.Drawing.Color]::FromArgb(65, 246, 224, 217) }
            'switching_activation_window' { [System.Drawing.Color]::FromArgb(65, 252, 244, 214) }
            default { [System.Drawing.Color]::FromArgb(50, 235, 235, 235) }
        }
    }
}

$barrierX = @($gridRows | ForEach-Object { To-Double $_.barrier_meV })
$ctx1 = New-BitmapContext 1280 720
Draw-LinePanel -g $ctx1.Graphics -rect (New-Object System.Drawing.RectangleF 40, 40, 1200, 620) -title "Unified barrier landscape" -xLabel "Effective barrier E_eff (meV)" -yLabel "normalized amplitude" -series @(
    @{ Name = 'A(T)'; X = $barrierX; Y = @($gridRows | ForEach-Object { To-Double $_.A_scale }); Color = Get-Color 'participation'; Width = 3; Dash = 'Solid' },
    @{ Name = 'Dip_depth'; X = $barrierX; Y = @($gridRows | ForEach-Object { To-Double $_.Dip_scale }); Color = Get-Color 'mobile'; Width = 2.5; Dash = 'Solid' },
    @{ Name = 'FM_abs'; X = $barrierX; Y = @($gridRows | ForEach-Object { To-Double $_.FM_scale }); Color = Get-Color 'pinned'; Width = 2.5; Dash = 'Solid' },
    @{ Name = 'S_peak'; X = $barrierX; Y = @($gridRows | ForEach-Object { To-Double $_.S_scale }); Color = Get-Color 'activation'; Width = 2.5; Dash = 'Solid' },
    @{ Name = 'motion'; X = $barrierX; Y = @($gridRows | ForEach-Object { To-Double $_.motion_scale }); Color = Get-Color 'motion'; Width = 2.0; Dash = 'Dash' }
) -yMin 0 -yMax 1.08 -bands $bands -showLegend $true
Save-BitmapContext $ctx1 (Join-Path $figuresDir 'unified_barrier_landscape.png')

$ctx2 = New-BitmapContext 1280 920
$panelRects = @(
    (New-Object System.Drawing.RectangleF 20, 20, 610, 280),
    (New-Object System.Drawing.RectangleF 650, 20, 610, 280),
    (New-Object System.Drawing.RectangleF 20, 320, 610, 280),
    (New-Object System.Drawing.RectangleF 650, 320, 610, 280),
    (New-Object System.Drawing.RectangleF 20, 620, 610, 280),
    (New-Object System.Drawing.RectangleF 650, 620, 610, 280)
)
Draw-LinePanel $ctx2.Graphics $panelRects[0] 'A(T) on barrier axis' 'E_eff (meV)' 'A(T)' @(@{ Name='A(T)'; X=@($relaxT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$relaxA; Color=Get-Color 'participation'; Width=2.5; Dash='Solid' }) (($relaxA | Measure-Object -Minimum).Minimum) (($relaxA | Measure-Object -Maximum).Maximum) @() $false
Draw-LinePanel $ctx2.Graphics $panelRects[1] 'Dip_depth on barrier axis' 'E_eff (meV)' 'Dip_depth' @(@{ Name='Dip_depth'; X=@($agingT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$agingDip; Color=Get-Color 'mobile'; Width=2.5; Dash='Solid' }) (($agingDip | Measure-Object -Minimum).Minimum) (($agingDip | Measure-Object -Maximum).Maximum) @() $false
Draw-LinePanel $ctx2.Graphics $panelRects[2] 'FM_abs on barrier axis' 'E_eff (meV)' 'FM_abs' @(@{ Name='FM_abs'; X=@($agingFmT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$agingFm; Color=Get-Color 'pinned'; Width=2.5; Dash='Solid' }) (($agingFm | Measure-Object -Minimum).Minimum) (($agingFm | Measure-Object -Maximum).Maximum) @() $false
Draw-LinePanel $ctx2.Graphics $panelRects[3] 'I_peak(T) on barrier axis' 'E_eff (meV)' 'I_peak (mA)' @(@{ Name='I_peak'; X=@($switchT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$switchI; Color=Get-Color 'activation'; Width=2.5; Dash='Solid' }) (($switchI | Measure-Object -Minimum).Minimum) (($switchI | Measure-Object -Maximum).Maximum) @() $false
Draw-LinePanel $ctx2.Graphics $panelRects[4] 'S_peak(T) on barrier axis' 'E_eff (meV)' 'S_peak (%)' @(@{ Name='S_peak'; X=@($switchT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$switchS; Color=Get-Color 'activation'; Width=2.5; Dash='Solid' }) (($switchS | Measure-Object -Minimum).Minimum) (($switchS | Measure-Object -Maximum).Maximum) @() $false
Draw-LinePanel $ctx2.Graphics $panelRects[5] 'motion(T) on barrier axis' 'E_eff (meV)' 'motion (mA/K)' @(@{ Name='motion'; X=@($switchT | ForEach-Object { $_ * $logFactor * $kBmeV }); Y=$switchMotion; Color=Get-Color 'motion'; Width=2.5; Dash='Solid' }) 0 (($switchMotion | Measure-Object -Maximum).Maximum) @() $false
Save-BitmapContext $ctx2 (Join-Path $figuresDir 'observable_projections_on_barrier_axis.png')

$ctx3 = New-BitmapContext 1280 820
Draw-LinePanel $ctx3.Graphics (New-Object System.Drawing.RectangleF 30, 25, 1220, 360) 'Mobile vs pinned channel map' 'E_eff (meV)' 'score' @(
    @{ Name='mobile score'; X=$barrierX; Y=@($gridRows | ForEach-Object { To-Double $_.mobile_score }); Color=Get-Color 'mobile'; Width=2.8; Dash='Solid' },
    @{ Name='pinned score'; X=$barrierX; Y=@($gridRows | ForEach-Object { To-Double $_.pinned_score }); Color=Get-Color 'pinned'; Width=2.8; Dash='Solid' },
    @{ Name='activation score'; X=$barrierX; Y=@($gridRows | ForEach-Object { To-Double $_.activation_score }); Color=Get-Color 'activation'; Width=2.2; Dash='Dash' }
) 0 1.05 $bands $true
Draw-LinePanel $ctx3.Graphics (New-Object System.Drawing.RectangleF 30, 420, 1220, 340) 'Mobile minus pinned contrast' 'E_eff (meV)' 'mobile - pinned' @(
    @{ Name='mobile - pinned'; X=$barrierX; Y=@($gridRows | ForEach-Object { To-Double $_.mobile_minus_pinned }); Color=Get-Color 'mobile'; Width=2.8; Dash='Solid' }
) -0.5 0.5 @() $false
Save-BitmapContext $ctx3 (Join-Path $figuresDir 'mobile_vs_pinned_channels.png')

Draw-HeatmapFigure $gridRows (Join-Path $figuresDir 'barrier_mechanism_map.png')

$mobilePeakIdx = FindMaxFiniteIndex @($agingDip)
$activationScoreNative = @()
for ($i = 0; $i -lt $switchT.Count; $i++) {
    $activationScoreNative += MeanAvailable @((MinMaxScale $switchS)[$i], (MinMaxScale $switchMotion)[$i], (MinMaxScale $currentEaseRaw)[$i])
}
$activationPeakIdx = FindMaxFiniteIndex $activationScoreNative

$reportLines = @()
$reportLines += '# Unified barrier landscape report'
$reportLines += ''
$reportLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportLines += ('Run root: `' + $runDir + '`')
$reportLines += ''
$reportLines += '## Inputs'
$reportLines += ('- Relaxation run: `' + $relaxRunDir + '`')
$reportLines += ('- Switching run: `' + $switchRunDir + '`')
$reportLines += ('- Aging observable run: `' + $agingObservableRunDir + '`')
$reportLines += ('- Aging shape run: `' + $agingShapeRunDir + '`')
$reportLines += ''
$reportLines += '## Barrier mapping'
$reportLines += ('- Effective mapping used: `E_eff = k_B T ln(' + [Math]::Round($referenceTime,3) + ' / ' + $attemptTime + ')`')
$reportLines += "- Relaxation-selected reference time: $referenceTime s"
$reportLines += "- Microscopic attempt time: $attemptTime s"
$reportLines += '- The barrier axis is an Arrhenius-style reconstruction inferred from the relaxation diagnostics because no standalone exported `E_eff` lookup table was present in the referenced run artifacts.'
$reportLines += ''
$reportLines += '## Interpretation'
$reportLines += '1. Relaxation reconstructs the barrier participation landscape.'
$reportLines += "A(T) supplies the participation envelope, peaking near $([Math]::Round((To-Double $relaxSummary.Relax_T_peak),0)) K where the relaxation audit reports `Relax_Amp_peak = $($relaxSummary.Relax_Amp_peak)` and a strongly rank-1 DeltaM map."
$reportLines += '2. Aging separates mobile vs pinned sectors.'
$reportLines += "Dip_depth is used as the mobile-memory channel and FM_abs as the pinned/background channel. The strongest mobile contrast in the aggregated aging observables occurs near $($agingT[$mobilePeakIdx]) K."
$reportLines += '3. Switching probes current-tilted activation thresholds.'
$reportLines += "The switching activation composite built from `I_peak(T)`, `S_peak(T)`, and `motion(T)` is strongest near $($switchT[$activationPeakIdx]) K, marking the barrier window where the current threshold evolves most rapidly."
$reportLines += '4. Unified physical interpretation.'
$reportLines += 'All three experiments are consistent with one shared barrier landscape: relaxation supplies the active barrier participation weight, aging splits that active population into mobile and pinned channels, and switching identifies the current-tilted activation window inside the same reconstructed landscape.'
$reportLines += ''
$reportLines += '## Barrier regions'
$reportLines += '| region | label | T range (K) | E range (meV) | dominant signal |'
$reportLines += '| ---: | --- | ---: | ---: | --- |'
foreach ($r in $regionSummary) {
    $reportLines += "| $($r.region_id) | $($r.label) | $([Math]::Round($r.T_min_K,0))-$([Math]::Round($r.T_max_K,0)) | $([Math]::Round($r.E_min_meV,2))-$([Math]::Round($r.E_max_meV,2)) | $($r.dominant_signal) |"
}
$reportLines += ''
$reportLines += '## Outputs'
$reportLines += '- `tables/observable_barrier_projections.csv`'
$reportLines += '- `tables/barrier_region_classification.csv`'
$reportLines += '- `figures/unified_barrier_landscape.png`'
$reportLines += '- `figures/observable_projections_on_barrier_axis.png`'
$reportLines += '- `figures/mobile_vs_pinned_channels.png`'
$reportLines += '- `figures/barrier_mechanism_map.png`'
$reportLines += '- `review/unified_barrier_landscape_bundle.zip`'
Set-Content -Path (Join-Path $reportsDir 'unified_barrier_landscape_report.md') -Value ($reportLines -join [Environment]::NewLine) -Encoding UTF8

$manifest = [pscustomobject]@{
    run_dir = $runDir
    relaxation_run = $relaxRunDir
    switching_run = $switchRunDir
    aging_observable_run = $agingObservableRunDir
    aging_shape_run = $agingShapeRunDir
    barrier_reference_time_s = $referenceTime
    barrier_attempt_time_s = $attemptTime
    barrier_ln_factor = $logFactor
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $runDir 'manifest.json') -Encoding UTF8

$notes = @(
    "Relaxation input: $relaxRunDir",
    "Switching input: $switchRunDir",
    "Aging observable input: $agingObservableRunDir",
    "Aging shape input: $agingShapeRunDir"
)
Set-Content -Path (Join-Path $runDir 'run_notes.txt') -Value ($notes -join [Environment]::NewLine) -Encoding UTF8

$bundlePath = Join-Path $reviewDir 'unified_barrier_landscape_bundle.zip'
if (Test-Path $bundlePath) { Remove-Item $bundlePath -Force }
Compress-Archive -Path (Join-Path $runDir 'tables'), (Join-Path $runDir 'figures'), (Join-Path $runDir 'reports') -DestinationPath $bundlePath

Write-Output $runDir




