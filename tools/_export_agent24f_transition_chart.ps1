# Renders aging_alpha_transition_focus.png from residual audit CSV (no MATLAB).
param(
    [string]$RunDir = "C:\Dev\matlab-functions\results\cross_experiment\runs\run_2026_03_26_012056_aging_alpha_closure_alpha_residual"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

$csv = Import-Csv (Join-Path $RunDir "tables\aging_alpha_closure_residual_audit.csv")
$r0 = $csv[0]
$r1 = $csv[1]
$mae22_ref = [double]$r0.mae_abs_residual_22_24_K
$maeOut_ref = [double]$r0.mae_abs_residual_outside_22_24_K
$mae22_a = [double]$r1.mae_abs_residual_22_24_K
$maeOut_a = [double]$r1.mae_abs_residual_outside_22_24_K

$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Width = 900
$chart.Height = 650
$chart.BackColor = [System.Drawing.Color]::White

$area = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$area.AxisX.Title = ""
$area.AxisY.Title = "Mean |residual|"
$area.AxisY.TitleFont = New-Object System.Drawing.Font("Arial", 14)
$area.AxisX.LabelStyle.Font = New-Object System.Drawing.Font("Arial", 12)
$area.AxisY.LabelStyle.Font = New-Object System.Drawing.Font("Arial", 12)
$chart.ChartAreas.Add($area)

$ser1 = $chart.Series.Add("PT+kappa1")
$ser1.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Column
$ser1.Color = [System.Drawing.Color]::FromArgb(255, 51, 115, 178)
$ser1.Points.DataBindXY(@("22-24 K", "Outside"), @($mae22_ref, $maeOut_ref))

$ser2 = $chart.Series.Add("Best alpha-aug")
$ser2.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Column
$ser2.Color = [System.Drawing.Color]::FromArgb(255, 217, 89, 38)
$ser2.Points.DataBindXY(@("22-24 K", "Outside"), @($mae22_a, $maeOut_a))

$chart.Legends.Add([System.Windows.Forms.DataVisualization.Charting.Legend]::new())
$chart.Legends[0].Font = New-Object System.Drawing.Font("Arial", 11)

$figDir = Join-Path $RunDir "figures"
if (-not (Test-Path $figDir)) { New-Item -ItemType Directory -Path $figDir | Out-Null }
$pngPath = Join-Path $figDir "aging_alpha_transition_focus.png"
$chart.SaveImage($pngPath, [System.Windows.Forms.DataVisualization.Charting.ChartImageFormat]::Png)
Write-Host "Wrote $pngPath"
