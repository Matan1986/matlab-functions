param(
    [string]$RunDir = 'C:\Dev\matlab-functions\results\cross_experiment\runs\run_2026_03_11_223145_relaxation_aging_canonical_comparison'
)

Add-Type -AssemblyName System.Drawing

function New-Color($hex) {
    $hex = $hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($hex.Substring(0,2),16), [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16))
}

function Save-PeakFigure($metricsPath, $outPath) {
    $metrics = Import-Csv $metricsPath
    $displayNames = @('Relaxation A(T)') + ($metrics | ForEach-Object { $_.display_name })
    $peakT = @([double]$metrics[0].relax_peak_T_K) + ($metrics | ForEach-Object { [double]$_.observable_peak_T_K })
    $peakDelta = @('') + ($metrics | ForEach-Object { ('dT = {0:N1} K' -f [double]$_.peak_delta_K) })
    $xMin = [math]::Floor((($metrics | ForEach-Object { [double]$_.relax_support25_low_K }) + ($metrics | ForEach-Object { [double]$_.observable_support25_low_K }) | Measure-Object -Minimum).Minimum) - 1
    $xMax = [math]::Ceiling((($metrics | ForEach-Object { [double]$_.relax_support25_high_K }) + ($metrics | ForEach-Object { [double]$_.observable_support25_high_K }) | Measure-Object -Maximum).Maximum) + 1

    $bmp = New-Object System.Drawing.Bitmap 1400, 760
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font('Arial', 14)
    $small = New-Object System.Drawing.Font('Arial', 11)
    $brush = [System.Drawing.Brushes]::Black
    $blue = New-Color '#0072B2'
    $gray = New-Color '#666666'
    $pen = New-Object System.Drawing.Pen($blue, 2)
    $dashPen = New-Object System.Drawing.Pen($gray, 2)
    $dashPen.DashStyle = 'Dash'
    $left = 260; $right = 80; $top = 70; $bottom = 70
    $plotW = $bmp.Width - $left - $right
    $plotH = $bmp.Height - $top - $bottom
    $count = $displayNames.Count
    $toX = { param($t) $left + (($t - $xMin) / ($xMax - $xMin)) * $plotW }
    $stepY = $plotH / [math]::Max(1, ($count - 1))

    $g.DrawString('Peak-temperature alignment summary', $font, $brush, 20, 20)
    $relaxX = & $toX $peakT[0]
    $g.DrawLine($dashPen, [int]$relaxX, $top, [int]$relaxX, $top + $plotH)

    for ($i = 0; $i -lt $count; $i++) {
        $y = $top + $i * $stepY
        $g.DrawString($displayNames[$i], $small, $brush, 10, $y - 8)
        $x = & $toX $peakT[$i]
        $g.FillEllipse((New-Object System.Drawing.SolidBrush($blue)), $x - 5, $y - 5, 10, 10)
        if ($i -gt 0) {
            $g.DrawString($peakDelta[$i], $small, $brush, $x + 10, $y - 8)
        }
    }

    for ($tick = [int]$xMin; $tick -le [int]$xMax; $tick += 4) {
        $x = & $toX $tick
        $g.DrawLine([System.Drawing.Pens]::Black, [int]$x, $top + $plotH + 4, [int]$x, $top + $plotH + 10)
        $g.DrawString([string]$tick, $small, $brush, $x - 8, $top + $plotH + 12)
    }
    $g.DrawString('Peak temperature (K)', $small, $brush, $left + ($plotW / 2) - 50, $bmp.Height - 40)
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    $bmp.Save($outPath)
    $g.Dispose(); $bmp.Dispose(); $font.Dispose(); $small.Dispose(); $pen.Dispose(); $dashPen.Dispose()
}

function Save-WindowFigure($windowsPath, $alignmentPath, $outPath) {
    $rows = Import-Csv $windowsPath
    $alignment = Import-Csv $alignmentPath
    $xMin = [math]::Floor((($alignment | ForEach-Object { [double]$_.T_K } | Measure-Object -Minimum).Minimum)) - 1
    $xMax = [math]::Ceiling((($rows | ForEach-Object { [double]$_.support25_high_K }) | Measure-Object -Maximum).Maximum) + 1
    $colors = @('#000000','#0072B2','#E69F00','#009E73','#CC79A7')

    $bmp = New-Object System.Drawing.Bitmap 1400, 860
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font('Arial', 14)
    $small = New-Object System.Drawing.Font('Arial', 11)
    $brush = [System.Drawing.Brushes]::Black
    $left = 280; $right = 80; $top = 70; $bottom = 70
    $plotW = $bmp.Width - $left - $right
    $plotH = $bmp.Height - $top - $bottom
    $count = $rows.Count
    $toX = { param($t) $left + (($t - $xMin) / ($xMax - $xMin)) * $plotW }
    $stepY = $plotH / [math]::Max(1, ($count - 1))

    $g.DrawString('Temperature-window overlap', $font, $brush, 20, 20)

    for ($i = 0; $i -lt $count; $i++) {
        $row = $rows[$i]
        $c = New-Color $colors[[math]::Min($i, $colors.Count - 1)]
        $bThin = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, $c))
        $bThick = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140, $c))
        $bDot = New-Object System.Drawing.SolidBrush($c)
        $y = $top + $i * $stepY
        $g.DrawString($row.display_name, $small, $brush, 10, $y - 8)
        $x1 = & $toX ([double]$row.support25_low_K)
        $x2 = & $toX ([double]$row.support25_high_K)
        $g.FillRectangle($bThin, $x1, $y - 8, [math]::Max(2, $x2 - $x1), 16)
        $f1 = & $toX ([double]$row.fwhm_low_K)
        $f2 = & $toX ([double]$row.fwhm_high_K)
        $g.FillRectangle($bThick, $f1, $y - 14, [math]::Max(2, $f2 - $f1), 28)
        $xp = & $toX ([double]$row.peak_T_K)
        $g.FillEllipse($bDot, $xp - 5, $y - 5, 10, 10)
        $bThin.Dispose(); $bThick.Dispose(); $bDot.Dispose()
    }

    for ($tick = [int]$xMin; $tick -le [int]$xMax; $tick += 4) {
        $x = & $toX $tick
        $g.DrawLine([System.Drawing.Pens]::Black, [int]$x, $top + $plotH + 4, [int]$x, $top + $plotH + 10)
        $g.DrawString([string]$tick, $small, $brush, $x - 8, $top + $plotH + 12)
    }
    $g.DrawString('Temperature (K)', $small, $brush, $left + ($plotW / 2) - 40, $bmp.Height - 40)
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    $bmp.Save($outPath)
    $g.Dispose(); $bmp.Dispose(); $font.Dispose(); $small.Dispose()
}

$metricsPath = Join-Path $RunDir 'tables\normalized_overlay_metrics.csv'
$windowsPath = Join-Path $RunDir 'tables\peak_window_summary.csv'
$manifestPath = Join-Path $RunDir 'tables\source_run_manifest.csv'
$alignmentPath = Join-Path $RunDir 'tables\relaxation_aging_observable_alignment.csv'
$figDir = Join-Path $RunDir 'figures'
$reportDir = Join-Path $RunDir 'reports'
$reviewDir = Join-Path $RunDir 'review'
New-Item -ItemType Directory -Force -Path $figDir, $reportDir, $reviewDir | Out-Null

Save-PeakFigure $metricsPath (Join-Path $figDir 'peak_alignment_summary.png')
Save-WindowFigure $windowsPath $alignmentPath (Join-Path $figDir 'temperature_window_overlap.png')

$metrics = Import-Csv $metricsPath
$manifest = Import-Csv $manifestPath
$report = @()
$report += '# Relaxation-Aging Canonical Comparison'
$report += ''
$report += '## Repository-state summary'
$report += '- Relevant saved runs were inspected from `results/relaxation/runs/`, `results/aging/runs/`, and `results/cross_experiment/runs/`.'
$report += '- Saved observables already present before this run included Relaxation `A_T`, `Relax_T_peak`, `Relax_peak_width`, and Aging `Dip_depth`, `FM_abs`, `coeff_mode1`, plus the saved Aging collapse sweep.'
$report += '- Existing cross-analysis context was present as a broader Relaxation-Aging-Switching run and a legacy `results/cross_analysis` tree, but no saved dedicated modern pairwise Relaxation-Aging run existed.'
$report += '- New scripts added or modified for this task: `analysis/relaxation_aging_canonical_comparison.m`, `analysis/finalize_relaxation_aging_run.ps1`.'
$report += ''
$report += '## Source runs used'
$manifest | ForEach-Object { $report += ('- `{0}` [{1}]: {2}' -f $_.run_id, $_.usage_role, $_.dataset) }
$report += ''
$report += '## Why these observables were selected'
$report += '- `A(T)` is the canonical Relaxation activity envelope from the stability audit.'
$report += '- `Dip_depth(T)` is the primary Aging observable according to the saved audit.'
$report += '- `FM_abs(T)` is a supporting background observable that is present in saved outputs but weaker.'
$report += '- `coeff_mode1(T)` is included as a supporting geometric descriptor only, with sign treated as convention-dependent.'
$report += '- `rank1_explained_variance_ratio(T_p)` is the saved Aging collapse metric used for the comparison.'
$report += ''
$report += '## Findings'
$metrics | ForEach-Object {
    $report += ('- `{0}`: {1}. normalized corr = {2:N3}, peak shift = {3:N1} K, FWHM overlap = {4:N3}, support-window overlap = {5:N3}.' -f $_.observable, $_.comparison_strength, [double]$_.normalized_pearson, [double]$_.peak_delta_K, [double]$_.fwhm_overlap_fraction, [double]$_.support25_overlap_fraction)
    $report += ('  sign / shape: {0} | {1}' -f $_.sign_note, $_.shape_note)
    if ($_.notes) { $report += ('  note: {0}' -f $_.notes) }
}
$report += ''
$dip = $metrics | Where-Object { $_.observable -eq 'Dip_depth' } | Select-Object -First 1
$report += '## Shared crossover window'
if ($dip -and ($dip.comparison_strength -eq 'suggestive' -or $dip.comparison_strength -eq 'strong')) {
    $report += '- The current evidence supports a **suggestive** shared crossover window centered in the same broad 22-30 K band, but not a clean one-to-one mechanistic lock.'
} else {
    $report += '- The current evidence does **not** cleanly establish a shared crossover window beyond partial overlap.'
}
$report += ''
$report += '## What remains missing for a stronger mechanism claim'
$report += '- A direct model-based bridge stronger than broad temperature-window alignment.'
$report += '- More complete structured Aging coverage at the fragile high-T points.'
$report += '- A sign-stable or otherwise more directly physical replacement for `coeff_mode1` across runs.'
$report += ''
$report += '## Visualization choices'
$report += '- number of curves: pair figures use one Relaxation curve and one Aging curve per panel; summary figures use one point/window per observable.'
$report += '- legend vs colormap: explicit legends only; no panel exceeds 5 compared quantities.'
$report += '- colormap used: none for line figures; categorical color-blind-safe palette only.'
$report += '- smoothing applied: none to source observables; interpolation is only used for alignment and window estimation.'
Set-Content -Path (Join-Path $reportDir 'relaxation_aging_canonical_comparison.md') -Value ($report -join "`r`n") -Encoding ascii

$zipPath = Join-Path $reviewDir 'relaxation_aging_canonical_comparison_bundle.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $RunDir 'reports'), (Join-Path $RunDir 'tables'), (Join-Path $RunDir 'figures'), (Join-Path $RunDir 'run_manifest.json'), (Join-Path $RunDir 'config_snapshot.m'), (Join-Path $RunDir 'log.txt'), (Join-Path $RunDir 'run_notes.txt') -DestinationPath $zipPath

