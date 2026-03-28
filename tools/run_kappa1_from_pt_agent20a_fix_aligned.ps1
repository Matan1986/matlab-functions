# PT alignment fix wrapper for Agent 20A (20A-FIX)
# Uses the SAME PT_matrix.csv that was used inside switching_residual_decomposition_analysis.

$ErrorActionPreference = "Stop"
$Repo = Split-Path -Parent $PSScriptRoot

$kappaRunDir = Join-Path $Repo "results/switching/runs/_extract_run_2026_03_24_220314_residual_decomposition/run_2026_03_24_220314_residual_decomposition"
$sourcesPath = Join-Path $kappaRunDir "tables/residual_decomposition_sources.csv"

if (!(Test-Path $sourcesPath)) { throw "Missing sources file: $sourcesPath" }

$src = Import-Csv $sourcesPath
$ptRow = $src | Where-Object { $_.source_role -eq "pt_matrix" } | Select-Object -First 1
if ($null -eq $ptRow) { throw "Could not find pt_matrix row in $sourcesPath" }
$ptPath = [string]$ptRow.source_file

$env:PT_MATRIX_OVERRIDE = $ptPath
$env:OUT_CSV_OVERRIDE = (Join-Path $Repo "tables/kappa1_from_PT_aligned.csv")
$env:OUT_MD_OVERRIDE = (Join-Path $Repo "reports/kappa1_from_PT_aligned_report.md")
$env:ALIGNED_RUN = "1"
$env:COMPARE_PREV_REPORT_PATH = (Join-Path $Repo "reports/kappa1_from_PT_report.md")

$scriptToRun = Join-Path $Repo "tools/run_kappa1_from_pt_agent20a.ps1"
if (!(Test-Path $scriptToRun)) { throw "Missing: $scriptToRun" }

Write-Host "Running aligned PT regression with PT_matrix="
Write-Host $ptPath

& $scriptToRun

