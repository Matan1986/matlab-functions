$runsRoot = "C:\Dev\matlab-functions\results\aging\runs"
$runs = Get-ChildItem -Path $runsRoot -Directory -Filter "run_*" | Sort-Object Name
foreach ($run in $runs) {
  $figs = @(Get-ChildItem -Path (Join-Path $run.FullName 'figures') -Recurse -File -ErrorAction SilentlyContinue)
  $tables = @(Get-ChildItem -Path (Join-Path $run.FullName 'tables') -Recurse -File -ErrorAction SilentlyContinue)
  $reports = @(Get-ChildItem -Path (Join-Path $run.FullName 'reports') -Recurse -File -ErrorAction SilentlyContinue)
  $review = @(Get-ChildItem -Path (Join-Path $run.FullName 'review') -Recurse -File -ErrorAction SilentlyContinue)
  Write-Output ("=== {0} ===" -f $run.Name)
  Write-Output ("figures={0}; tables={1}; reports={2}; review={3}" -f $figs.Count, $tables.Count, $reports.Count, $review.Count)
  if ($figs.Count -gt 0) { Write-Output ("figure_files: " + (($figs | Select-Object -First 8 -ExpandProperty Name) -join ', ')) }
  if ($tables.Count -gt 0) { Write-Output ("table_files: " + (($tables | Select-Object -First 8 -ExpandProperty Name) -join ', ')) }
  if ($reports.Count -gt 0) { Write-Output ("report_files: " + (($reports | Select-Object -First 8 -ExpandProperty Name) -join ', ')) }
  if ($review.Count -gt 0) { Write-Output ("review_files: " + (($review | Select-Object -First 8 -ExpandProperty Name) -join ', ')) }
  Write-Output ""
}
